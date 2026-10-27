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
    # The leading comma returns the set itself; a bare return would unroll it into a fixed-size array
    if (-not $Refresh -and $WN.Cache.ContainsKey('InstalledApps')) { return ,$WN.Cache.InstalledApps }
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
    return ,$set
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

function ConvertFrom-WNWingetTable {
    # Parses winget's text table (search/list). Column starts come from the header words, which
    # winget localizes, so they are found by position rather than by name.
    # shortcut: wide (CJK) characters shift columns; switch to the Microsoft.WinGet.Client module if that matters.
    param([string[]]$Lines)
    $Lines = @($Lines | ForEach-Object { ($_ -split "`r")[-1] })
    $dash = [Array]::FindIndex([string[]]$Lines, [Predicate[string]] { param($l) $l -match '^-{10,}$' })
    if ($dash -lt 1 -or $dash -ge $Lines.Count - 1) { return }
    $starts = @([regex]::Matches($Lines[$dash - 1], '\S+') | ForEach-Object Index)
    if ($starts.Count -lt 3) { return }
    foreach ($l in $Lines[($dash + 1)..($Lines.Count - 1)]) {
        if ($l.Length -le $starts[2]) { continue }
        $id = $l.Substring($starts[1], $starts[2] - $starts[1]).Trim()
        # Ids cut with an ellipsis (narrow output) cannot be installed
        if (-not $id -or $id -match '\s' -or $id.EndsWith([string][char]0x2026)) { continue }
        $verEnd = if ($starts.Count -gt 3 -and $l.Length -gt $starts[3]) { $starts[3] } else { $l.Length }
        [pscustomobject]@{
            Name    = $l.Substring(0, $starts[1]).Trim()
            Id      = $id
            Version = $l.Substring($starts[2], $verEnd - $starts[2]).Trim()
        }
    }
}

function Search-WNWinget {
    # Returns catalog-shaped app objects so Show-WNAppList / Install-WNApps can use them as is
    param([Parameter(Mandatory)][string]$Query)
    $wg = Find-WNWinget
    if (-not $wg) { Write-WNStatus (T 'apps.noWinget') Error 'Apps'; return }
    Write-WNStatus (T 'apps.searching' $Query) Info 'Apps'
    $enc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        $out = & $wg search --query $Query --source winget --accept-source-agreements --disable-interactivity 2>$null
    } finally { [Console]::OutputEncoding = $enc }
    foreach ($r in (ConvertFrom-WNWingetTable @($out))) {
        [pscustomobject]@{ Name = $r.Name; Winget = $r.Id; Choco = 'na'; Description = "v$($r.Version)"; Category = $null; Foss = $false }
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
        # Re-read from winget so the INSTALLED tags match the PC when the list comes back
        if (-not $WN.DryRun) { [void](Get-WNInstalledAppIds -Refresh) }
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
        $items += @{ Label = (T 'apps.search'); Value = 'search'; Hotkey = 'w'; Hint = (T 'apps.searchHint') }
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
            'search' {
                Write-WNHeader (T 'apps.searchTitle')
                $q = Read-WNText (T 'apps.searchPrompt')
                if (-not $q) { break }
                $found = @(Search-WNWinget $q)
                if ($found.Count) { Show-WNAppList -Title (T 'apps.searchResults' $q $found.Count) -Apps $found }
                else { Write-WNStatus (T 'apps.searchNone' $q) Warn 'Apps'; Wait-WNKey }
            }
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
