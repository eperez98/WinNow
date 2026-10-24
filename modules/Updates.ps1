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
        @('Feature update deferral (days)', (Get-WNRegistryValue $script:WUPolicy 'DeferFeatureUpdatesPeriodInDays')),
        @('Quality update deferral (days)', (Get-WNRegistryValue $script:WUPolicy 'DeferQualityUpdatesPeriodInDays')),
        @('Drivers excluded from updates',  (Get-WNRegistryValue $script:WUPolicy 'ExcludeWUDriversInQualityUpdate')),
        @('Automatic Updates option',       (Get-WNRegistryValue $script:WUAU 'AUOptions')),
        @('Paused until',                   (Get-WNRegistryValue $script:WUUX 'PauseUpdatesExpiryTime'))
    )
    foreach ($r in $rows) {
        $v = if ($null -eq $r[1] -or "$($r[1])" -eq '') { 'default' } else { $r[1] }
        Write-Host ("   {0,-34} {1}" -f $r[0], $v) -ForegroundColor Gray
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
    Write-WNStatus 'Feature updates deferred 120 days, security updates 7 days, drivers excluded, download-and-notify.' Ok 'Updates'
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
    Write-WNStatus 'Windows Update policies reset to Windows defaults.' Ok 'Updates'
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
    Write-WNStatus "Updates paused until $($now.AddDays($Days).ToLocalTime().ToString('yyyy-MM-dd HH:mm'))" Ok 'Updates'
}

function Resume-WNUpdates {
    foreach ($n in $script:PauseNames) { Set-WNRegistry $script:WUUX $n 'String' '<unset>' }
    Write-WNStatus 'Updates resumed.' Ok 'Updates'
}

function Show-WNUpdatesMenu {
    while ($true) {
        $items = @(
            @{ Label = 'Status'; Value = 'status'; Hint = 'Current Windows Update policy values' }
            @{ Label = 'Recommended settings'; Value = 'rec'; Hint = 'Defer feature updates 120 days, security 7 days, no driver updates, notify before install' }
            @{ Label = 'Windows default settings'; Value = 'default'; Hint = 'Removes the Windows Update policies Winnow can set' }
            @{ Label = 'Pause updates...'; Value = 'pause'; Hint = 'Pause for 1-35 days (same as the Settings app)' }
            @{ Label = 'Resume updates'; Value = 'resume'; Hint = 'Clears the pause' }
            @{ Label = 'Open Windows Update settings'; Value = 'open'; Hint = 'ms-settings:windowsupdate' }
        )
        $choice = Show-WNMenu -Title 'Windows Update' -Items $items
        if (-not $choice) { return }
        Write-WNHeader 'Windows Update'
        switch ($choice) {
            'status'  { Show-WNUpdateStatus }
            'rec'     { if ((Test-WNCanChange) -and (Read-WNConfirm 'Apply recommended update settings?' -DefaultYes) -and (Start-WNUpdateChange 'updates recommended')) { Set-WNUpdatesRecommended; Write-Host ''; Show-WNUpdateStatus } }
            'default' { if ((Test-WNCanChange) -and (Read-WNConfirm 'Reset update policies to default?' -DefaultYes) -and (Start-WNUpdateChange 'updates default')) { Set-WNUpdatesDefault; Write-Host ''; Show-WNUpdateStatus } }
            'pause'   {
                if (Test-WNCanChange) {
                    $d = Read-WNText 'Days to pause (1-35)' '7'
                    if ($d -match '^\d+$' -and [int]$d -ge 1 -and [int]$d -le 35) { if (Start-WNUpdateChange 'updates pause') { Suspend-WNUpdates -Days ([int]$d) } } else { Write-WNStatus 'Enter a number between 1 and 35.' Warn }
                }
            }
            'resume'  { if (Start-WNUpdateChange 'updates resume') { Resume-WNUpdates } }
            'open'    { Start-Process 'ms-settings:windowsupdate' }
        }
        Wait-WNKey
    }
}
