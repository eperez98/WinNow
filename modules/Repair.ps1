# modules/Repair.ps1
# Repair & maintenance. Long operations run in the foreground and stream their output.

function Invoke-WNRepairStep {
    param([string]$Title, [scriptblock]$Action, [switch]$NeedsConfirm, [string]$Warning, [switch]$ReadOnly)
    Write-WNHeader $Title
    if ($Warning) { Write-Host "  $Warning" -ForegroundColor Yellow; Write-Host '' }
    if (-not (Test-WNCanChange)) { Wait-WNKey; return }
    if ($NeedsConfirm -and -not (Read-WNConfirm 'Continue?')) { return }
    if (-not $ReadOnly -and -not (Start-WNChange -Label $Title)) { return }
    Write-WNLog "Repair: $Title" -Component 'Repair'
    $start = Get-Date
    try { & $Action } catch { Write-WNStatus "$Title failed: $($_.Exception.Message)" Error 'Repair' }
    Write-Host ''
    Write-WNStatus ("{0} finished in {1:mm\:ss}" -f $Title, ((Get-Date) - $start)) Ok 'Repair'
    Wait-WNKey
}

function Reset-WNWindowsUpdateComponents {
    $services = 'BITS', 'wuauserv', 'appidsvc', 'cryptsvc'
    if ($WN.DryRun) { Write-WNStatus "Would stop $($services -join ', '), rename SoftwareDistribution\Download and catroot2, re-register and restart" Dry 'Repair'; return }
    foreach ($s in $services) { Write-WNStatus "Stopping $s" Step; Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    Remove-Item "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($dir in @("$env:SystemRoot\SoftwareDistribution\Download", "$env:SystemRoot\System32\catroot2")) {
        if (Test-Path $dir) {
            try { Rename-Item $dir "$(Split-Path $dir -Leaf).bak$stamp" -ErrorAction Stop; Write-WNStatus "Renamed $dir" Ok }
            catch { Write-WNStatus "Could not rename $dir : $($_.Exception.Message)" Warn }
        }
    }
    Push-Location "$env:SystemRoot\System32"
    foreach ($dll in 'atl.dll', 'urlmon.dll', 'mshtml.dll', 'msxml3.dll', 'msxml6.dll', 'wuapi.dll', 'wuaueng.dll', 'wups.dll', 'wups2.dll', 'qmgr.dll') {
        if (Test-Path $dll) { regsvr32.exe /s $dll }
    }
    Pop-Location
    foreach ($s in $services) { Write-WNStatus "Starting $s" Step; Start-Service -Name $s -ErrorAction SilentlyContinue }
    Write-WNStatus 'Windows Update components reset. Check for updates again in Settings.' Ok
}

function Show-WNRepairMenu {
    while ($true) {
        $items = @(
            @{ Separator = $true; Label = 'System files' }
            @{ Label = 'SFC /scannow'; Value = 'sfc'; Hint = 'Scans and repairs protected system files (5-15 min)' }
            @{ Label = 'DISM CheckHealth + ScanHealth'; Value = 'dismscan'; Hint = 'Checks the component store for corruption, changes nothing' }
            @{ Label = 'DISM RestoreHealth'; Value = 'dismfix'; Hint = 'Repairs the component store using Windows Update (10-30 min)' }
            @{ Label = 'Full repair (DISM RestoreHealth, then SFC)'; Value = 'full'; Hint = 'Recommended order when Windows is misbehaving' }
            @{ Label = 'Check disk (chkdsk /scan, online)'; Value = 'chkdsk'; Hint = 'Read-only online scan of the system drive' }
            @{ Separator = $true; Label = 'Cleanup' }
            @{ Label = 'Delete temporary files'; Value = 'temp'; Hint = 'User and Windows TEMP folders' }
            @{ Label = 'Disk Cleanup + component cleanup'; Value = 'cleanmgr'; Hint = 'cleanmgr with all handlers + DISM ResetBase' }
            @{ Separator = $true; Label = 'Network / Store / Update' }
            @{ Label = 'Flush DNS cache'; Value = 'dns'; Hint = 'ipconfig /flushdns' }
            @{ Label = 'Reset network stack'; Value = 'net'; Hint = 'Winsock + TCP/IP reset, release/renew. Needs a reboot' }
            @{ Label = 'Reset Windows Update components'; Value = 'wu'; Hint = 'Stops services, renames caches, re-registers DLLs' }
            @{ Label = 'Reset Microsoft Store cache'; Value = 'store'; Hint = 'wsreset.exe' }
            @{ Label = 'Reset winget sources'; Value = 'winget'; Hint = 'winget source reset --force' }
        )
        $choice = Show-WNMenu -Title 'Repair & Maintenance' -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'sfc'      { Invoke-WNRepairStep 'SFC /scannow' { [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
            'dismscan' { Invoke-WNRepairStep 'DISM scan' -ReadOnly { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/CheckHealth') 'Repair'); [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/ScanHealth') 'Repair') } }
            'dismfix'  { Invoke-WNRepairStep 'DISM RestoreHealth' { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair') } }
            'full'     { Invoke-WNRepairStep 'Full repair' { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair'); [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
            'chkdsk'   { Invoke-WNRepairStep 'Check disk' -ReadOnly { [void](Invoke-WNNative 'chkdsk.exe' @($env:SystemDrive, '/scan') 'Repair') } }
            'temp'     { Invoke-WNRepairStep 'Delete temporary files' { if ($WN.DryRun) { Write-WNStatus "Would empty $env:TEMP and $env:SystemRoot\Temp" Dry } else { Invoke-WNDeleteTempFiles } } }
            'cleanmgr' { Invoke-WNRepairStep 'Disk Cleanup' { if ($WN.DryRun) { Write-WNStatus 'Would run cleanmgr /sagerun:64 and DISM StartComponentCleanup /ResetBase' Dry } else { Invoke-WNDiskCleanup } } }
            'dns'      { Invoke-WNRepairStep 'Flush DNS' -ReadOnly { [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair') } }
            'net'      { Invoke-WNRepairStep 'Reset network stack' -NeedsConfirm -Warning 'You will lose connectivity for a moment and must reboot afterwards.' {
                            [void](Invoke-WNNative 'netsh.exe' @('winsock', 'reset') 'Repair')
                            [void](Invoke-WNNative 'netsh.exe' @('int', 'ip', 'reset') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/release') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/renew') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair')
                            Write-Host '  Reboot to complete the reset.' -ForegroundColor Yellow } }
            'wu'       { Invoke-WNRepairStep 'Reset Windows Update' -NeedsConfirm { Reset-WNWindowsUpdateComponents } }
            'store'    { Invoke-WNRepairStep 'Reset Store cache' { [void](Invoke-WNNative 'wsreset.exe' @() 'Repair') } }
            'winget'   { Invoke-WNRepairStep 'Reset winget sources' { [void](Invoke-WNWinget @('source', 'reset', '--force')) } }
        }
    }
}
