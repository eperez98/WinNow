# modules/Profiles.ps1
# Profiles: the tweaks applied and the catalog apps installed on this PC, saved as JSON, exported to another
# PC and applied there in one step. Schedules: a Windows scheduled task that runs maintenance (temp cleanup,
# app upgrades) weekly or every four weeks with -Maintain.

$script:WNScheduleName = 'WinNow Maintenance'

function Get-WNProfileDir {
    $d = Join-Path $WN.DataDir 'profiles'
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}

function ConvertTo-WNProfile {
    # Keeps only what WinNow knows: tweak keys from the catalog and apps from the catalog (a profile file can come
    # from another PC, so nothing outside the catalog is ever applied or installed from it)
    param([Parameter(Mandatory)]$Data, [string]$File)
    $tweaks = @(@($Data.Tweaks) | Where-Object { $_ -is [string] -and (Get-WNTweak $_) })
    $apps = @(@($Data.Apps) | Where-Object { $id = $_; $_ -is [string] -and ($WN.Config.apps | Where-Object { $_.Winget -eq $id }) })
    $name = "$($Data.Name)" -replace '[^\w\- .]', ''
    if (-not $name.Trim()) { $name = 'Profile' }
    return [pscustomobject]@{ Name = $name.Trim(); Created = "$($Data.Created)"; Computer = "$($Data.Computer)"; Version = "$($Data.Version)"
                              Tweaks = $tweaks; Apps = $apps; File = $File }
}

function Get-WNProfiles {
    Get-ChildItem -LiteralPath (Get-WNProfileDir) -Filter '*.json' -File -ErrorAction SilentlyContinue |
        Where-Object { Test-WNTrustedOwner $_.FullName } |
        ForEach-Object {
            try { ConvertTo-WNProfile (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json) $_.FullName }
            catch { Write-WNLog "Profile $($_.Name) unreadable: $_" -Level WARN -Component 'Profiles' }
        } | Sort-Object Created -Descending
}

function Save-WNProfileFile {
    param([Parameter(Mandatory)]$Pf)
    $base = $Pf.Name -replace '\s+', '_'
    $file = Join-Path (Get-WNProfileDir) "$base.json"
    $i = 2
    while (Test-Path -LiteralPath $file) { $file = Join-Path (Get-WNProfileDir) "${base}_$i.json"; $i++ }
    [ordered]@{ Name = $Pf.Name; Created = $Pf.Created; Computer = $Pf.Computer; Version = $Pf.Version
                Tweaks = @($Pf.Tweaks); Apps = @($Pf.Apps) } | ConvertTo-Json | Set-Content -LiteralPath $file -Encoding UTF8
    return $file
}

function New-WNProfile {
    # This PC as it is now: every applied tweak and preference, every installed catalog app
    param([string]$Name = "$env:COMPUTERNAME $(Get-Date -Format 'yyyy-MM-dd HHmm')")
    Write-WNStatus (T 'pf.reading') Step 'Profiles'
    $tweaks = @($WN.Config.tweaks | Where-Object { $_.Type -ne 'Action' -and (Get-WNTweakState $_) -eq 'Applied' } | ForEach-Object Key)
    $installed = Get-WNInstalledAppIds
    $apps = @($WN.Config.apps | Where-Object { $_.Winget -and $installed.Contains($_.Winget) } | ForEach-Object Winget)
    $p = ConvertTo-WNProfile ([pscustomobject]@{ Name = $Name; Created = (Get-Date -Format 'yyyy-MM-dd HH:mm'); Computer = $env:COMPUTERNAME
                                                 Version = $WN.Version; Tweaks = $tweaks; Apps = $apps })
    $p.File = Save-WNProfileFile $p
    Write-WNStatus (T 'pf.saved' $p.Name $p.Tweaks.Count $p.Apps.Count) Ok 'Profiles'
    return $p
}

function Import-WNProfile {
    param([Parameter(Mandatory)][string]$Path)
    try { $data = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-WNStatus (T 'pf.badFile' $Path) Error 'Profiles'; return $null }
    $p = ConvertTo-WNProfile $data
    if (-not ($p.Tweaks.Count + $p.Apps.Count)) { Write-WNStatus (T 'pf.badFile' $Path) Error 'Profiles'; return $null }
    $p.File = Save-WNProfileFile $p
    Write-WNStatus (T 'pf.imported' $p.Name $p.Tweaks.Count $p.Apps.Count) Ok 'Profiles'
    return $p
}

function Export-WNProfile {
    param([Parameter(Mandatory)]$Pf, [Parameter(Mandatory)][string]$Path)
    try { Copy-Item -LiteralPath $Pf.File -Destination $Path -Force -ErrorAction Stop; Write-WNStatus (T 'pf.exported' $Path) Ok 'Profiles'; return $true }
    catch { Write-WNStatus (T 'pf.exportFail' $_.Exception.Message) Error 'Profiles'; return $false }
}

function Remove-WNProfile {
    param([Parameter(Mandatory)]$Pf)
    Remove-Item -LiteralPath $Pf.File -Force -ErrorAction SilentlyContinue
    Write-WNStatus (T 'pf.deleted' $Pf.Name) Ok 'Profiles'
}

function Invoke-WNProfile {
    # Applies the profile's tweaks that are not applied yet and installs its apps that are missing.
    # -NoConfirm: the window already asked.
    param([Parameter(Mandatory)]$Pf, [switch]$NoConfirm)
    if (-not (Test-WNCanChange)) { return }
    $tweaks = @($Pf.Tweaks | ForEach-Object { Get-WNTweak $_ } | Where-Object { (Get-WNTweakState $_) -ne 'Applied' })
    $installed = Get-WNInstalledAppIds
    $apps = @($WN.Config.apps | Where-Object { $_.Winget -in $Pf.Apps -and -not $installed.Contains($_.Winget) })
    if (-not ($tweaks.Count + $apps.Count)) { Write-WNStatus (T 'pf.nothing' $Pf.Name) Ok 'Profiles'; return }
    if ($tweaks.Count -and ($NoConfirm -or (Confirm-WNTweakPlan -Tweaks $tweaks))) { Invoke-WNTweakBatch -Tweaks $tweaks }
    if ($apps.Count) { Install-WNApps -Apps $apps }
}

#region Scheduled maintenance
function Get-WNSchedule {
    # $null, or @{ Every = 1 | 4 (weeks); Next; Tasks }
    $t = Get-ScheduledTask -TaskName $script:WNScheduleName -ErrorAction SilentlyContinue
    if (-not $t) { return $null }
    $weeks = [int]($t.Triggers | Select-Object -First 1).WeeksInterval
    $next = try { (Get-ScheduledTaskInfo -TaskName $script:WNScheduleName -ErrorAction Stop).NextRunTime } catch { $null }
    return [pscustomobject]@{ Every = $(if ($weeks -gt 1) { $weeks } else { 1 }); Next = $next; State = "$($t.State)" }
}

function Set-WNSchedule {
    # Every Sunday (or every 4th Sunday) at 10:00, as this user with full rights, while signed in: temp cleanup,
    # then winget upgrade --all. A copy in %TEMP% is replaced on every download, so it cannot be scheduled.
    param([ValidateSet(1, 4)][int]$Weeks = 1)
    if (Test-WNTempCopy) { Write-WNStatus (T 'sch.tempCopy') Error 'Schedule'; return $false }
    if (-not (Test-WNCanChange)) { return $false }
    $script = Join-Path $WN.Root 'Winnow.ps1'
    if ($WN.DryRun) { Write-WNStatus (T 'sch.dry' $Weeks $script) Dry 'Schedule'; return $true }
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -Maintain Temp,Upgrade -Yes -NoUpdateCheck" -WorkingDirectory $WN.Root
        $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval $Weeks -DaysOfWeek Sunday -At '10:00'
        $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
        Register-ScheduledTask -TaskName $script:WNScheduleName -Action $action -Trigger $trigger -Principal $principal -Settings $settings `
            -Description 'WinNow: temp cleanup and app upgrades' -Force -ErrorAction Stop | Out-Null
        Write-WNStatus (T 'sch.set' $Weeks) Ok 'Schedule'
        return $true
    } catch {
        Write-WNStatus (T 'sch.fail' $_.Exception.Message) Error 'Schedule'
        return $false
    }
}

function Remove-WNSchedule {
    if (-not (Get-WNSchedule)) { Write-WNStatus (T 'sch.none') Info 'Schedule'; return }
    if (-not (Test-WNCanChange)) { return }
    if ($WN.DryRun) { Write-WNStatus (T 'sch.dryOff') Dry 'Schedule'; return }
    try { Unregister-ScheduledTask -TaskName $script:WNScheduleName -Confirm:$false -ErrorAction Stop; Write-WNStatus (T 'sch.off') Ok 'Schedule' }
    catch { Write-WNStatus (T 'sch.fail' $_.Exception.Message) Error 'Schedule' }
}

function Get-WNScheduleText {
    $s = Get-WNSchedule
    if (-not $s) { return (T 'sch.statusOff') }
    $when = if ($s.Next) { '{0:yyyy-MM-dd HH:mm}' -f $s.Next } else { '-' }
    return (T 'sch.statusOn' $s.Every $when)
}

function Invoke-WNMaintenance {
    # -Maintain (the scheduled task): no questions, a JSON backup of the app list before upgrades, all in the log
    param([ValidateSet('Temp', 'Upgrade')][string[]]$Tasks)
    Write-WNLog "Scheduled maintenance: $($Tasks -join ', ')" -Component 'Schedule'
    if ('Temp' -in $Tasks) { if ($WN.DryRun) { Write-WNStatus (T 'rep.dryTemp' $env:TEMP "$env:SystemRoot\Temp") Dry } else { Invoke-WNDeleteTempFiles } }
    if ('Upgrade' -in $Tasks -and (Test-WNCanChange) -and (Start-WNChange -Label 'scheduled upgrade' -Apps -SkipRestorePoint)) {
        [void](Invoke-WNWinget @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--silent'))
    }
}
#endregion

function Show-WNProfilesMenu {
    while ($true) {
        $profiles = @(Get-WNProfiles)
        $items = @(
            @{ Separator = $true; Label = (T 'pf.title') }
            @{ Label = (T 'pf.save'); Value = 'save'; Hotkey = 's'; Hint = (T 'pf.saveHint') }
            @{ Label = (T 'pf.apply'); Value = 'apply'; Hotkey = 'a'; Hint = (T 'pf.count' $profiles.Count) }
            @{ Label = (T 'pf.export'); Value = 'export'; Hotkey = 'e'; Hint = (T 'pf.exportHint') }
            @{ Label = (T 'pf.import'); Value = 'import'; Hotkey = 'i'; Hint = (T 'pf.importHint') }
            @{ Label = (T 'pf.delete'); Value = 'delete'; Hotkey = 'd'; Hint = (Get-WNProfileDir) }
            @{ Separator = $true; Label = (T 'sch.title') }
            @{ Label = (T 'sch.weekly'); Value = 'w1'; Hotkey = 'w'; Hint = (T 'sch.tasksHint') }
            @{ Label = (T 'sch.monthly'); Value = 'w4'; Hotkey = 'm'; Hint = (T 'sch.tasksHint') }
            @{ Label = (T 'sch.turnOff'); Value = 'off'; Hotkey = 'o'; Hint = (Get-WNScheduleText) }
        )
        $choice = Show-WNMenu -Title (T 'pf.menuTitle') -Items $items
        if (-not $choice) { return }
        if ($choice -in 'apply', 'export', 'delete') {
            if (-not $profiles.Count) { Write-WNHeader (T 'pf.title'); Write-WNStatus (T 'pf.none') Info 'Profiles'; Wait-WNKey; continue }
            $pick = Show-WNMenu -Title (T "pf.$choice") -Items @($profiles | ForEach-Object {
                @{ Label = $_.Name; Value = $_.File; Hint = (T 'pf.rowHint' $_.Tweaks.Count $_.Apps.Count $_.Computer $_.Created) } })
            if (-not $pick) { continue }
            $p = $profiles | Where-Object File -eq $pick | Select-Object -First 1
        }
        Write-WNHeader (T 'pf.menuTitle')
        switch ($choice) {
            'save'   { $n = Read-WNText (T 'pf.askName') "$env:COMPUTERNAME $(Get-Date -Format 'yyyy-MM-dd')"; [void](New-WNProfile -Name $n) }
            'apply'  { Invoke-WNProfile $p }
            'export' {
                $dest = Read-WNText (T 'pf.askPath') (Join-Path ([Environment]::GetFolderPath('Desktop')) (Split-Path $p.File -Leaf))
                if ($dest) { [void](Export-WNProfile $p $dest) }
            }
            'import' { $src = Read-WNText (T 'pf.askImport'); if ($src) { [void](Import-WNProfile ($src.Trim('"'))) } }
            'delete' { if (Read-WNConfirm (T 'pf.delAsk' $p.Name)) { Remove-WNProfile $p } }
            'w1'     { [void](Set-WNSchedule -Weeks 1) }
            'w4'     { [void](Set-WNSchedule -Weeks 4) }
            'off'    { Remove-WNSchedule }
        }
        Wait-WNKey
    }
}
