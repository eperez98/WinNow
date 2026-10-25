# modules/Repair.ps1
# Repair & maintenance. Long operations run in the foreground and stream their output.

function Invoke-WNRepairStep {
    param([string]$Title, [scriptblock]$Action, [switch]$NeedsConfirm, [string]$Warning, [switch]$ReadOnly)
    Write-WNHeader $Title
    if ($Warning) { Write-Host "  $Warning" -ForegroundColor Yellow; Write-Host '' }
    if (-not (Test-WNCanChange)) { Wait-WNKey; return }
    if ($NeedsConfirm -and -not (Read-WNConfirm (T 'common.continue'))) { return }
    if (-not $ReadOnly -and -not (Start-WNChange -Label $Title)) { return }
    Write-WNLog "Repair: $Title" -Component 'Repair'
    $start = Get-Date
    try { & $Action } catch { Write-WNStatus (T 'rep.failed' $Title $_.Exception.Message) Error 'Repair' }
    Write-Host ''
    Write-WNStatus (T 'rep.finished' $Title ((Get-Date) - $start)) Ok 'Repair'
    Wait-WNKey
}

function Reset-WNWindowsUpdateComponents {
    $services = 'BITS', 'wuauserv', 'appidsvc', 'cryptsvc'
    if ($WN.DryRun) { Write-WNStatus (T 'rep.dryWu' ($services -join ', ')) Dry 'Repair'; return }
    foreach ($s in $services) { Write-WNStatus (T 'rep.stopping' $s) Step; Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
    Remove-Item "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($dir in @("$env:SystemRoot\SoftwareDistribution\Download", "$env:SystemRoot\System32\catroot2")) {
        if (Test-Path $dir) {
            try { Rename-Item $dir "$(Split-Path $dir -Leaf).bak$stamp" -ErrorAction Stop; Write-WNStatus (T 'rep.renamed' $dir) Ok }
            catch { Write-WNStatus (T 'rep.renameFail' $dir $_.Exception.Message) Warn }
        }
    }
    Push-Location "$env:SystemRoot\System32"
    foreach ($dll in 'atl.dll', 'urlmon.dll', 'mshtml.dll', 'msxml3.dll', 'msxml6.dll', 'wuapi.dll', 'wuaueng.dll', 'wups.dll', 'wups2.dll', 'qmgr.dll') {
        if (Test-Path $dll) { regsvr32.exe /s $dll }
    }
    Pop-Location
    foreach ($s in $services) { Write-WNStatus (T 'rep.starting' $s) Step; Start-Service -Name $s -ErrorAction SilentlyContinue }
    Write-WNStatus (T 'rep.wuDone') Ok
}

function Show-WNRepairMenu {
    while ($true) {
        $items = @(
            @{ Separator = $true; Label = (T 'rep.secFiles') }
            @{ Label = 'SFC /scannow'; Value = 'sfc'; Hint = (T 'rep.sfcHint') }
            @{ Label = (T 'rep.dismScan'); Value = 'dismscan'; Hint = (T 'rep.dismScanHint') }
            @{ Label = 'DISM RestoreHealth'; Value = 'dismfix'; Hint = (T 'rep.dismFixHint') }
            @{ Label = (T 'rep.full'); Value = 'full'; Hint = (T 'rep.fullHint') }
            @{ Label = (T 'rep.chkdsk'); Value = 'chkdsk'; Hint = (T 'rep.chkdskHint') }
            @{ Separator = $true; Label = (T 'rep.secCleanup') }
            @{ Label = (T 'rep.temp'); Value = 'temp'; Hint = (T 'rep.tempHint') }
            @{ Label = (T 'rep.cleanmgr'); Value = 'cleanmgr'; Hint = (T 'rep.cleanmgrHint') }
            @{ Separator = $true; Label = (T 'rep.secNet') }
            @{ Label = (T 'rep.dns'); Value = 'dns'; Hint = 'ipconfig /flushdns' }
            @{ Label = (T 'rep.net'); Value = 'net'; Hint = (T 'rep.netHint') }
            @{ Label = (T 'rep.wu'); Value = 'wu'; Hint = (T 'rep.wuHint') }
            @{ Label = (T 'rep.store'); Value = 'store'; Hint = 'wsreset.exe' }
            @{ Label = (T 'rep.winget'); Value = 'winget'; Hint = 'winget source reset --force' }
        )
        $choice = Show-WNMenu -Title (T 'rep.title') -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'sfc'      { Invoke-WNRepairStep 'SFC /scannow' { [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
            'dismscan' { Invoke-WNRepairStep (T 'rep.dismScan') -ReadOnly { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/CheckHealth') 'Repair'); [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/ScanHealth') 'Repair') } }
            'dismfix'  { Invoke-WNRepairStep 'DISM RestoreHealth' { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair') } }
            'full'     { Invoke-WNRepairStep (T 'rep.full') { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair'); [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
            'chkdsk'   { Invoke-WNRepairStep (T 'rep.chkdsk') -ReadOnly { [void](Invoke-WNNative 'chkdsk.exe' @($env:SystemDrive, '/scan') 'Repair') } }
            'temp'     { Invoke-WNRepairStep (T 'rep.temp') { if ($WN.DryRun) { Write-WNStatus (T 'rep.dryTemp' $env:TEMP "$env:SystemRoot\Temp") Dry } else { Invoke-WNDeleteTempFiles } } }
            'cleanmgr' { Invoke-WNRepairStep (T 'rep.cleanmgr') { if ($WN.DryRun) { Write-WNStatus (T 'rep.dryCleanmgr') Dry } else { Invoke-WNDiskCleanup } } }
            'dns'      { Invoke-WNRepairStep (T 'rep.dns') -ReadOnly { [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair') } }
            'net'      { Invoke-WNRepairStep (T 'rep.net') -NeedsConfirm -Warning (T 'rep.netWarn') {
                            [void](Invoke-WNNative 'netsh.exe' @('winsock', 'reset') 'Repair')
                            [void](Invoke-WNNative 'netsh.exe' @('int', 'ip', 'reset') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/release') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/renew') 'Repair')
                            [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair')
                            Write-Host ('  ' + (T 'rep.netReboot')) -ForegroundColor Yellow } }
            'wu'       { Invoke-WNRepairStep (T 'rep.wu') -NeedsConfirm { Reset-WNWindowsUpdateComponents } }
            'store'    { Invoke-WNRepairStep (T 'rep.store') { [void](Invoke-WNNative 'wsreset.exe' @() 'Repair') } }
            'winget'   { Invoke-WNRepairStep (T 'rep.winget') { [void](Invoke-WNWinget @('source', 'reset', '--force')) } }
        }
    }
}
