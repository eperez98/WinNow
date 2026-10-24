# modules/Apps.ps1
# App Manager: install / uninstall / upgrade from the catalog with winget (Chocolatey fallback).

$script:WingetCommon = @('--accept-source-agreements', '--disable-interactivity')
# winget exit codes that mean "nothing to do" rather than failure
$script:WingetAlreadyInstalled = @(-1978335189, -1978335135)   # 0x8A15002B, 0x8A150061

function Invoke-WNWinget {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $wg = Find-WNWinget
    if (-not $wg) { Write-WNStatus 'winget is not available (install "App Installer" from the Microsoft Store).' Error 'Apps'; return -1 }
    return (Invoke-WNNative -FilePath $wg -ArgumentList ($Arguments + $script:WingetCommon) -Component 'Apps')
}

function Get-WNInstalledAppIds {
    param([switch]$Refresh)
    if (-not $Refresh -and $WN.Cache.ContainsKey('InstalledApps')) { return $WN.Cache.InstalledApps }
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $wg = Find-WNWinget
    if ($wg) {
        Write-WNStatus 'Reading installed apps (winget export)...' Info 'Apps'
        $tmp = Join-Path $env:TEMP "winnow_export_$PID.json"
        & $wg export -o $tmp --accept-source-agreements --disable-interactivity *> $null
        if (Test-Path $tmp) {
            try {
                $data = Get-Content $tmp -Raw | ConvertFrom-Json
                foreach ($src in $data.Sources) { foreach ($p in $src.Packages) { [void]$set.Add($p.PackageIdentifier) } }
            } catch { Write-WNLog "winget export parse failed: $_" -Level WARN -Component 'Apps' }
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    $WN.Cache.InstalledApps = $set
    return $set
}

function Install-WNChoco {
    if (Get-Command choco.exe -ErrorAction SilentlyContinue) { return $true }
    Write-Host '  Chocolatey is not installed. It will be installed from community.chocolatey.org.' -ForegroundColor Yellow
    if (-not (Read-WNConfirm 'Install Chocolatey now?')) { return $false }
    if ($WN.DryRun) { Write-WNStatus 'Would install Chocolatey' Dry 'Apps'; return $true }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";$env:ProgramData\chocolatey\bin"
        return [bool](Get-Command choco.exe -ErrorAction SilentlyContinue)
    } catch {
        Write-WNStatus "Chocolatey install failed: $($_.Exception.Message)" Error 'Apps'
        return $false
    }
}

function Install-WNApps {
    param([Parameter(Mandatory)][object[]]$Apps)
    if (-not (Start-WNChange -Label 'install apps' -Apps -Items @($Apps | ForEach-Object Winget))) { return }
    $installed = Get-WNInstalledAppIds
    $useChoco = -not (Find-WNWinget)
    if ($useChoco -and -not (Install-WNChoco)) { return }

    $i = 0; $ok = 0; $skip = 0
    foreach ($a in $Apps) {
        $i++
        Write-Host ''
        Write-Host ("  [{0}/{1}] {2}" -f $i, $Apps.Count, $a.Name) -ForegroundColor White
        if ($installed.Contains($a.Winget)) { Write-WNStatus "$($a.Name) is already installed" Skip 'Apps'; $skip++; continue }
        if ($useChoco) {
            if (-not $a.Choco -or $a.Choco -eq 'na') { Write-WNStatus "No Chocolatey package for $($a.Name)" Skip 'Apps'; $skip++; continue }
            $code = Invoke-WNNative -FilePath 'choco' -ArgumentList @('install', $a.Choco, '-y', '--no-progress') -Component 'Apps'
        } else {
            $code = Invoke-WNWinget @('install', '--id', $a.Winget, '-e', '--source', 'winget', '--accept-package-agreements', '--silent')
        }
        if ($code -in 0, 3010, 1641) { Write-WNStatus "Installed $($a.Name)" Ok 'Apps'; $ok++; if (-not $WN.DryRun) { [void]$installed.Add($a.Winget) } }
        elseif ($code -in $script:WingetAlreadyInstalled) { Write-WNStatus "$($a.Name) is already installed" Skip 'Apps'; $skip++ }
        else { Write-WNStatus ("Install failed for {0} (exit 0x{1:X8})" -f $a.Name, $code) Error 'Apps' }
    }
    Write-Host ''
    Write-Host "  Installed $ok, skipped $skip, failed $($Apps.Count - $ok - $skip) of $($Apps.Count)." -ForegroundColor Cyan
}

function Uninstall-WNApps {
    param([Parameter(Mandatory)][object[]]$Apps)
    if (-not (Start-WNChange -Label 'uninstall apps' -Apps -Items @($Apps | ForEach-Object Winget))) { return }
    $installed = Get-WNInstalledAppIds
    foreach ($a in $Apps) {
        Write-Host ''
        Write-Host "  $($a.Name)" -ForegroundColor White
        if (-not $installed.Contains($a.Winget)) { Write-WNStatus "$($a.Name) is not installed (via winget)" Skip 'Apps'; continue }
        $code = Invoke-WNWinget @('uninstall', '--id', $a.Winget, '-e', '--silent')
        if ($code -eq 0) { Write-WNStatus "Uninstalled $($a.Name)" Ok 'Apps'; if (-not $WN.DryRun) { [void]$installed.Remove($a.Winget) } }
        else { Write-WNStatus ("Uninstall failed for {0} (exit 0x{1:X8})" -f $a.Name, $code) Error 'Apps' }
    }
}

function Show-WNAppList {
    param([string]$Title, [object[]]$Apps)
    while ($true) {
        $installed = Get-WNInstalledAppIds
        $items = foreach ($a in ($Apps | Sort-Object Name)) {
            $isIn = $installed.Contains($a.Winget)
            $foss = if ($a.Foss) { ' [FOSS]' } else { '' }
            [pscustomobject]@{
                Label    = "$($a.Name)$foss"
                Value    = $a
                Detail   = "$($a.Description)  (winget: $($a.Winget))"
                Tag      = $(if ($isIn) { 'INSTALLED' } else { '' })
                TagColor = 'Green'
                Group    = $a.Category
            }
        }
        $r = Show-WNCheckList -Title $Title -Items @($items) -EnterLabel 'install' -Actions ([ordered]@{ U = 'Uninstall' })
        if (-not $r) { return }
        $verb = if ($r.Action -eq 'Uninstall') { 'Uninstall' } else { 'Install' }
        Write-WNHeader "$verb $(@($r.Items).Count) app(s)"
        $r.Items | ForEach-Object { Write-Host "   - $($_.Name)" }
        Write-Host ''
        if (-not (Read-WNConfirm "$verb these apps?" -DefaultYes)) { continue }
        if ($verb -eq 'Install') { Install-WNApps -Apps $r.Items } else { Uninstall-WNApps -Apps $r.Items }
        Wait-WNKey
    }
}

function Show-WNAppsMenu {
    while ($true) {
        $apps = @($WN.Config.apps)
        $wg = Find-WNWinget
        $items = @()
        foreach ($cat in ($apps | Group-Object Category | Sort-Object Name)) {
            $items += @{ Label = "$($cat.Name)  ($($cat.Count))"; Value = "cat:$($cat.Name)"; Hint = 'Space to select, Enter install, U uninstall' }
        }
        $items += @{ Separator = $true; Label = '' }
        $items += @{ Label = "All apps - search ($($apps.Count))"; Value = 'all'; Hotkey = 's'; Hint = 'Press / inside the list to search by name or description' }
        $items += @{ Label = 'Installed catalog apps'; Value = 'installed'; Hotkey = 'i'; Hint = 'Apps from the catalog that winget reports as installed' }
        $items += @{ Label = 'Upgrade ALL apps (winget upgrade --all)'; Value = 'upgrade'; Hotkey = 'g'; Hint = 'Upgrades every app winget can upgrade, including ones not in the catalog' }
        $items += @{ Label = 'List available upgrades'; Value = 'list'; Hotkey = 'l'; Hint = 'winget upgrade' }
        $items += @{ Label = 'Refresh installed list'; Value = 'refresh'; Hotkey = 'r'; Hint = 'Re-reads installed apps from winget' }

        $sub = if ($wg) { 'winget ready' } else { 'winget NOT found - Chocolatey will be used' }
        $choice = Show-WNMenu -Title 'App Manager' -Subtitle $sub -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'cat:*'     { $c = $choice.Substring(4); Show-WNAppList -Title "Apps - $c" -Apps @($apps | Where-Object Category -eq $c) }
            'all'       { Show-WNAppList -Title 'All apps' -Apps $apps }
            'installed' { $set = Get-WNInstalledAppIds; Show-WNAppList -Title 'Installed apps' -Apps @($apps | Where-Object { $set.Contains($_.Winget) }) }
            'upgrade' {
                Write-WNHeader 'Upgrade all apps'
                if ((Test-WNCanChange) -and (Read-WNConfirm 'Run winget upgrade --all now?' -DefaultYes) -and (Start-WNChange -Label 'upgrade all apps' -Apps)) {
                    [void](Invoke-WNWinget @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--silent'))
                    [void](Get-WNInstalledAppIds -Refresh)
                }
                Wait-WNKey
            }
            'list'    { Write-WNHeader 'Available upgrades'; if ($wg) { & $wg upgrade --accept-source-agreements | Out-Host }; Wait-WNKey }
            'refresh' { [void](Get-WNInstalledAppIds -Refresh) }
        }
    }
}
