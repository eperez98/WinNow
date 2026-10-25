# modules/Updates.ps1
# Windows Update policy: recommended (deferred), default, pause/resume.

$script:WUPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$script:WUAU     = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$script:WUUX     = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$script:WUDrv    = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'
$script:PauseNames = @('PauseUpdatesExpiryTime', 'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime', 'PauseUpdatesStartTime')

function Start-WNUpdateChange {
    param([string]$Label)
    # Every value this module can touch, so a backup can restore the exact previous policy
    $names = @{
        $script:WUAU     = @('NoAutoUpdate', 'AUOptions', 'NoAutoRebootWithLoggedOnUsers', 'AUPowerManagement')
        $script:WUPolicy = @('ExcludeWUDriversInQualityUpdate', 'DeferFeatureUpdates', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdates', 'DeferQualityUpdatesPeriodInDays')
        $script:WUUX     = @('BranchReadinessLevel', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdatesPeriodInDays') + $script:PauseNames
        $script:WUDrv    = @('DontPromptForWindowsUpdate', 'DontSearchWindowsUpdate', 'DriverUpdateWizardWuSearchEnabled')
    }
    $regs = foreach ($path in $names.Keys) { foreach ($n in $names[$path]) { [pscustomobject]@{ Path = $path; Name = $n } } }
    Start-WNChange -Label $Label -Registry @($regs) -Services @('BITS', 'wuauserv', 'UsoSvc')
}

function Show-WNUpdateStatus {
    $rows = @(
        @((T 'upd.rowFeature'), (Get-WNRegistryValue $script:WUPolicy 'DeferFeatureUpdatesPeriodInDays')),
        @((T 'upd.rowQuality'), (Get-WNRegistryValue $script:WUPolicy 'DeferQualityUpdatesPeriodInDays')),
        @((T 'upd.rowDrivers'), (Get-WNRegistryValue $script:WUPolicy 'ExcludeWUDriversInQualityUpdate')),
        @((T 'upd.rowAU'), (Get-WNRegistryValue $script:WUAU 'AUOptions')),
        @((T 'upd.rowPaused'), (Get-WNRegistryValue $script:WUUX 'PauseUpdatesExpiryTime'))
    )
    foreach ($r in $rows) {
        $v = if ($null -eq $r[1] -or "$($r[1])" -eq '') { T 'common.default' } else { $r[1] }
        Write-Host ("   {0,-42} {1}" -f $r[0], $v) -ForegroundColor Gray
    }
}

function Set-WNUpdatesRecommended {
    Set-WNRegistry $script:WUDrv 'DontPromptForWindowsUpdate' 'DWord' '1'
    Set-WNRegistry $script:WUDrv 'DontSearchWindowsUpdate' 'DWord' '1'
    Set-WNRegistry $script:WUDrv 'DriverUpdateWizardWuSearchEnabled' 'DWord' '0'
    Set-WNRegistry $script:WUPolicy 'ExcludeWUDriversInQualityUpdate' 'DWord' '1'
    Set-WNRegistry $script:WUPolicy 'DeferFeatureUpdates' 'DWord' '1'
    Set-WNRegistry $script:WUPolicy 'DeferFeatureUpdatesPeriodInDays' 'DWord' '120'
    Set-WNRegistry $script:WUPolicy 'DeferQualityUpdates' 'DWord' '1'
    Set-WNRegistry $script:WUPolicy 'DeferQualityUpdatesPeriodInDays' 'DWord' '7'
    Set-WNRegistry $script:WUAU 'AUOptions' 'DWord' '3'
    Set-WNRegistry $script:WUAU 'AUPowerManagement' 'DWord' '0'
    Set-WNRegistry $script:WUAU 'NoAutoRebootWithLoggedOnUsers' 'DWord' '<unset>'
    Write-WNStatus (T 'upd.recDone') Ok 'Updates'
}

function Set-WNUpdatesDefault {
    $values = @{
        $script:WUAU     = @('NoAutoUpdate', 'AUOptions', 'NoAutoRebootWithLoggedOnUsers', 'AUPowerManagement')
        $script:WUPolicy = @('ExcludeWUDriversInQualityUpdate', 'DeferFeatureUpdates', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdates', 'DeferQualityUpdatesPeriodInDays')
        $script:WUUX     = @('BranchReadinessLevel', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdatesPeriodInDays')
        $script:WUDrv    = @('DontPromptForWindowsUpdate', 'DontSearchWindowsUpdate', 'DriverUpdateWizardWuSearchEnabled')
    }
    foreach ($path in $values.Keys) { foreach ($n in $values[$path]) { Set-WNRegistry $path $n 'DWord' '<unset>' } }
    foreach ($s in @(@('BITS', 'Manual'), @('wuauserv', 'Manual'), @('UsoSvc', 'Automatic'))) { Set-WNService -Name $s[0] -StartupType $s[1] }
    Write-WNStatus (T 'upd.defaultDone') Ok 'Updates'
}

function Suspend-WNUpdates {
    param([ValidateRange(1, 35)][int]$Days)
    $now = (Get-Date).ToUniversalTime()
    $start = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $end = $now.AddDays($Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    Set-WNRegistry $script:WUUX 'PauseUpdatesStartTime' 'String' $start
    Set-WNRegistry $script:WUUX 'PauseUpdatesExpiryTime' 'String' $end
    Set-WNRegistry $script:WUUX 'PauseFeatureUpdatesStartTime' 'String' $start
    Set-WNRegistry $script:WUUX 'PauseFeatureUpdatesEndTime' 'String' $end
    Set-WNRegistry $script:WUUX 'PauseQualityUpdatesStartTime' 'String' $start
    Set-WNRegistry $script:WUUX 'PauseQualityUpdatesEndTime' 'String' $end
    Write-WNStatus (T 'upd.paused' $now.AddDays($Days).ToLocalTime().ToString('yyyy-MM-dd HH:mm')) Ok 'Updates'
}

function Resume-WNUpdates {
    foreach ($n in $script:PauseNames) { Set-WNRegistry $script:WUUX $n 'String' '<unset>' }
    Write-WNStatus (T 'upd.resumed') Ok 'Updates'
}

function Show-WNUpdatesMenu {
    while ($true) {
        $items = @(
            @{ Label = (T 'upd.status'); Value = 'status'; Hint = (T 'upd.statusHint') }
            @{ Label = (T 'upd.rec'); Value = 'rec'; Hint = (T 'upd.recHint') }
            @{ Label = (T 'upd.default'); Value = 'default'; Hint = (T 'upd.defaultHint') }
            @{ Label = (T 'upd.pause'); Value = 'pause'; Hint = (T 'upd.pauseHint') }
            @{ Label = (T 'upd.resume'); Value = 'resume'; Hint = (T 'upd.resumeHint') }
            @{ Label = (T 'upd.open'); Value = 'open'; Hint = 'ms-settings:windowsupdate' }
        )
        $choice = Show-WNMenu -Title 'Windows Update' -Items $items
        if (-not $choice) { return }
        Write-WNHeader 'Windows Update'
        switch ($choice) {
            'status'  { Show-WNUpdateStatus }
            'rec'     { if ((Test-WNCanChange) -and (Read-WNConfirm (T 'upd.askRec') -DefaultYes) -and (Start-WNUpdateChange 'updates recommended')) { Set-WNUpdatesRecommended; Write-Host ''; Show-WNUpdateStatus } }
            'default' { if ((Test-WNCanChange) -and (Read-WNConfirm (T 'upd.askDefault') -DefaultYes) -and (Start-WNUpdateChange 'updates default')) { Set-WNUpdatesDefault; Write-Host ''; Show-WNUpdateStatus } }
            'pause'   {
                if (Test-WNCanChange) {
                    $d = Read-WNText (T 'upd.askDays') '7'
                    if ($d -match '^\d+$' -and [int]$d -ge 1 -and [int]$d -le 35) { if (Start-WNUpdateChange 'updates pause') { Suspend-WNUpdates -Days ([int]$d) } } else { Write-WNStatus (T 'upd.badDays') Warn }
                }
            }
            'resume'  { if (Start-WNUpdateChange 'updates resume') { Resume-WNUpdates } }
            'open'    { Start-Process 'ms-settings:windowsupdate' }
        }
        Wait-WNKey
    }
}
