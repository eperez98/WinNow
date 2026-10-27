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

# Every repair task once, for the terminal menu and the GUI. Label / Hint are i18n keys or literal
# text (T returns unknown keys unchanged).
$script:RepairTasks = @(
    @{ Id = 'sfc'; Section = 'rep.secFiles'; Label = 'SFC /scannow'; Hint = 'rep.sfcHint'
       Action = { [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
    @{ Id = 'dismscan'; Section = 'rep.secFiles'; Label = 'rep.dismScan'; Hint = 'rep.dismScanHint'; ReadOnly = $true
       Action = { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/CheckHealth') 'Repair'); [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/ScanHealth') 'Repair') } }
    @{ Id = 'dismfix'; Section = 'rep.secFiles'; Label = 'DISM RestoreHealth'; Hint = 'rep.dismFixHint'
       Action = { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair') } }
    @{ Id = 'full'; Section = 'rep.secFiles'; Label = 'rep.full'; Hint = 'rep.fullHint'
       Action = { [void](Invoke-WNNative 'dism.exe' @('/Online', '/Cleanup-Image', '/RestoreHealth') 'Repair'); [void](Invoke-WNNative 'sfc.exe' @('/scannow') 'Repair') } }
    @{ Id = 'chkdsk'; Section = 'rep.secFiles'; Label = 'rep.chkdsk'; Hint = 'rep.chkdskHint'; ReadOnly = $true
       Action = { [void](Invoke-WNNative 'chkdsk.exe' @($env:SystemDrive, '/scan') 'Repair') } }
    @{ Id = 'temp'; Section = 'rep.secCleanup'; Label = 'rep.temp'; Hint = 'rep.tempHint'
       Action = { if ($WN.DryRun) { Write-WNStatus (T 'rep.dryTemp' $env:TEMP "$env:SystemRoot\Temp") Dry } else { Invoke-WNDeleteTempFiles } } }
    @{ Id = 'cleanmgr'; Section = 'rep.secCleanup'; Label = 'rep.cleanmgr'; Hint = 'rep.cleanmgrHint'
       Action = { if ($WN.DryRun) { Write-WNStatus (T 'rep.dryCleanmgr') Dry } else { Invoke-WNDiskCleanup } } }
    @{ Id = 'dns'; Section = 'rep.secNet'; Label = 'rep.dns'; Hint = 'ipconfig /flushdns'; ReadOnly = $true
       Action = { [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair') } }
    @{ Id = 'net'; Section = 'rep.secNet'; Label = 'rep.net'; Hint = 'rep.netHint'; NeedsConfirm = $true; Warning = 'rep.netWarn'
       Action = {
            [void](Invoke-WNNative 'netsh.exe' @('winsock', 'reset') 'Repair')
            [void](Invoke-WNNative 'netsh.exe' @('int', 'ip', 'reset') 'Repair')
            [void](Invoke-WNNative 'ipconfig.exe' @('/release') 'Repair')
            [void](Invoke-WNNative 'ipconfig.exe' @('/renew') 'Repair')
            [void](Invoke-WNNative 'ipconfig.exe' @('/flushdns') 'Repair')
            Write-Host ('  ' + (T 'rep.netReboot')) -ForegroundColor Yellow } }
    @{ Id = 'wu'; Section = 'rep.secNet'; Label = 'rep.wu'; Hint = 'rep.wuHint'; NeedsConfirm = $true
       Action = { Reset-WNWindowsUpdateComponents } }
    @{ Id = 'store'; Section = 'rep.secNet'; Label = 'rep.store'; Hint = 'wsreset.exe'
       Action = { [void](Invoke-WNNative 'wsreset.exe' @() 'Repair') } }
    @{ Id = 'winget'; Section = 'rep.secNet'; Label = 'rep.winget'; Hint = 'winget source reset --force'
       Action = { [void](Invoke-WNWinget @('source', 'reset', '--force')) } }
)

function Invoke-WNRepairTask {
    param([Parameter(Mandatory)][string]$Id)
    $t = $script:RepairTasks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $t) { return }
    $warn = if ($t.Warning) { T $t.Warning } else { $null }
    Invoke-WNRepairStep (T $t.Label) $t.Action -NeedsConfirm:([bool]$t.NeedsConfirm) -Warning $warn -ReadOnly:([bool]$t.ReadOnly)
}

function Show-WNRepairMenu {
    while ($true) {
        $items = @()
        $section = $null
        foreach ($t in $script:RepairTasks) {
            if ($t.Section -ne $section) { $section = $t.Section; $items += @{ Separator = $true; Label = (T $section) } }
            $items += @{ Label = (T $t.Label); Value = $t.Id; Hint = (T $t.Hint) }
        }
        $choice = Show-WNMenu -Title (T 'rep.title') -Items $items
        if (-not $choice) { return }
        Invoke-WNRepairTask $choice
    }
}
