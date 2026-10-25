# modules/Apps.ps1
# App Manager: install / uninstall / upgrade from the catalog with winget (Chocolatey fallback).

$script:WingetCommon = @('--accept-source-agreements', '--disable-interactivity')
# winget exit codes that mean "nothing to do" rather than failure
$script:WingetAlreadyInstalled = @(-1978335189, -1978335135)   # 0x8A15002B, 0x8A150061

function Invoke-WNWinget {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $wg = Find-WNWinget
    if (-not $wg) { Write-WNStatus (T 'apps.noWinget') Error 'Apps'; return -1 }
    return (Invoke-WNNative -FilePath $wg -ArgumentList ($Arguments + $script:WingetCommon) -Component 'Apps')
}

function Get-WNInstalledAppIds {
    param([switch]$Refresh)
    if (-not $Refresh -and $WN.Cache.ContainsKey('InstalledApps')) { return $WN.Cache.InstalledApps }
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $wg = Find-WNWinget
    if ($wg) {
        Write-WNStatus (T 'apps.reading') Info 'Apps'
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
    Write-Host ('  ' + (T 'apps.chocoMissing')) -ForegroundColor Yellow
    if (-not (Read-WNConfirm (T 'apps.chocoAsk'))) { return $false }
    if ($WN.DryRun) { Write-WNStatus (T 'apps.chocoDry') Dry 'Apps'; return $true }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";$env:ProgramData\chocolatey\bin"
        return [bool](Get-Command choco.exe -ErrorAction SilentlyContinue)
    } catch {
        Write-WNStatus (T 'apps.chocoFail' $_.Exception.Message) Error 'Apps'
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
        if ($installed.Contains($a.Winget)) { Write-WNStatus (T 'apps.already' $a.Name) Skip 'Apps'; $skip++; continue }
        if ($useChoco) {
            if (-not $a.Choco -or $a.Choco -eq 'na') { Write-WNStatus (T 'apps.noChoco' $a.Name) Skip 'Apps'; $skip++; continue }
            $code = Invoke-WNNative -FilePath 'choco' -ArgumentList @('install', $a.Choco, '-y', '--no-progress') -Component 'Apps'
        } else {
            $code = Invoke-WNWinget @('install', '--id', $a.Winget, '-e', '--source', 'winget', '--accept-package-agreements', '--silent')
        }
        if ($code -in 0, 3010, 1641) { Write-WNStatus (T 'apps.installed' $a.Name) Ok 'Apps'; $ok++; if (-not $WN.DryRun) { [void]$installed.Add($a.Winget) } }
        elseif ($code -in $script:WingetAlreadyInstalled) { Write-WNStatus (T 'apps.already' $a.Name) Skip 'Apps'; $skip++ }
        else { Write-WNStatus (T 'apps.installFail' $a.Name $code) Error 'Apps' }
    }
    Write-Host ''
    Write-Host ('  ' + (T 'apps.summary' $ok $skip ($Apps.Count - $ok - $skip) $Apps.Count)) -ForegroundColor Cyan
}

function Uninstall-WNApps {
    param([Parameter(Mandatory)][object[]]$Apps)
    if (-not (Start-WNChange -Label 'uninstall apps' -Apps -Items @($Apps | ForEach-Object Winget))) { return }
    $installed = Get-WNInstalledAppIds
    foreach ($a in $Apps) {
        Write-Host ''
        Write-Host "  $($a.Name)" -ForegroundColor White
        if (-not $installed.Contains($a.Winget)) { Write-WNStatus (T 'apps.notInstalled' $a.Name) Skip 'Apps'; continue }
        $code = Invoke-WNWinget @('uninstall', '--id', $a.Winget, '-e', '--silent')
        if ($code -eq 0) { Write-WNStatus (T 'apps.uninstalled' $a.Name) Ok 'Apps'; if (-not $WN.DryRun) { [void]$installed.Remove($a.Winget) } }
        else { Write-WNStatus (T 'apps.uninstallFail' $a.Name $code) Error 'Apps' }
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
                Tag      = $(if ($isIn) { T 'apps.tagInstalled' } else { '' })
                TagColor = 'Green'
                Group    = $a.Category
            }
        }
        $r = Show-WNCheckList -Title $Title -Items @($items) -EnterLabel (T 'enter.install') -Actions ([ordered]@{ U = 'Uninstall' })
        if (-not $r) { return }
        $uninstall = $r.Action -eq 'Uninstall'
        Write-WNHeader $(if ($uninstall) { T 'apps.titleUninstall' @($r.Items).Count } else { T 'apps.titleInstall' @($r.Items).Count })
        $r.Items | ForEach-Object { Write-Host "   - $($_.Name)" }
        Write-Host ''
        if (-not (Read-WNConfirm $(if ($uninstall) { T 'apps.confirmUninstall' } else { T 'apps.confirmInstall' }) -DefaultYes)) { continue }
        if ($uninstall) { Uninstall-WNApps -Apps $r.Items } else { Install-WNApps -Apps $r.Items }
        Wait-WNKey
    }
}

function Show-WNAppsMenu {
    while ($true) {
        $apps = @($WN.Config.apps)
        $wg = Find-WNWinget
        $items = @()
        foreach ($cat in ($apps | Group-Object Category | Sort-Object Name)) {
            $items += @{ Label = "$($cat.Name)  ($($cat.Count))"; Value = "cat:$($cat.Name)"; Hint = (T 'apps.catHint') }
        }
        $items += @{ Separator = $true; Label = '' }
        $items += @{ Label = (T 'apps.all' $apps.Count); Value = 'all'; Hotkey = 's'; Hint = (T 'apps.allHint') }
        $items += @{ Label = (T 'apps.installedMenu'); Value = 'installed'; Hotkey = 'i'; Hint = (T 'apps.installedHint') }
        $items += @{ Label = (T 'apps.upgradeAll'); Value = 'upgrade'; Hotkey = 'g'; Hint = (T 'apps.upgradeAllHint') }
        $items += @{ Label = (T 'apps.listUpgrades'); Value = 'list'; Hotkey = 'l'; Hint = 'winget upgrade' }
        $items += @{ Label = (T 'apps.refresh'); Value = 'refresh'; Hotkey = 'r'; Hint = (T 'apps.refreshHint') }

        $sub = if ($wg) { T 'apps.wingetReady' } else { T 'apps.wingetMissing' }
        $choice = Show-WNMenu -Title (T 'apps.title') -Subtitle $sub -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'cat:*'     { $c = $choice.Substring(4); Show-WNAppList -Title (T 'apps.catTitle' $c) -Apps @($apps | Where-Object Category -eq $c) }
            'all'       { Show-WNAppList -Title (T 'apps.allTitle') -Apps $apps }
            'installed' { $set = Get-WNInstalledAppIds; Show-WNAppList -Title (T 'apps.installedTitle') -Apps @($apps | Where-Object { $set.Contains($_.Winget) }) }
            'upgrade' {
                Write-WNHeader (T 'apps.upgradeTitle')
                if ((Test-WNCanChange) -and (Read-WNConfirm (T 'apps.upgradeAsk') -DefaultYes) -and (Start-WNChange -Label 'upgrade all apps' -Apps)) {
                    [void](Invoke-WNWinget @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--silent'))
                    [void](Get-WNInstalledAppIds -Refresh)
                }
                Wait-WNKey
            }
            'list'    { Write-WNHeader (T 'apps.upgradesTitle'); if ($wg) { & $wg upgrade --accept-source-agreements | Out-Host }; Wait-WNKey }
            'refresh' { [void](Get-WNInstalledAppIds -Refresh) }
        }
    }
}
