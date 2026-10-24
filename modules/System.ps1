# modules/System.ps1
# System information, logs and session settings.

function Show-WNSystemInfo {
    Write-WNHeader 'System information'
    Write-WNStatus 'Collecting...' Info
    $os  = Get-CimInstance Win32_OperatingSystem
    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object Name) -join ', '
    $ubr = Get-WNRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'UBR'
    $ver = Get-WNRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
    $up  = (Get-Date) - $os.LastBootUpTime
    $wg  = Find-WNWinget
    $wgv = if ($wg) { (& $wg --version 2>$null) } else { 'not found' }
    $rows = [ordered]@{
        'Computer'   = $env:COMPUTERNAME
        'Windows'    = "$($os.Caption) $ver (build $($WN.OSBuild).$ubr)"
        'CPU'        = $cpu.Name.Trim()
        'RAM'        = '{0:N1} GB total, {1:N1} GB free' -f ($cs.TotalPhysicalMemory / 1GB), ($os.FreePhysicalMemory * 1KB / 1GB)
        'GPU'        = $gpu
        'Uptime'     = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
        'PowerShell' = "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
        'winget'     = $wgv
        'Log file'   = $WN.LogFile
    }
    Write-Host ''
    foreach ($k in $rows.Keys) { Write-Host ("   {0,-12} {1}" -f $k, $rows[$k]) -ForegroundColor Gray }
    Write-Host ''
    foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        $pct = if ($d.Size) { 100 - [int](100 * $d.FreeSpace / $d.Size) } else { 0 }
        $bar = ('#' * [int]($pct / 5)).PadRight(20, '.')
        $color = if ($pct -ge 90) { 'Red' } elseif ($pct -ge 75) { 'Yellow' } else { 'Green' }
        Write-Host ("   {0}  [{1}] {2,3}%  {3:N0} GB free of {4:N0} GB" -f $d.DeviceID, $bar, $pct, ($d.FreeSpace / 1GB), ($d.Size / 1GB)) -ForegroundColor $color
    }
    Wait-WNKey
}

function Show-WNLogsMenu {
    while ($true) {
        $items = @(
            @{ Label = 'Show last 60 lines of today''s log'; Value = 'tail'; Hint = $WN.LogFile }
            @{ Label = 'Show only warnings and errors'; Value = 'errors'; Hint = 'WARN / ERROR lines from all logs' }
            @{ Label = 'Open log folder'; Value = 'folder'; Hint = (Split-Path $WN.LogFile) }
            @{ Label = 'Open today''s log in Notepad'; Value = 'notepad'; Hint = $WN.LogFile }
        )
        $choice = Show-WNMenu -Title 'Logs' -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'tail'    { Show-WNText 'Log (last 60 lines)' @(Get-Content $WN.LogFile -Tail 60 -ErrorAction SilentlyContinue) }
            'errors'  { Show-WNText 'Warnings and errors' @(Get-ChildItem (Split-Path $WN.LogFile) -Filter '*.log' | Sort-Object Name | Get-Content | Where-Object { $_ -match '\]\[(WARN|ERROR)\]' } | Select-Object -Last 200) }
            'folder'  { Start-Process explorer.exe (Split-Path $WN.LogFile) }
            'notepad' { Start-Process notepad.exe $WN.LogFile }
        }
    }
}

function Show-WNBackupDetail {
    param($Backup)
    $lines = @("Created : $($Backup.Created)", "Action  : $($Backup.Label)", "File    : $($Backup.File)", '')
    if (@($Backup.Items).Count) { $lines += "Items   : $(@($Backup.Items) -join ', ')"; $lines += '' }
    foreach ($r in @($Backup.Registry)) { if ($r) { $lines += "REG  $($r.Path)\$($r.Name) = $(if ($r.Exists) { "$($r.Data) ($($r.Kind))" } else { '(not set)' })" } }
    foreach ($s in @($Backup.Services)) { if ($s) { $lines += "SVC  $($s.Name) = $($s.Startup)" } }
    foreach ($d in @($Backup.Dns)) { if ($d) { $lines += "DNS  $($d.Name) = $(if ($d.IPv4 -or $d.IPv6) { "$($d.IPv4) $($d.IPv6)".Trim() } else { 'DHCP' })" } }
    if (@($Backup.Apps).Count) { $lines += "APPS $(@($Backup.Apps).Count) installed apps recorded" }
    Show-WNText "Backup: $($Backup.Label)" $lines
}

function Get-WNRestorePointList {
    try {
        @(Get-ComputerRestorePoint -ErrorAction Stop | ForEach-Object {
            [pscustomobject]@{
                Sequence    = $_.SequenceNumber
                Created     = [Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime)
                Description = $_.Description
            }
        })
    } catch {
        Write-WNLog "Could not list restore points: $($_.Exception.Message)" -Level WARN -Component 'Restore'
        @()
    }
}

function Show-WNRestorePoints {
    $rps = @(Get-WNRestorePointList)
    $lines = if ($rps.Count) { $rps | ForEach-Object { '#{0,-4} {1:yyyy-MM-dd HH:mm}  {2}' -f $_.Sequence, $_.Created, $_.Description } } else { @('No restore points found (or System Protection is off).') }
    Show-WNText "System Restore Points ($($rps.Count))" @($lines)
}

function Remove-WNRestorePoints {
    # Restore points live in Volume Shadow Copies; only the system drive is touched
    # (never shadow copies on other drives).
    param([ValidateSet('Oldest', 'All')][string]$Mode)
    Write-WNHeader 'Delete restore points'
    if (-not (Test-WNCanChange)) { Wait-WNKey; return }
    $rps = @(Get-WNRestorePointList)
    if ($rps.Count -eq 0) { Write-WNStatus 'There are no restore points to delete.' Info; Wait-WNKey; return }
    if ($Mode -eq 'Oldest') {
        $old = $rps | Sort-Object Created | Select-Object -First 1
        Write-Host ("  Oldest restore point: #{0}  {1:yyyy-MM-dd HH:mm}  {2}" -f $old.Sequence, $old.Created, $old.Description) -ForegroundColor Yellow
        if (-not (Read-WNConfirm 'Delete it?')) { return }
        $vssArgs = @('delete', 'shadows', "/for=$env:SystemDrive", '/oldest', '/quiet')
    } else {
        Write-Host "  This deletes ALL $($rps.Count) restore points and shadow copies on $env:SystemDrive." -ForegroundColor Red
        Write-Host '  You will not be able to roll Windows back to any earlier state.' -ForegroundColor Red
        if ((Read-WNText 'Type DELETE to confirm') -ne 'DELETE') { Write-WNStatus 'Cancelled.' Skip; Wait-WNKey; return }
        $vssArgs = @('delete', 'shadows', "/for=$env:SystemDrive", '/all', '/quiet')
    }
    $code = Invoke-WNNative -FilePath 'vssadmin.exe' -ArgumentList $vssArgs -Component 'Restore'
    if ($code -eq 0) { Write-WNStatus "Restore points deleted ($Mode)." $(if ($WN.DryRun) { 'Dry' } else { 'Ok' }) 'Restore' }
    else { Write-WNStatus "vssadmin exit code $code" Error 'Restore' }
    # This session's automatic restore point may be gone now; make a new one before the next change
    $WN.RestorePointDone = $false
    Wait-WNKey
}

function Remove-WNBackupFiles {
    $backups = @(Get-WNBackups)
    if ($backups.Count -eq 0) { Write-WNHeader 'Delete backups'; Write-WNStatus 'There are no Winnow backups.' Info; Wait-WNKey; return }
    $items = foreach ($b in $backups) {
        $size = (Get-Item $b.File).Length
        [pscustomobject]@{
            Label    = "$($b.Created)  $($b.Label)"
            Value    = $b
            Detail   = "$($b.File)  ($([Math]::Ceiling($size / 1KB)) KB)"
            Tag      = '{0:N0} KB' -f [Math]::Ceiling($size / 1KB)
            TagColor = 'DarkGray'
        }
    }
    $r = Show-WNCheckList -Title 'Delete Winnow backups' -Subtitle 'Space to select, A for all, Enter to delete' -Items @($items) -EnterLabel 'delete'
    if (-not $r) { return }
    Write-WNHeader "Delete $(@($r.Items).Count) backup(s)"
    $r.Items | ForEach-Object { Write-Host "   - $($_.Created)  $($_.Label)" }
    Write-Host ''
    Write-Host '  Deleted backups cannot be restored afterwards.' -ForegroundColor Yellow
    if (-not (Test-WNCanChange) -or -not (Read-WNConfirm 'Delete these backups?')) { Wait-WNKey; return }
    foreach ($b in $r.Items) {
        if ($WN.DryRun) { Write-WNStatus "Would delete $($b.File)" Dry 'Backup'; continue }
        try { Remove-Item -LiteralPath $b.File -Force -ErrorAction Stop; Write-WNStatus "Deleted $(Split-Path $b.File -Leaf)" Ok 'Backup' }
        catch { Write-WNStatus "Could not delete $(Split-Path $b.File -Leaf): $($_.Exception.Message)" Error 'Backup' }
    }
    Wait-WNKey
}

function Show-WNBackupsMenu {
    while ($true) {
        $backups = @(Get-WNBackups | Select-Object -First 40)
        $items = @(
            @{ Separator = $true; Label = 'System Restore points' }
            @{ Label = 'Create restore point now'; Value = 'rp'; Hotkey = 'r'; Hint = 'Windows System Restore point (full system rollback)' }
            @{ Label = 'List restore points'; Value = 'rplist'; Hotkey = 'l'; Hint = 'Shows existing restore points with date and description' }
            @{ Label = 'Open System Restore (rstrui)'; Value = 'rstrui'; Hotkey = 'w'; Hint = 'Roll the whole system back to a restore point' }
            @{ Label = 'Delete the oldest restore point'; Value = 'rpold'; Hotkey = 'o'; Hint = 'Frees space, keeps the newer ones' }
            @{ Label = 'Delete ALL restore points'; Value = 'rpall'; Hotkey = 'x'; Hint = 'System drive only, asks you to type DELETE' }
            @{ Separator = $true; Label = 'Winnow backups' }
            @{ Label = 'Delete Winnow backups...'; Value = 'bdel'; Hotkey = 'd'; Hint = 'Choose which backup files to delete' }
            @{ Label = 'Open backups folder'; Value = 'folder'; Hotkey = 'f'; Hint = (Get-WNBackupDir) }
            @{ Separator = $true; Label = "Restore a backup ($($backups.Count)) - newest first" }
        )
        $n = 0
        foreach ($b in $backups) {
            $n++
            $count = @($b.Registry).Count + @($b.Services).Count + @($b.Dns).Count
            $items += @{ Label = ('{0}  {1}  ({2} values)' -f $b.Created, $b.Label, $count); Value = "b:$($b.File)"; Hotkey = "$(if ($n -le 9) { $n } else { [char](96 + $n) })"; Hint = 'Enter: view and restore' }
            if ($n -ge 9) { break }
        }
        if ($backups.Count -gt 9) { $items += @{ Label = "Older backups are in the backups folder ($($backups.Count - 9) more)"; Value = 'folder'; Hotkey = 'm' } }

        $choice = Show-WNMenu -Title 'Backups & restore' -Subtitle 'A backup is saved before every change' -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'rp'     { Write-WNHeader 'Restore point'; if (Test-WNCanChange) { [void](New-WNRestorePoint -Force) }; Wait-WNKey }
            'rstrui' { Start-Process rstrui.exe }
            'rplist' { Show-WNRestorePoints }
            'rpold'  { Remove-WNRestorePoints -Mode Oldest }
            'rpall'  { Remove-WNRestorePoints -Mode All }
            'bdel'   { Remove-WNBackupFiles }
            'folder' { Start-Process explorer.exe (Get-WNBackupDir) }
            'b:*' {
                $b = $backups | Where-Object { $_.File -eq $choice.Substring(2) } | Select-Object -First 1
                Show-WNBackupDetail $b
                Write-WNHeader "Restore backup: $($b.Label)"
                if ((Test-WNCanChange) -and (Read-WNConfirm "Restore the values saved on $($b.Created)?")) { Restore-WNBackup -Backup $b }
                Wait-WNKey
            }
        }
    }
}
