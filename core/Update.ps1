# core/Update.ps1
# Update check against the GitHub releases, in-place updater, and the desktop shortcut.

$script:WNRepoSlug = 'eperez98/Winnow'

function ConvertTo-WNVersion {
    param([string]$Text)
    $v = $null
    if ([version]::TryParse(("$Text".Trim() -replace '^[vV]', ''), [ref]$v)) { return $v }
    return $null
}

function ConvertFrom-WNChangelog {
    # CHANGELOG.md lines -> the sections of every version newer than $Since, without markdown noise
    param([string[]]$Lines, [version]$Since)
    $out = New-Object System.Collections.Generic.List[string]
    $take = $false
    foreach ($l in $Lines) {
        if ($l -match '^## \[([^\]]+)\]') {
            $v = ConvertTo-WNVersion $matches[1]
            $take = [bool]($v -and $v -gt $Since)
            if ($take) { $out.Add(($l -replace '^## ', '')) }
            continue
        }
        if ($l -match '^\[[^\]]+\]: ') { continue }
        if ($take) { $out.Add((($l -replace '\*\*', '') -replace '`', '')) }
    }
    # Drop the blank line that ends the last section
    while ($out.Count -and -not $out[$out.Count - 1].Trim()) { $out.RemoveAt($out.Count - 1) }
    return $out.ToArray()
}

function Get-WNUpdateInfo {
    # Asks GitHub for the latest release. Never throws: $null when offline, otherwise
    # @{ Newer; Version; Tag; Url; Zip; Notes } where Notes are the CHANGELOG sections since this version.
    param([int]$TimeoutSec = 5)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
        $headers = @{ 'User-Agent' = 'Winnow'; 'Accept' = 'application/vnd.github+json' }
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$script:WNRepoSlug/releases/latest" -Headers $headers -TimeoutSec $TimeoutSec -UseBasicParsing
        $latest = ConvertTo-WNVersion $rel.tag_name
        $current = ConvertTo-WNVersion $WN.Version
        $newer = [bool]($latest -and $current -and $latest -gt $current)
        Write-WNLog "Update check: latest $($rel.tag_name), installed $($WN.Version), newer=$newer" -Component 'Update'
        $notes = @()
        if ($newer) {
            try {
                $md = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$script:WNRepoSlug/$($rel.tag_name)/CHANGELOG.md" -Headers @{ 'User-Agent' = 'Winnow' } -TimeoutSec $TimeoutSec -UseBasicParsing
                $notes = ConvertFrom-WNChangelog ($md -split "`r?`n") $current
            } catch { }
            # Older tags may not have a CHANGELOG; the release text is the fallback
            if (-not $notes.Count) { $notes = @("$($rel.body)" -split "`r?`n" | Where-Object { $_ -notmatch '^\s*!\[' }) }
        }
        return [pscustomobject]@{
            Newer   = $newer
            Version = "$latest"
            Tag     = $rel.tag_name
            Url     = $rel.html_url
            Zip     = ($rel.assets | Where-Object { $_.name -eq 'Winnow.zip' } | Select-Object -First 1).browser_download_url
            Notes   = @($notes)
        }
    } catch {
        Write-WNLog "Update check failed: $($_.Exception.Message)" -Level WARN -Component 'Update'
        return $null
    }
}

function Install-WNUpdate {
    # Downloads the release zip and puts it in place of this copy. The code folders are swapped as a whole
    # (old ones kept until the copy succeeds) so a failed update never leaves a half-updated Winnow.
    param([Parameter(Mandatory)]$Update, [string]$Root = $WN.Root)
    if ($WN.DryRun) { Write-WNStatus (T 'au.dry' $Update.Version) Dry 'Update'; return $false }
    if (-not $Update.Zip) { Write-WNStatus (T 'au.failed' 'Winnow.zip' $WN.Version) Error 'Update'; return $false }
    $tmp = Join-Path $env:TEMP "Winnow-update-$PID"
    $zip = "$tmp.zip"
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    $moved = @()
    try {
        Write-WNStatus (T 'au.downloading' $Update.Version) Step 'Update'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Update.Zip -OutFile $zip -UseBasicParsing -TimeoutSec 120
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        if (-not (Test-Path (Join-Path $tmp 'Winnow.ps1'))) { throw 'Winnow.ps1 is missing from the package' }
        Get-ChildItem $tmp -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        foreach ($d in 'core', 'modules', 'gui', 'config') {
            $t = Join-Path $Root $d
            if (Test-Path $t) { Rename-Item -Path $t -NewName "$d.old-$stamp" -ErrorAction Stop; $moved += $d }
        }
        Copy-Item -Path (Join-Path $tmp '*') -Destination $Root -Recurse -Force -ErrorAction Stop
        foreach ($d in $moved) { Remove-Item (Join-Path $Root "$d.old-$stamp") -Recurse -Force -ErrorAction SilentlyContinue }
        Write-WNStatus (T 'au.done' $Update.Version) Ok 'Update'
        return $true
    } catch {
        foreach ($d in $moved) {
            $new = Join-Path $Root $d
            if (Test-Path $new) { Remove-Item $new -Recurse -Force -ErrorAction SilentlyContinue }
            Rename-Item -Path (Join-Path $Root "$d.old-$stamp") -NewName $d -ErrorAction SilentlyContinue
        }
        Write-WNStatus (T 'au.failed' $_.Exception.Message $WN.Version) Error 'Update'
        return $false
    } finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Restart-WNApp {
    # Starts the (updated) copy again with the same language and mode; this process should exit after it
    param([switch]$Gui)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $WN.Root 'Winnow.ps1')`"", '-Lang', $WN.Lang, '-NoUpdateCheck')
    if ($Gui) { $a = @('-STA') + $a + '-GUI' }
    if ($WN.DryRun) { $a += '-DryRun' }
    Start-Process powershell.exe -ArgumentList $a -WindowStyle $(if ($Gui) { 'Minimized' } else { 'Normal' })
}

function Show-WNUpdatePrompt {
    # Terminal: release notes and the three choices. Returns $true when Winnow was updated (caller restarts).
    param([Parameter(Mandatory)]$Update)
    Write-WNHeader (T 'au.title' $Update.Version)
    Write-Host ('  ' + (T 'au.versions' $WN.Version $Update.Version)) -ForegroundColor White
    Write-Host ''
    Write-Host ('  ' + (T 'au.notes')) -ForegroundColor Cyan
    $max = 34
    foreach ($l in @($Update.Notes | Select-Object -First $max)) {
        $color = if ($l -match '^\[') { 'Yellow' } elseif ($l -match '^###') { 'Cyan' } else { 'Gray' }
        Write-Host "   $($l -replace '^### ', '')" -ForegroundColor $color
    }
    if (@($Update.Notes).Count -gt $max) { Write-Host ('   ' + (T 'au.more' $Update.Url)) -ForegroundColor DarkGray }
    Write-Host ''
    Write-Host ('   1) ' + (T 'au.optUpdate' $Update.Version)) -ForegroundColor Green
    Write-Host ('   2) ' + (T 'au.optKeep' $WN.Version))
    Write-Host ('   3) ' + (T 'au.optSkip'))
    Write-Host ''
    $choice = $null
    if ($WN.Interactive) {
        Write-Host ('  ' + (T 'au.prompt')) -ForegroundColor Yellow -NoNewline
        Clear-WNKeyBuffer
        while (-not $choice) {
            $k = Read-WNKey
            if ("$($k.KeyChar)" -in '1', '2', '3') { $choice = "$($k.KeyChar)" }
            elseif ($k.Key -in 'Escape', 'Enter') { $choice = '2' }
        }
        Write-Host " $choice"
    } else {
        $choice = Read-Host ('  ' + (T 'au.prompt'))
    }
    switch ($choice) {
        '1' { $ok = Install-WNUpdate $Update; if (-not $ok) { Wait-WNKey }; return $ok }
        '3' { Save-WNSetting 'SkipVersion' $Update.Version; Write-WNStatus (T 'au.skipped' $Update.Version) Info 'Update'; Wait-WNKey }
    }
    return $false
}

function Invoke-WNUpdateCheck {
    # Startup (quiet unless there is something new) or manual (-Manual reports every outcome).
    # Returns $true when Winnow was updated and must restart.
    param([switch]$Manual)
    if ($Manual) { Write-WNHeader (T 'main.update') }
    Write-WNStatus (T 'au.checking') Info 'Update'
    $u = Get-WNUpdateInfo
    if (-not $u) { if ($Manual) { Write-WNStatus (T 'au.offline') Warn 'Update'; Wait-WNKey }; return $false }
    if (-not $u.Newer) { if ($Manual) { Write-WNStatus (T 'au.upToDate' $WN.Version) Ok 'Update'; Wait-WNKey }; return $false }
    if (-not $Manual -and (Get-WNSettings).SkipVersion -eq $u.Version) { return $false }
    return (Show-WNUpdatePrompt $u)
}

function New-WNShortcut {
    # Desktop shortcut with the Winnow logo that opens this copy directly. A copy started by the one-line
    # launcher lives in %TEMP% (replaced on every run), so it is first copied to a permanent folder.
    param(
        [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Winnow'),
        [string]$Path = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Winnow.lnk')
    )
    $temp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
    $target = if ([IO.Path]::GetFullPath($WN.Root).StartsWith($temp, [StringComparison]::OrdinalIgnoreCase)) { $InstallDir } else { $WN.Root }
    if ($WN.DryRun) { Write-WNStatus (T 'sc.dry' $Path (Join-Path $target 'Winnow.ps1')) Dry 'Shortcut'; return $true }
    try {
        if ($target -ne $WN.Root) {
            Write-WNStatus (T 'sc.copying' $target) Step 'Shortcut'
            if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
            # Same idea as the updater: code folders replaced as a whole, nothing stale left behind
            foreach ($d in 'core', 'modules', 'gui', 'config') { Remove-Item (Join-Path $target $d) -Recurse -Force -ErrorAction SilentlyContinue }
            Copy-Item -Path (Join-Path $WN.Root '*') -Destination $target -Recurse -Force -ErrorAction Stop
        }
        $shell = New-Object -ComObject WScript.Shell
        $s = $shell.CreateShortcut($Path)
        $s.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $target 'Winnow.ps1')`""
        $s.WorkingDirectory = $target
        $ico = Join-Path $target 'LOGO\Winnow.ico'
        if (Test-Path $ico) { $s.IconLocation = "$ico,0" }
        $s.Description = 'Winnow'
        $s.Save()
        Write-WNStatus (T 'sc.done' $Path) Ok 'Shortcut'
        return $true
    } catch {
        Write-WNStatus (T 'sc.failed' $_.Exception.Message) Error 'Shortcut'
        return $false
    }
}

function Show-WNShortcutOffer {
    # Asked once, on the first interactive start; K in the main menu creates it later
    Write-WNHeader (T 'sc.title')
    Write-Host ('  ' + (T 'sc.offerNote')) -ForegroundColor DarkGray
    Write-Host ''
    if (Read-WNConfirm (T 'sc.ask') -DefaultYes) { [void](New-WNShortcut); Wait-WNKey }
    Save-WNSetting 'ShortcutAsked' $true
}
