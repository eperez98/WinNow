# modules/System.ps1
# System information, logs and session settings.

function Get-WNSystemInfo {
    # Rows (label -> value) and disks, shared by the terminal screen and the GUI page
    $os  = Get-CimInstance Win32_OperatingSystem
    $cs  = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object Name) -join ', '
    $ubr = Get-WNRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'UBR'
    $ver = Get-WNRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
    $up  = (Get-Date) - $os.LastBootUpTime
    $wg  = Find-WNWinget
    $wgv = if ($wg) { (& $wg --version 2>$null) } else { T 'sys.notFound' }
    $rows = [ordered]@{
        (T 'sys.computer') = $env:COMPUTERNAME
        'Windows'    = "$($os.Caption) $ver (build $($WN.OSBuild).$ubr)"
        'CPU'        = $cpu.Name.Trim()
        'RAM'        = T 'sys.ram' ($cs.TotalPhysicalMemory / 1GB) ($os.FreePhysicalMemory * 1KB / 1GB)
        'GPU'        = $gpu
        (T 'sys.uptime') = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
        'PowerShell' = "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
        'winget'     = $wgv
        (T 'sys.logFile') = $WN.LogFile
    }
    $disks = foreach ($d in Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') {
        [pscustomobject]@{ Drive = $d.DeviceID; UsedPct = $(if ($d.Size) { 100 - [int](100 * $d.FreeSpace / $d.Size) } else { 0 }); FreeGB = $d.FreeSpace / 1GB; SizeGB = $d.Size / 1GB }
    }
    @{ Rows = $rows; Disks = @($disks) }
}

function Show-WNSystemInfo {
    Write-WNHeader (T 'sys.title')
    Write-WNStatus (T 'sys.collecting') Info
    $info = Get-WNSystemInfo
    Write-Host ''
    foreach ($k in $info.Rows.Keys) { Write-Host ("   {0,-14} {1}" -f $k, $info.Rows[$k]) -ForegroundColor Gray }
    Write-Host ''
    foreach ($d in $info.Disks) {
        $bar = ('#' * [int]($d.UsedPct / 5)).PadRight(20, '.')
        $color = if ($d.UsedPct -ge 90) { 'Red' } elseif ($d.UsedPct -ge 75) { 'Yellow' } else { 'Green' }
        Write-Host ('   ' + (T 'sys.disk' $d.Drive $bar $d.UsedPct $d.FreeGB $d.SizeGB)) -ForegroundColor $color
    }
    Wait-WNKey
}

function Show-WNLogsMenu {
    while ($true) {
        $items = @(
            @{ Label = (T 'logs.tail'); Value = 'tail'; Hint = $WN.LogFile }
            @{ Label = (T 'logs.errors'); Value = 'errors'; Hint = (T 'logs.errorsHint') }
            @{ Label = (T 'logs.folder'); Value = 'folder'; Hint = (Split-Path $WN.LogFile) }
            @{ Label = (T 'logs.notepad'); Value = 'notepad'; Hint = $WN.LogFile }
        )
        $choice = Show-WNMenu -Title (T 'logs.title') -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'tail'    { Show-WNText (T 'logs.tailTitle') @(Get-Content $WN.LogFile -Tail 60 -ErrorAction SilentlyContinue) }
            'errors'  { Show-WNText (T 'logs.errorsTitle') @(Get-ChildItem (Split-Path $WN.LogFile) -Filter '*.log' | Sort-Object Name | Get-Content | Where-Object { $_ -match '\]\[(WARN|ERROR)\]' } | Select-Object -Last 200) }
            'folder'  { Start-Process explorer.exe (Split-Path $WN.LogFile) }
            'notepad' { Start-Process notepad.exe $WN.LogFile }
        }
    }
}

function Show-WNBackupDetail {
    param($Backup)
    $lines = @((T 'bkm.dCreated' $Backup.Created), (T 'bkm.dAction' $Backup.Label), (T 'bkm.dFile' $Backup.File), '')
    if (@($Backup.Items).Count) { $lines += T 'bkm.dItems' (@($Backup.Items) -join ', '); $lines += '' }
    foreach ($r in @($Backup.Registry)) { if ($r) { $lines += "REG  $($r.Path)\$($r.Name) = $(if ($r.Exists) { "$($r.Data) ($($r.Kind))" } else { T 'bkm.dNotSet' })" } }
    foreach ($s in @($Backup.Services)) { if ($s) { $lines += "SVC  $($s.Name) = $($s.Startup)" } }
    foreach ($d in @($Backup.Dns)) { if ($d) { $lines += "DNS  $($d.Name) = $(if ($d.IPv4 -or $d.IPv6) { "$($d.IPv4) $($d.IPv6)".Trim() } else { 'DHCP' })" } }
    if (@($Backup.Apps).Count) { $lines += T 'bkm.dApps' @($Backup.Apps).Count }
    Show-WNText (T 'bkm.detailTitle' $Backup.Label) $lines
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
    $lines = if ($rps.Count) { $rps | ForEach-Object { '#{0,-4} {1:yyyy-MM-dd HH:mm}  {2}' -f $_.Sequence, $_.Created, $_.Description } } else { @(T 'bkm.rpNone') }
    Show-WNText (T 'bkm.rpListTitle' $rps.Count) @($lines)
}

function Remove-WNRestorePoints {
    # Restore points live in Volume Shadow Copies; only the system drive is touched
    # (never shadow copies on other drives).
    param([ValidateSet('Oldest', 'All')][string]$Mode)
    Write-WNHeader (T 'bkm.delRpTitle')
    if (-not (Test-WNCanChange)) { Wait-WNKey; return }
    $rps = @(Get-WNRestorePointList)
    if ($rps.Count -eq 0) { Write-WNStatus (T 'bkm.noRp') Info; Wait-WNKey; return }
    if ($Mode -eq 'Oldest') {
        $old = $rps | Sort-Object Created | Select-Object -First 1
        Write-Host ('  ' + (T 'bkm.oldest' $old.Sequence $old.Created $old.Description)) -ForegroundColor Yellow
        if (-not (Read-WNConfirm (T 'bkm.deleteIt'))) { return }
    } else {
        Write-Host ('  ' + (T 'bkm.allWarn1' $rps.Count $env:SystemDrive)) -ForegroundColor Red
        Write-Host ('  ' + (T 'bkm.allWarn2')) -ForegroundColor Red
        if ((Read-WNText (T 'bkm.typeDelete')) -ne 'DELETE') { Write-WNStatus (T 'common.cancelled') Skip; Wait-WNKey; return }
    }
    Remove-WNShadowCopies -Mode $Mode
    Wait-WNKey
}

function Remove-WNShadowCopies {
    # No prompts: callers confirm first (terminal screens above, GUI dialogs)
    param([ValidateSet('Oldest', 'All')][string]$Mode)
    $vssArgs = @('delete', 'shadows', "/for=$env:SystemDrive", $(if ($Mode -eq 'Oldest') { '/oldest' } else { '/all' }), '/quiet')
    $code = Invoke-WNNative -FilePath 'vssadmin.exe' -ArgumentList $vssArgs -Component 'Restore'
    if ($code -eq 0) { Write-WNStatus (T 'bkm.rpDeleted' $Mode) $(if ($WN.DryRun) { 'Dry' } else { 'Ok' }) 'Restore' }
    else { Write-WNStatus (T 'bkm.vssFail' $code) Error 'Restore' }
    # This session's automatic restore point may be gone now; make a new one before the next change
    $WN.RestorePointDone = $false
}

function Remove-WNBackupFiles {
    $backups = @(Get-WNBackups)
    if ($backups.Count -eq 0) { Write-WNHeader (T 'bkm.delTitle'); Write-WNStatus (T 'bkm.noBackups') Info; Wait-WNKey; return }
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
    $r = Show-WNCheckList -Title (T 'bkm.delTitle') -Subtitle (T 'bkm.delSubtitle') -Items @($items) -EnterLabel (T 'enter.delete')
    if (-not $r) { return }
    Write-WNHeader (T 'bkm.delConfirmTitle' @($r.Items).Count)
    $r.Items | ForEach-Object { Write-Host "   - $($_.Created)  $($_.Label)" }
    Write-Host ''
    Write-Host ('  ' + (T 'bkm.delWarn')) -ForegroundColor Yellow
    if (-not (Test-WNCanChange) -or -not (Read-WNConfirm (T 'bkm.delAsk'))) { Wait-WNKey; return }
    foreach ($b in $r.Items) { Remove-WNBackupFile $b.File }
    Wait-WNKey
}

function Remove-WNBackupFile {
    param([Parameter(Mandatory)][string]$File)
    if ($WN.DryRun) { Write-WNStatus (T 'bkm.dryDel' $File) Dry 'Backup'; return }
    try { Remove-Item -LiteralPath $File -Force -ErrorAction Stop; Write-WNStatus (T 'bkm.deleted' (Split-Path $File -Leaf)) Ok 'Backup' }
    catch { Write-WNStatus (T 'bkm.delFail' (Split-Path $File -Leaf) $_.Exception.Message) Error 'Backup' }
}

function Show-WNBackupsMenu {
    while ($true) {
        $backups = @(Get-WNBackups | Select-Object -First 40)
        $items = @(
            @{ Separator = $true; Label = (T 'bkm.secRp') }
            @{ Label = (T 'bkm.rpCreate'); Value = 'rp'; Hotkey = 'r'; Hint = (T 'bkm.rpCreateHint') }
            @{ Label = (T 'bkm.rpList'); Value = 'rplist'; Hotkey = 'l'; Hint = (T 'bkm.rpListHint') }
            @{ Label = (T 'bkm.rstrui'); Value = 'rstrui'; Hotkey = 'w'; Hint = (T 'bkm.rstruiHint') }
            @{ Label = (T 'bkm.rpOld'); Value = 'rpold'; Hotkey = 'o'; Hint = (T 'bkm.rpOldHint') }
            @{ Label = (T 'bkm.rpAll'); Value = 'rpall'; Hotkey = 'x'; Hint = (T 'bkm.rpAllHint') }
            @{ Separator = $true; Label = (T 'bkm.secBackups') }
            @{ Label = (T 'bkm.bDel'); Value = 'bdel'; Hotkey = 'd'; Hint = (T 'bkm.bDelHint') }
            @{ Label = (T 'bkm.folder'); Value = 'folder'; Hotkey = 'f'; Hint = (Get-WNBackupDir) }
            @{ Separator = $true; Label = (T 'bkm.secRestore' $backups.Count) }
        )
        $n = 0
        foreach ($b in $backups) {
            $n++
            $count = @($b.Registry).Count + @($b.Services).Count + @($b.Dns).Count
            $items += @{ Label = (T 'bkm.item' $b.Created $b.Label $count); Value = "b:$($b.File)"; Hotkey = "$(if ($n -le 9) { $n } else { [char](96 + $n) })"; Hint = (T 'bkm.itemHint') }
            if ($n -ge 9) { break }
        }
        if ($backups.Count -gt 9) { $items += @{ Label = (T 'bkm.older' ($backups.Count - 9)); Value = 'folder'; Hotkey = 'm' } }

        $choice = Show-WNMenu -Title (T 'bkm.title') -Subtitle (T 'bkm.subtitle') -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'rp'     { Write-WNHeader (T 'bkm.rpTitle'); if (Test-WNCanChange) { [void](New-WNRestorePoint -Force) }; Wait-WNKey }
            'rstrui' { Start-Process rstrui.exe }
            'rplist' { Show-WNRestorePoints }
            'rpold'  { Remove-WNRestorePoints -Mode Oldest }
            'rpall'  { Remove-WNRestorePoints -Mode All }
            'bdel'   { Remove-WNBackupFiles }
            'folder' { Start-Process explorer.exe (Get-WNBackupDir) }
            'b:*' {
                $b = $backups | Where-Object { $_.File -eq $choice.Substring(2) } | Select-Object -First 1
                Show-WNBackupDetail $b
                Write-WNHeader (T 'bkm.restoreTitle' $b.Label)
                if ((Test-WNCanChange) -and (Read-WNConfirm (T 'bkm.restoreAsk' $b.Created))) { Restore-WNBackup -Backup $b }
                Wait-WNKey
            }
        }
    }
}
