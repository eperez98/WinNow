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
        # The package carries both editions; it is as new as the newer of the two labels
        $current = @((ConvertTo-WNVersion $WN.Version), (ConvertTo-WNVersion $WN.GuiVersion)) | Sort-Object -Descending | Select-Object -First 1
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

function Get-WNTreeHashes {
    # SHA256 of every file under a folder, keyed by its relative path
    param([Parameter(Mandatory)][string]$Path)
    $h = @{}
    $cut = ([IO.Path]::GetFullPath($Path).TrimEnd('\')).Length + 1
    foreach ($f in Get-ChildItem -LiteralPath $Path -Recurse -File -Force) { $h[$f.FullName.Substring($cut)] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash }
    return $h
}

function Save-WNUpdate {
    # Downloads and unpacks the release in %TEMP%. Returns @{ Path; Hashes } (Hashes are checked again before the
    # files are installed), or $null; this copy is not touched yet.
    param([Parameter(Mandatory)]$Update)
    if (-not $Update.Zip) { Write-WNStatus (T 'au.failed' 'Winnow.zip' $WN.Version) Error 'Update'; return $null }
    $tmp = Join-Path $env:TEMP "Winnow-update-$PID"
    $zip = "$tmp.zip"
    try {
        Write-WNStatus (T 'au.downloading' $Update.Version) Step 'Update'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Update.Zip -OutFile $zip -UseBasicParsing -TimeoutSec 120
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        if (-not (Test-Path (Join-Path $tmp 'Winnow.ps1'))) { throw 'Winnow.ps1 is missing from the package' }
        Get-ChildItem $tmp -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Path = $tmp; Hashes = (Get-WNTreeHashes $tmp) }
    } catch {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-WNStatus (T 'au.failed' $_.Exception.Message $WN.Version) Error 'Update'
        return $null
    } finally {
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }
}

function Install-WNUpdate {
    # Puts a release in place of this copy: downloads it first unless -Staged gives what Save-WNUpdate returned.
    # Every top-level file and folder the package brings is set aside before the copy and put back if anything
    # fails, so a failed update never leaves a mix of two versions.
    param([Parameter(Mandatory)]$Update, [string]$Root = $WN.Root, $Staged)
    if ($WN.DryRun) { Write-WNStatus (T 'au.dry' $Update.Version) Dry 'Update'; return $false }
    $stage = if ($Staged) { $Staged } else { Save-WNUpdate $Update }
    if (-not $stage -or -not (Test-Path (Join-Path $stage.Path 'Winnow.ps1'))) { return $false }
    $tmp = $stage.Path
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    $moved = @(); $added = @()
    try {
        # The staged files waited in a folder this user can write: install them only if they are unchanged
        $now = Get-WNTreeHashes $tmp
        $changed = @($stage.Hashes.Keys | Where-Object { $now[$_] -ne $stage.Hashes[$_] })
        if ($now.Count -ne $stage.Hashes.Count -or $changed.Count) { throw (T 'au.tampered') }
        $items = @(Get-ChildItem -LiteralPath $tmp -Force | ForEach-Object Name)
        $added = @($items | Where-Object { -not (Test-Path -LiteralPath (Join-Path $Root $_)) })
        foreach ($n in $items) {
            if ($n -in $added) { continue }
            Rename-Item -LiteralPath (Join-Path $Root $n) -NewName "$n.old-$stamp" -ErrorAction Stop
            $moved += $n
        }
        Copy-Item -Path (Join-Path $tmp '*') -Destination $Root -Recurse -Force -ErrorAction Stop
        foreach ($n in $moved) { Remove-Item -LiteralPath (Join-Path $Root "$n.old-$stamp") -Recurse -Force -ErrorAction SilentlyContinue }
        Write-WNStatus (T 'au.done' $Update.Version) Ok 'Update'
        return $true
    } catch {
        foreach ($n in $moved + $added) {
            $new = Join-Path $Root $n
            if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Recurse -Force -ErrorAction SilentlyContinue }
        }
        foreach ($n in $moved) { Rename-Item -LiteralPath (Join-Path $Root "$n.old-$stamp") -NewName $n -ErrorAction SilentlyContinue }
        Write-WNStatus (T 'au.failed' $_.Exception.Message $WN.Version) Error 'Update'
        return $false
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-WNLaunchArgs {
    # powershell.exe arguments that start this copy in a given mode: the one place every relaunch builds them
    param([Parameter(Mandatory)][ValidateSet('GUI', 'Terminal')][string]$Mode, [string]$Lang = $WN.Lang, [switch]$NoUpdateCheck)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $WN.Root 'Winnow.ps1')`"", "-$Mode")
    if ($Mode -eq 'GUI') { $a = @('-STA') + $a + '-NoElevate' }
    if ($Lang) { $a += '-Lang', $Lang }
    if ($WN.DryRun) { $a += '-DryRun' }
    if ($NoUpdateCheck) { $a += '-NoUpdateCheck' }
    return $a
}

function Restart-WNApp {
    # Starts the (updated) copy again with the same language and mode; this process should exit after it
    param([switch]$Gui)
    $mode = if ($Gui) { 'GUI' } else { 'Terminal' }
    Start-Process powershell.exe -ArgumentList (Get-WNLaunchArgs $mode -NoUpdateCheck) -WindowStyle $(if ($Gui) { 'Minimized' } else { 'Normal' })
}

function Show-WNUpdatePrompt {
    # Terminal: release notes and the three choices. Returns $true when WinNow was updated (caller restarts).
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
    # Returns $true when WinNow was updated and must restart.
    param([switch]$Manual)
    if ($Manual) { Write-WNHeader (T 'main.update') }
    Write-WNStatus (T 'au.checking') Info 'Update'
    $u = Get-WNUpdateInfo
    if (-not $u) { if ($Manual) { Write-WNStatus (T 'au.offline') Warn 'Update'; Wait-WNKey }; return $false }
    if (-not $u.Newer) { if ($Manual) { Write-WNStatus (T 'au.upToDate' $WN.Version) Ok 'Update'; Wait-WNKey }; return $false }
    if (-not $Manual -and (Get-WNSettings).SkipVersion -eq $u.Version) { return $false }
    return (Show-WNUpdatePrompt $u)
}

function Test-WNTempCopy {
    # True for a copy the one-line launcher extracted below %TEMP% (replaced on every run, safe to remove)
    $temp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
    $root = [IO.Path]::GetFullPath($WN.Root).TrimEnd('\')
    return ($root.StartsWith("$temp\", [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath (Join-Path $root 'Winnow.ps1')))
}

function New-WNShortcut {
    # Desktop shortcut with the WinNow logo that opens this copy directly. A copy started by the one-line
    # launcher lives in %TEMP% (replaced on every run), so it is first copied to a permanent folder.
    param(
        [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Winnow'),
        [string]$Path = (Join-Path ([Environment]::GetFolderPath('Desktop')) 'WinNow.lnk')
    )
    $target = if (Test-WNTempCopy) { $InstallDir } else { $WN.Root }
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
        $saved = (Get-WNSettings).GuiTheme
        $patria = $saved -eq 'Patria' -or (-not $saved -and (Get-Date).Month -eq 11)
        $ico = Join-Path $target "LOGO\$(if ($patria) { 'Winnow_patria.ico' } else { 'Winnow.ico' })"
        if (Test-Path $ico) { $s.IconLocation = "$ico,0" }
        $s.Description = 'WinNow'
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

function Get-WNInstallDir { Join-Path $env:LOCALAPPDATA 'Programs\Winnow' }

function Test-WNManagedCopy {
    # Copies WinNow itself put on this PC (the download in %TEMP% or the shortcut copy); only these are ever deleted
    if (Test-WNTempCopy) { return $true }
    $install = [IO.Path]::GetFullPath((Get-WNInstallDir)).TrimEnd('\')
    return ([IO.Path]::GetFullPath($WN.Root).TrimEnd('\') -eq $install)
}

function Register-WNInstance {
    # Copies WinNow may delete on exit note every WinNow process running from them (one empty file per PID),
    # so the delete waits for all of them however they were started
    if (-not (Test-WNManagedCopy)) { return }
    $dir = Join-Path $WN.Root '.instances'
    try { New-Item -ItemType File -Path (Join-Path $dir "$PID") -Force | Out-Null } catch { }
}

function Remove-WNPathsOnExit {
    # A hidden helper waits until no WinNow process registered in these folders is alive (30 minutes at most),
    # then deletes the folders.
    param([Parameter(Mandatory)][string[]]$Paths)
    $list = ($Paths | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ', '
    $cmd = @"
`$dirs = @($list)
`$end = (Get-Date).AddMinutes(30)
do {
    Start-Sleep -Seconds 2
    `$busy = @(foreach (`$d in `$dirs) {
        Get-ChildItem -LiteralPath (Join-Path `$d '.instances') -Name -ErrorAction SilentlyContinue |
            Where-Object { `$_ -match '^\d+$' -and `$_ -ne "`$PID" -and (Get-Process -Id `$_ -ErrorAction SilentlyContinue | Where-Object { `$_.ProcessName -in 'powershell', 'pwsh' }) }
    })
} while (`$busy.Count -and (Get-Date) -lt `$end)
foreach (`$d in `$dirs) { Remove-Item -LiteralPath `$d -Recurse -Force -ErrorAction SilentlyContinue }
"@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-NonInteractive', '-EncodedCommand', $enc -WindowStyle Hidden -WorkingDirectory $env:SystemRoot
    Write-WNLog "Scheduled for removal after exit: $($Paths -join '; ')" -Component 'Cleanup'
}

function Uninstall-WNLocalCopy {
    # "No" on exit: remove what WinNow put on this PC, like an uninstall: the download in %TEMP%, the shortcut
    # copy in %LOCALAPPDATA%\Programs\Winnow and its desktop shortcut. Logs and backups in ProgramData are kept.
    $install = [IO.Path]::GetFullPath((Get-WNInstallDir)).TrimEnd('\')
    $dirs = @()
    if (Test-WNTempCopy) { $dirs += [IO.Path]::GetFullPath($WN.Root).TrimEnd('\') }
    if (Test-Path -LiteralPath (Join-Path $install 'Winnow.ps1')) { $dirs += $install }
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'WinNow.lnk'
    $ourLnk = $false
    if (Test-Path -LiteralPath $lnk) {
        try { $ourLnk = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk).Arguments.IndexOf($install, [StringComparison]::OrdinalIgnoreCase) -ge 0 } catch { }
    }
    if ($WN.DryRun) {
        foreach ($d in $dirs) { Write-WNStatus (T 'dl.dryDelete' $d) Dry 'Cleanup' }
        if ($ourLnk) { Write-WNStatus (T 'dl.dryDelete' $lnk) Dry 'Cleanup' }
        return
    }
    if ($ourLnk) { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }
    if ($dirs) { Remove-WNPathsOnExit -Paths $dirs }
    Save-WNSetting 'ShortcutAsked' $false
}

function Show-WNExitPrompt {
    # On exit, while there is no desktop shortcut yet (or from the download in %TEMP%): Yes = create it and keep
    # the files, No = remove WinNow's own copies. A folder you extracted yourself is never deleted, and No is
    # remembered for it. Skipped when another WinNow process takes over from these files (update restart).
    # -Owner: the window the dialogs belong to (the GUI asks while it is closing).
    param([switch]$Gui, $Owner)
    if ($WN.Handoff) { return }
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'WinNow.lnk'
    if (-not (Test-WNTempCopy) -and (Test-Path -LiteralPath $lnk)) { return }
    $managed = Test-WNManagedCopy
    $dir = [IO.Path]::GetFullPath($WN.Root).TrimEnd('\')
    if (-not $managed -and (Get-WNSettings).ShortcutDeclined -eq $dir) { return }
    $target = if (Test-WNTempCopy) { Get-WNInstallDir } else { $dir }
    $box = {
        param($text, $buttons = 'OK', $icon = 'Information')
        if ($Owner) { [Windows.MessageBox]::Show($Owner, $text, 'WinNow', $buttons, $icon) } else { [Windows.MessageBox]::Show($text, 'WinNow', $buttons, $icon) }
    }
    if ($Gui) {
        $msg = if ($managed) { T 'dl.gui' $dir (Get-WNInstallDir) } else { T 'dl.guiOwn' $dir }
        $choice = @{ Yes = 'shortcut'; No = 'no' }["$(& $box $msg 'YesNo' 'Question')"]
    } else {
        $no = if ($managed) { @{ Label = (T 'dl.delete'); Value = 'no'; Hint = (T 'dl.deleteHint' (Get-WNInstallDir)) } }
              else { @{ Label = (T 'dl.no'); Value = 'no'; Hint = (T 'dl.noHint') } }
        $items = @(@{ Label = (T 'dl.shortcut'); Value = 'shortcut'; Hint = (T 'dl.shortcutHint' $target) }, $no)
        $choice = Show-WNMenu -Title (T 'dl.title') -Subtitle (T 'dl.text' $dir) -Items $items -BackLabel (T 'dl.keep')
    }
    if ($choice -eq 'shortcut') {
        $ok = New-WNShortcut
        if ($ok) { Save-WNSetting 'ShortcutAsked' $true }
        if (-not $Gui) { Wait-WNKey }
        elseif (-not $ok) { [void](& $box (T 'sc.failedGui')) }
        elseif ($WN.DryRun) { [void](& $box (T 'sc.dryGui')) }
        else { [void](& $box (T 'dl.shortcutDone')) }
    } elseif ($choice -eq 'no' -and -not $managed) {
        Save-WNSetting 'ShortcutDeclined' $dir
    } elseif ($choice -eq 'no') {
        Uninstall-WNLocalCopy
        if ($Gui -and -not $WN.DryRun) { [void](& $box (T 'dl.deleting')) }
        elseif (-not $Gui -and -not $WN.DryRun) { Write-WNStatus (T 'dl.deleting') Ok 'Cleanup' }
    }
}
