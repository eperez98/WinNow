# core/Engine.ps1
# Declarative tweak engine. Each tweak in config/tweaks.json declares:
#   Registry  -> Value on apply, Original on undo ("<unset>" deletes the value)
#   Services  -> Startup on apply, Original on undo (only if still at Startup)
#   Appx      -> removed on apply, never restored
#   Invoke / Undo / Check -> names of functions in modules/TweakActions.ps1
# Every write goes through this file so DryRun is honoured in one place.

$script:UnsetToken = '<unset>'

#region Registry
function Get-WNRegistryValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        return $item.$Name
    } catch { return $null }
}

function Set-WNRegistry {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [string]$Type = 'DWord',
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    $target = "$Path\$Name"
    if ($Value -eq $script:UnsetToken) {
        if ($null -eq (Get-WNRegistryValue $Path $Name)) {
            Write-WNLog "Already absent: $target" -Component 'Registry'
            return
        }
        if ($WN.DryRun) { Write-WNStatus (T 'reg.dryRemove' $target) Dry 'Registry'; return }
        try {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
            Write-WNLog "Removed $target" -Component 'Registry'
        } catch {
            Write-WNStatus (T 'reg.removeFail' $target $_.Exception.Message) Error 'Registry'
        }
        return
    }

    $current = Get-WNRegistryValue $Path $Name
    if ($null -ne $current -and "$current" -eq $Value) {
        Write-WNLog "Unchanged $target = $Value" -Component 'Registry'
        return
    }
    if ($WN.DryRun) { Write-WNStatus (T 'reg.drySet' $target $Value $Type) Dry 'Registry'; return }
    try {
        # New-Item -Force on an existing key wipes its values, so only create missing keys
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -LiteralPath $Path -Name $Name -Type $Type -Value $Value -Force -ErrorAction Stop
        Write-WNLog "Set $target = $Value ($Type) [was: $current]" -Component 'Registry'
    } catch {
        Write-WNStatus (T 'reg.writeFail' $target $_.Exception.Message) Error 'Registry'
    }
}

function Test-WNRegistryEntry {
    # True when the entry is in its "applied" (Value) state
    param([Parameter(Mandatory)]$Entry)
    $actual = Get-WNRegistryValue $Entry.Path $Entry.Name
    if ($Entry.Value -eq $script:UnsetToken) { return ($null -eq $actual) }
    if ($null -eq $actual) {
        if ($Entry.Original -eq $script:UnsetToken) { return $false }
        if ($null -ne $Entry.IfMissing) { return [bool]$Entry.IfMissing }
        return $false
    }
    return ("$actual" -eq "$($Entry.Value)")
}
#endregion

#region Services
function Get-WNServiceStartup {
    param([Parameter(Mandatory)][string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return $null }
    $type = [string]$svc.StartType
    if ($type -eq 'Automatic') {
        $delayed = Get-WNRegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" 'DelayedAutostart'
        if ($delayed -eq 1) { $type = 'AutomaticDelayedStart' }
    }
    return $type
}

function Set-WNService {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic', 'AutomaticDelayedStart', 'Manual', 'Disabled')][string]$StartupType
    )
    $current = Get-WNServiceStartup $Name
    if ($null -eq $current) { Write-WNStatus (T 'svc.notFound' $Name) Skip 'Service'; return }
    if ($current -eq $StartupType) { Write-WNLog "Service $Name already $StartupType" -Component 'Service'; return }
    if ($WN.DryRun) { Write-WNStatus (T 'svc.dry' $Name $current $StartupType) Dry 'Service'; return }
    try {
        switch ($StartupType) {
            'AutomaticDelayedStart' {
                # Set-Service only knows AutomaticDelayedStart on PowerShell 7, sc.exe works everywhere
                sc.exe config $Name start= delayed-auto | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "sc.exe exit code $LASTEXITCODE" }
            }
            'Disabled' {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
            }
            default {
                if ($current -eq 'AutomaticDelayedStart') {
                    # Clear the delayed flag, Set-Service does not on Windows PowerShell
                    sc.exe config $Name start= $(if ($StartupType -eq 'Automatic') { 'auto' } else { 'demand' }) | Out-Null
                } else {
                    Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
                }
            }
        }
        Write-WNLog "Service $Name : $current -> $StartupType" -Component 'Service'
    } catch {
        Write-WNStatus (T 'svc.fail' $Name $StartupType $_.Exception.Message) Error 'Service'
    }
}
#endregion

#region Appx
function Initialize-WNAppx {
    if ($WN.Cache.AppxReady) { return }
    if ($PSVersionTable.PSEdition -eq 'Core') {
        # Appx cmdlets are not native in PowerShell 7
        Import-Module Appx -UseWindowsPowerShell -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    }
    $WN.Cache.AppxReady = $true
}

function Get-WNAppxMatch {
    param([Parameter(Mandatory)][string]$Pattern)
    Initialize-WNAppx
    if ($WN.IsAdmin) {
        @(Get-AppxPackage -AllUsers -Name $Pattern -ErrorAction SilentlyContinue | Sort-Object PackageFullName -Unique)
    } else {
        @(Get-AppxPackage -Name $Pattern -ErrorAction SilentlyContinue)
    }
}

function Remove-WNAppx {
    param([Parameter(Mandatory)][string[]]$Patterns)
    Initialize-WNAppx
    if (-not $WN.DryRun -and -not $WN.Cache.ContainsKey('Provisioned')) {
        Write-WNStatus (T 'appx.reading') Info 'Appx'
        $WN.Cache.Provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
    }
    foreach ($p in $Patterns) {
        $pkgs = Get-WNAppxMatch $p
        $prov = @($WN.Cache.Provisioned | Where-Object { $_.DisplayName -like $p })
        if ($pkgs.Count -eq 0 -and $prov.Count -eq 0) { Write-WNLog "Appx not present: $p" -Component 'Appx'; continue }
        foreach ($pkg in $pkgs) {
            if ($WN.DryRun) { Write-WNStatus (T 'appx.dry' $pkg.Name $pkg.Version) Dry 'Appx'; continue }
            try {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                Write-WNStatus (T 'appx.removed' $pkg.Name) Ok 'Appx'
            } catch {
                Write-WNStatus (T 'appx.fail' $pkg.Name $_.Exception.Message) Warn 'Appx'
            }
        }
        foreach ($pp in $prov) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                Write-WNLog "Deprovisioned $($pp.DisplayName)" -Component 'Appx'
            } catch {
                Write-WNLog "Deprovision failed $($pp.DisplayName): $($_.Exception.Message)" -Level WARN -Component 'Appx'
            }
        }
    }
}
#endregion

#region Restore point
function New-WNRestorePoint {
    param([string]$Description = "Winnow $(Get-Date -Format 'yyyy-MM-dd HH:mm')", [switch]$Force)
    if ($WN.DryRun) { Write-WNStatus (T 'rp.dry' $Description) Dry 'Restore'; return $true }
    if ($WN.RestorePointDone -and -not $Force) { return $true }

    Write-WNStatus (T 'rp.creating') Step 'Restore'
    $freqPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $prevFreq = Get-WNRegistryValue $freqPath 'SystemRestorePointCreationFrequency'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Windows silently skips restore points made less than 24h apart; lift that for this call only
        Set-ItemProperty -Path $freqPath -Name 'SystemRestorePointCreationFrequency' -Type DWord -Value 0 -Force
        if ($PSVersionTable.PSEdition -eq 'Core') {
            # Checkpoint-Computer only exists in Windows PowerShell
            powershell.exe -NoProfile -Command "Checkpoint-Computer -Description '$Description' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop"
            if ($LASTEXITCODE -ne 0) { throw "Checkpoint-Computer exit code $LASTEXITCODE" }
        } else {
            Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        }
        $WN.RestorePointDone = $true
        Write-WNStatus (T 'rp.created' $Description) Ok 'Restore'
        return $true
    } catch {
        Write-WNStatus (T 'rp.failed' $_.Exception.Message) Warn 'Restore'
        return $false
    } finally {
        if ($null -ne $prevFreq) { Set-ItemProperty -Path $freqPath -Name 'SystemRestorePointCreationFrequency' -Type DWord -Value $prevFreq -Force -ErrorAction SilentlyContinue }
        else { Remove-ItemProperty -Path $freqPath -Name 'SystemRestorePointCreationFrequency' -ErrorAction SilentlyContinue }
    }
}

function Confirm-WNRestorePoint {
    # Asks to continue if the restore point fails.
    if ($WN.NoRestorePoint -or $WN.RestorePointDone) { return $true }
    if (New-WNRestorePoint) { return $true }
    if ($WN.Yes) { return $true }
    return (Read-WNConfirm (T 'rp.continueWithout'))
}
#endregion

#region Backups
# Before every change Winnow saves a JSON snapshot with the exact current values of everything
# it is about to touch (registry values, service startup types, DNS servers, installed apps).
# Unlike the catalog's "Original" values, restoring a snapshot puts back what *this* PC had.

function Get-WNBackupDir { Join-Path $WN.DataDir 'backup' }

function Get-WNRegistrySnapshot {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    $entry = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Kind = $null; Data = $null }
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($key.GetValueNames() -contains $Name) {
            $kind = $key.GetValueKind($Name)
            $raw = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            $entry.Exists = $true
            $entry.Kind = [string]$kind
            $entry.Data = switch ($kind) {
                'Binary'      { [Convert]::ToBase64String([byte[]]$raw) }
                'MultiString' { @($raw) }
                default       { [string]$raw }
            }
        }
    } catch { }
    return [pscustomobject]$entry
}

function Get-WNDnsSnapshot {
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
        # NameServer is empty when the adapter takes DNS from DHCP
        $v4 = Get-WNRegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($a.InterfaceGuid)" 'NameServer'
        $v6 = Get-WNRegistryValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$($a.InterfaceGuid)" 'NameServer'
        [pscustomobject]@{ Name = $a.Name; Guid = [string]$a.InterfaceGuid; IPv4 = [string]$v4; IPv6 = [string]$v6 }
    }
}

function New-WNBackup {
    # Registry: objects with Path + Name. Services: service names.
    param(
        [Parameter(Mandatory)][string]$Label,
        [object[]]$Registry = @(),
        [string[]]$Services = @(),
        [switch]$Dns,
        [switch]$Apps,
        [string[]]$Items = @()
    )
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safe = ($Label -replace '[^A-Za-z0-9]+', '-').Trim('-')
    $file = Join-Path (Get-WNBackupDir) "backup_${stamp}_$safe.json"
    if ($WN.DryRun) { Write-WNStatus (T 'bk.dry' (Split-Path $file -Leaf)) Dry 'Backup'; return $file }

    $seen = @{}
    $reg = foreach ($r in $Registry) {
        if (-not $r -or -not $r.Path) { continue }
        $id = "$($r.Path)|$($r.Name)"
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        Get-WNRegistrySnapshot -Path $r.Path -Name $r.Name
    }
    $svc = foreach ($s in ($Services | Select-Object -Unique)) {
        $st = Get-WNServiceStartup $s
        if ($st) { [pscustomobject]@{ Name = $s; Startup = $st } }
    }
    $backup = [ordered]@{
        Version  = 1
        Created  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Label    = $Label
        Computer = $env:COMPUTERNAME
        Items    = @($Items)
        Registry = @($reg)
        Services = @($svc)
        Dns      = @(if ($Dns) { Get-WNDnsSnapshot })
        Apps     = @()
    }
    if ($Apps) { $backup.Apps = @(Get-WNInstalledAppIds -Refresh | Sort-Object) }
    try {
        $backup | ConvertTo-Json -Depth 6 | Set-Content -Path $file -Encoding UTF8 -ErrorAction Stop
        $what = @()
        if ($backup.Registry.Count) { $what += T 'bk.regValues' $backup.Registry.Count }
        if ($backup.Services.Count) { $what += T 'bk.services' $backup.Services.Count }
        if ($backup.Dns.Count) { $what += T 'bk.dns' $backup.Dns.Count }
        if ($backup.Apps.Count) { $what += T 'bk.apps' $backup.Apps.Count }
        $detail = if ($what) { $what -join ', ' } else { T 'bk.logOnly' }
        Write-WNStatus (T 'bk.saved' $detail $file) Ok 'Backup'
        return $file
    } catch {
        Write-WNStatus (T 'bk.failed' $_.Exception.Message) Error 'Backup'
        return $null
    }
}

function Start-WNChange {
    # Single entry point before ANY change: restore point (once per session) + JSON backup.
    # Returns $false if the user cancels.
    param(
        [Parameter(Mandatory)][string]$Label,
        [object[]]$Registry = @(),
        [string[]]$Services = @(),
        [switch]$Dns,
        [switch]$Apps,
        [string[]]$Items = @()
    )
    if (-not (Test-WNCanChange)) { return $false }
    if (-not (Confirm-WNRestorePoint)) { return $false }
    $file = New-WNBackup -Label $Label -Registry $Registry -Services $Services -Dns:$Dns -Apps:$Apps -Items $Items
    if (-not $file -and -not $WN.Yes) { return (Read-WNConfirm (T 'bk.continueWithout')) }
    return $true
}

function Get-WNBackups {
    Get-ChildItem -Path (Get-WNBackupDir) -Filter 'backup_*.json' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            try { $d = Get-Content $_.FullName -Raw | ConvertFrom-Json } catch { return }
            $d | Add-Member -NotePropertyName File -NotePropertyValue $_.FullName -PassThru
        }
}

function Restore-WNBackup {
    param([Parameter(Mandatory)]$Backup)
    if (-not (Test-WNCanChange)) { return }
    # Back up the current state of the same items first, so a restore can itself be undone
    [void](New-WNBackup -Label "before-restore $($Backup.Label)" -Registry @($Backup.Registry) -Services @($Backup.Services | ForEach-Object Name) -Dns:([bool]@($Backup.Dns).Count))

    foreach ($r in @($Backup.Registry)) {
        if (-not $r) { continue }
        $target = "$($r.Path)\$($r.Name)"
        if (-not $r.Exists) { Set-WNRegistry -Path $r.Path -Name $r.Name -Value $script:UnsetToken; continue }
        if ($WN.DryRun) { Write-WNStatus (T 'bk.dryRestore' $target $r.Data $r.Kind) Dry 'Backup'; continue }
        try {
            if (-not (Test-Path -LiteralPath $r.Path)) { New-Item -Path $r.Path -Force | Out-Null }
            $value = switch ($r.Kind) {
                'Binary'      { [Convert]::FromBase64String($r.Data) }
                'MultiString' { [string[]]@($r.Data) }
                'DWord'       { [int]$r.Data }
                'QWord'       { [int64]$r.Data }
                default       { [string]$r.Data }
            }
            New-ItemProperty -LiteralPath $r.Path -Name $r.Name -PropertyType $r.Kind -Value $value -Force -ErrorAction Stop | Out-Null
            Write-WNLog "Restored $target" -Component 'Backup'
        } catch {
            Write-WNStatus (T 'bk.restoreFail' $target $_.Exception.Message) Error 'Backup'
        }
    }
    foreach ($s in @($Backup.Services)) { if ($s) { Set-WNService -Name $s.Name -StartupType $s.Startup } }
    foreach ($d in @($Backup.Dns)) {
        if (-not $d) { continue }
        $a = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { [string]$_.InterfaceGuid -eq $d.Guid }
        if (-not $a) { Write-WNStatus (T 'bk.adapterMissing' $d.Name) Skip 'Backup'; continue }
        $servers = @(($d.IPv4 -split '[,\s]+') + ($d.IPv6 -split '[,\s]+') | Where-Object { $_ })
        if ($WN.DryRun) { Write-WNStatus (T 'bk.dryDns' $d.Name $(if ($servers) { $servers -join ', ' } else { 'DHCP' })) Dry 'Backup'; continue }
        if ($servers.Count) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $servers -ErrorAction SilentlyContinue }
        else { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue }
    }
    if (@($Backup.Apps).Count) {
        Write-WNStatus (T 'bk.appsNote' @($Backup.Apps).Count) Info 'Backup'
    }
    Write-WNStatus (T 'bk.restored' $Backup.Label $Backup.Created $(if ($WN.DryRun) { T 'bk.simSuffix' } else { '' })) Ok 'Backup'
}
#endregion

#region Tweaks
function Get-WNTweakState {
    # Returns Applied | NotApplied | Partial | Unknown | Action
    param([Parameter(Mandatory)]$Tweak)
    if ($Tweak.Type -eq 'Action') { return 'Action' }
    $results = New-Object System.Collections.Generic.List[bool]

    if ($Tweak.Check) {
        try { $results.Add([bool](& $Tweak.Check)) } catch { Write-WNLog "Check $($Tweak.Check) failed: $_" -Level WARN -Component 'Tweaks' }
    }
    foreach ($r in @($Tweak.Registry)) {
        if ($r) { $results.Add((Test-WNRegistryEntry $r)) }
    }
    foreach ($s in @($Tweak.Services)) {
        if (-not $s) { continue }
        $cur = Get-WNServiceStartup $s.Name
        if ($null -ne $cur) { $results.Add($cur -eq $s.Startup) }
    }

    if ($results.Count -eq 0) { return 'Unknown' }
    $on = @($results | Where-Object { $_ }).Count
    if ($on -eq $results.Count) { return 'Applied' }
    if ($on -eq 0) { return 'NotApplied' }
    return 'Partial'
}

function Invoke-WNScriptAction {
    param([Parameter(Mandatory)][string]$Function, [Parameter(Mandatory)][string]$TweakName)
    if (-not (Get-Command $Function -ErrorAction SilentlyContinue)) {
        Write-WNStatus (T 'tw.scriptMissing' $Function $TweakName) Error 'Script'
        return
    }
    if ($WN.DryRun) { Write-WNStatus (T 'tw.dryScript' $Function) Dry 'Script'; return }
    try {
        Write-WNLog "Run script $Function for $TweakName" -Component 'Script'
        & $Function
    } catch {
        Write-WNStatus (T 'tw.scriptFail' $Function $_.Exception.Message) Error 'Script'
    }
}

function Invoke-WNTweak {
    param([Parameter(Mandatory)]$Tweak, [switch]$Undo)

    foreach ($s in @($Tweak.Services)) {
        if (-not $s) { continue }
        if ($Undo) {
            # Only restore services that are still where this tweak put them
            if ((Get-WNServiceStartup $s.Name) -eq $s.Startup) { Set-WNService -Name $s.Name -StartupType $s.Original }
        } else {
            Set-WNService -Name $s.Name -StartupType $s.Startup
        }
    }
    foreach ($r in @($Tweak.Registry)) {
        if (-not $r) { continue }
        $v = if ($Undo) { $r.Original } else { $r.Value }
        Set-WNRegistry -Path $r.Path -Name $r.Name -Type $r.Type -Value $v
    }
    $script = if ($Undo) { $Tweak.Undo } else { $Tweak.Invoke }
    if ($script) { Invoke-WNScriptAction -Function $script -TweakName $Tweak.Name }
    if (-not $Undo -and $Tweak.Appx) { Remove-WNAppx -Patterns @($Tweak.Appx) }
}

function Invoke-WNTweakBatch {
    param([Parameter(Mandatory)][object[]]$Tweaks, [switch]$Undo)

    if (-not (Test-WNCanChange)) { return }
    $verb = if ($Undo) { T 'verb.undo' } else { T 'verb.apply' }
    $list = @($Tweaks)

    if ($Undo) {
        $skipped = @($list | Where-Object { $_.Type -eq 'Action' -or (-not $_.Registry -and -not $_.Services -and -not $_.Undo) })
        foreach ($t in $skipped) { Write-WNStatus (T 'tw.oneShot' $t.Name) Skip 'Tweaks' }
        $list = @($list | Where-Object { $skipped -notcontains $_ })
        # Undoing a tweak that is not applied would write its "original" values over whatever is
        # there now (and for grouped tweaks, over a sibling's setting), so leave those alone
        $notApplied = @($list | Where-Object { (Get-WNTweakState $_) -eq 'NotApplied' })
        foreach ($t in $notApplied) { Write-WNStatus (T 'tw.notApplied' $t.Name) Skip 'Tweaks' }
        $list = @($list | Where-Object { $notApplied -notcontains $_ })
    } else {
        # Tweaks in the same Group write the same setting: keep only the last one selected
        $grouped = $list | Where-Object { $_.Group } | Group-Object Group | Where-Object { $_.Count -gt 1 }
        foreach ($g in $grouped) {
            $keep = $g.Group[-1]
            foreach ($drop in ($g.Group | Where-Object { $_ -ne $keep })) {
                Write-WNStatus (T 'tw.conflict' $drop.Name $keep.Name $g.Name) Warn 'Tweaks'
                $list = @($list | Where-Object { $_ -ne $drop })
            }
        }
    }
    if ($list.Count -eq 0) { Write-WNStatus (T 'tw.nothing') Info; return }

    $regs = @($list | ForEach-Object { $_.Registry } | Where-Object { $_ })
    $svcs = @($list | ForEach-Object { $_.Services } | Where-Object { $_ } | ForEach-Object Name)
    if (-not (Start-WNChange -Label $(if ($Undo) { 'undo tweaks' } else { 'apply tweaks' }) -Registry $regs -Services $svcs -Items @($list.Key))) { Write-WNStatus (T 'common.cancelled') Warn; return }

    Write-Host ''
    Write-WNStatus (T 'tw.batchStart' $verb $list.Count $(if ($WN.DryRun) { T 'title.sim' } else { '' })) Step 'Tweaks'
    $results = @()
    $i = 0
    foreach ($t in $list) {
        $i++
        Write-Host ''
        Write-Host ("  [{0}/{1}] {2}" -f $i, $list.Count, $t.Name) -ForegroundColor White
        $before = $WN.ErrorCount
        try {
            Invoke-WNTweak -Tweak $t -Undo:$Undo
        } catch {
            Write-WNStatus (T 'tw.unexpected' $_.Exception.Message) Error 'Tweaks'
        }
        $ok = ($WN.ErrorCount -eq $before)
        $results += [pscustomobject]@{ Name = $t.Name; Ok = $ok }
        if ($ok) { Write-WNStatus (T 'tw.done' $verb $t.Name) Ok 'Tweaks' } else { Write-WNStatus (T 'tw.doneErrors' $verb $t.Name) Warn 'Tweaks' }
    }

    $restart = @($list | ForEach-Object { $_.Restart } | Where-Object { $_ } | Select-Object -Unique)
    if ($restart -contains 'Explorer') { Restart-WNExplorer }

    $okCount = @($results | Where-Object Ok).Count
    Write-Host ''
    Write-Host ('  ' + ('-' * 56)) -ForegroundColor DarkGray
    $color = if ($okCount -eq $results.Count) { 'Green' } else { 'Yellow' }
    Write-Host ('  ' + (T 'tw.summary' $verb $okCount $results.Count)) -ForegroundColor $color
    foreach ($r in ($results | Where-Object { -not $_.Ok })) { Write-Host "    - $($r.Name) $(T 'tw.seeLog')" -ForegroundColor Yellow }
    if ($restart -contains 'Reboot') { Write-Host ('  ' + (T 'tw.reboot')) -ForegroundColor Yellow }
    Write-Host ('  ' + (T 'common.log' $WN.LogFile)) -ForegroundColor DarkGray
    Write-WNLog "$verb batch complete: $okCount/$($results.Count) ok" -Component 'Tweaks'
}
#endregion
