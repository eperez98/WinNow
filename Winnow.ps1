<#
.SYNOPSIS
    Winnow - Windows 10/11 optimization, debloat and maintenance toolkit for the terminal.

.DESCRIPTION
    Interactive keyboard-driven menus (arrow keys, Space, Enter) or fully scripted via parameters.
    Declarative tweak engine: every tweak is declared in config/tweaks.json
    with its applied and original values, so it can be detected, applied and undone.

.PARAMETER DryRun
    Simulation mode. Nothing is changed; every registry, service, app and command step is printed.
    Works without administrator rights.

.PARAMETER Preset
    Apply a preset (Minimal, Standard, Heavy) without the menu.

.PARAMETER Apply
    Apply tweaks by key (see -List), e.g. -Apply Telemetry,WPBT

.PARAMETER Undo
    Undo tweaks by key.

.PARAMETER Install
    Install apps by catalog id or winget id, e.g. -Install firefox,7zip

.PARAMETER List
    List tweak keys, presets and exit.

.PARAMETER Status
    Show the detected state of every tweak and exit.

.PARAMETER Yes
    Do not ask for confirmation (for unattended use).

.PARAMETER NoRestorePoint
    Skip the automatic System Restore Point before changes.

.EXAMPLE
    .\Winnow.ps1
    .\Winnow.ps1 -DryRun
    .\Winnow.ps1 -Preset Standard -Yes
    .\Winnow.ps1 -Apply Telemetry,ClassicContextMenu -DryRun
    .\Winnow.ps1 -Status
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('Minimal', 'Standard', 'Heavy')][string]$Preset,
    [string[]]$Apply,
    [string[]]$Undo,
    [string[]]$Install,
    [switch]$List,
    [switch]$Status,
    [switch]$Yes,
    [switch]$NoRestorePoint,
    [switch]$NoElevate
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot

# ---- Elevation: real changes need admin; -DryRun / -List / -Status do not -------------------
$isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun -and -not $List -and -not $Status -and -not $NoElevate) {
    Write-Host '  Requesting administrator rights...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($p in $PSBoundParameters.GetEnumerator()) {
        if ($p.Value -is [switch]) { if ($p.Value) { $argList += "-$($p.Key)" } }
        elseif ($p.Value -is [array]) { $argList += "-$($p.Key)"; $argList += ($p.Value -join ',') }
        else { $argList += "-$($p.Key)"; $argList += "`"$($p.Value)`"" }
    }
    $exe = (Get-Process -Id $PID).Path
    try { Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs -ErrorAction Stop }
    catch { Write-Host '  Elevation was cancelled. Run with -DryRun to explore without admin rights.' -ForegroundColor Red; exit 1 }
    exit 0
}

# ---- Load ------------------------------------------------------------------------------------
foreach ($f in @(Get-ChildItem "$root\core\*.ps1") + @(Get-ChildItem "$root\modules\*.ps1")) { . $f.FullName }
Initialize-WNContext -Root $root -DryRun:$DryRun -Yes:$Yes -NoRestorePoint:$NoRestorePoint
try { Import-WNConfig } catch { Write-Host "  [ERROR] $_" -ForegroundColor Red; exit 1 }

# ---- Scripted mode -----------------------------------------------------------------------------
function Resolve-WNTweakKeys {
    param([string[]]$Keys)
    $keys = @($Keys | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $found = @()
    foreach ($k in $keys) {
        $t = Get-WNTweak $k
        if ($t) { $found += $t } else { Write-WNStatus "Unknown tweak key '$k' (use -List)" Error }
    }
    return $found
}

if ($List) {
    Write-Host ''
    $WN.Config.tweaks | Sort-Object Category, Name | Format-Table @{ n = 'Key'; e = { $_.Key } }, Category, Type, Risk, Name -AutoSize | Out-Host
    Write-Host '  Presets:' -ForegroundColor Cyan
    foreach ($p in $WN.Config.presets.PSObject.Properties) { Write-Host ("   {0,-9} {1}" -f $p.Name, ($p.Value.Tweaks -join ', ')) }
    exit 0
}

if ($Status) {
    Write-Host ''
    $WN.Config.tweaks | ForEach-Object { [pscustomobject]@{ Key = $_.Key; Category = $_.Category; State = (Get-WNTweakState $_); Name = $_.Name } } |
        Sort-Object Category, Key | Format-Table -AutoSize | Out-Host
    exit 0
}

if ($Preset -or $Apply -or $Undo -or $Install) {
    Initialize-WNConsole
    $WN.Interactive = $false
    if ($Preset) { $Apply = @($Apply) + @($WN.Config.presets.$Preset.Tweaks) }
    if ($Apply) {
        $t = @(Resolve-WNTweakKeys $Apply)
        if ($t.Count -and (Confirm-WNTweakPlan -Tweaks $t)) { Invoke-WNTweakBatch -Tweaks $t }
    }
    if ($Undo) {
        $t = @(Resolve-WNTweakKeys $Undo)
        if ($t.Count -and (Confirm-WNTweakPlan -Tweaks $t -Undo)) { Invoke-WNTweakBatch -Tweaks $t -Undo }
    }
    if ($Install) {
        $ids = @($Install | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $apps = foreach ($id in $ids) {
            $a = $WN.Config.apps | Where-Object { $_.Id -eq $id -or $_.Winget -eq $id } | Select-Object -First 1
            if ($a) { $a } else { Write-WNStatus "Unknown app '$id'" Error }
        }
        if ($apps) { Install-WNApps -Apps @($apps) }
    }
    exit ([int]($WN.ErrorCount -gt 0))
}

# ---- Interactive -------------------------------------------------------------------------------
Initialize-WNConsole
if (-not $WN.IsAdmin -and -not $WN.DryRun) { $WN.DryRun = $true }

try {
    while ($true) {
        $sim = if ($WN.DryRun) { 'ON - nothing is changed' } else { 'OFF - changes are real' }
        $items = @(
            @{ Separator = $true; Label = 'Optimize' }
            @{ Label = 'Tweaks'; Value = 'tweaks'; Hint = "$(@($WN.Config.tweaks | Where-Object Type -ne 'Toggle').Count) tweaks by category, presets, undo" }
            @{ Label = 'Preferences (switches)'; Value = 'prefs'; Hint = 'Dark mode, file extensions, taskbar, mouse acceleration... shown as ON/OFF' }
            @{ Label = 'App Manager'; Value = 'apps'; Hint = "$(@($WN.Config.apps).Count) apps via winget - install, uninstall, upgrade all" }
            @{ Label = 'Services'; Value = 'services'; Hint = 'Compare and set startup type of common services' }
            @{ Label = 'Startup Manager'; Value = 'startup'; Hint = 'Enable / disable apps that start with Windows' }
            @{ Separator = $true; Label = 'Maintain' }
            @{ Label = 'Repair & Maintenance'; Value = 'repair'; Hint = 'SFC, DISM, cleanup, network/update/store reset, restore points' }
            @{ Label = 'Windows Update'; Value = 'updates'; Hint = 'Recommended / default policies, pause and resume' }
            @{ Label = 'DNS'; Value = 'dns'; Hint = 'Cloudflare, Google, Quad9, AdGuard... or back to DHCP' }
            @{ Label = 'Hosts file'; Value = 'hosts'; Hint = 'Telemetry / Adobe blocks, view, edit with backup' }
            @{ Label = 'Backups & restore'; Value = 'backups'; Hint = 'Restore points and backups: create, restore, delete'; Hotkey = 'b' }
            @{ Separator = $true; Label = 'Tool' }
            @{ Label = 'System information'; Value = 'info'; Hint = 'Hardware, Windows version, disks'; Hotkey = 'y' }
            @{ Label = 'Logs'; Value = 'logs'; Hint = $WN.LogFile; Hotkey = 'l' }
            @{ Label = "Simulation mode: $sim"; Value = 'sim'; Hint = 'When ON every action is only printed (safe for testing)'; Hotkey = 'm' }
        )
        $choice = Show-WNMenu -Title 'Main menu' -Items $items -BackLabel 'Exit' -Banner
        if (-not $choice) {
            # Ask before leaving so a stray Esc can never close the app on its own
            if (-not $WN.Interactive) { break }
            Write-Host ''
            if (Read-WNConfirm 'Exit Winnow?' -DefaultYes) { break } else { continue }
        }
        try {
        switch ($choice) {
            'tweaks'   { Show-WNTweaksMenu }
            'prefs'    { Show-WNToggles }
            'apps'     { Show-WNAppsMenu }
            'services' { Show-WNServicesMenu }
            'startup'  { Show-WNStartupMenu }
            'repair'   { Show-WNRepairMenu }
            'updates'  { Show-WNUpdatesMenu }
            'dns'      { Show-WNDnsMenu }
            'hosts'    { Show-WNHostsMenu }
            'backups'  { Show-WNBackupsMenu }
            'info'     { Show-WNSystemInfo }
            'logs'     { Show-WNLogsMenu }
            'sim' {
                if ($WN.DryRun -and -not $WN.IsAdmin) {
                    Write-WNHeader 'Simulation mode'
                    Write-WNStatus 'Real changes need administrator rights. Restart Winnow as administrator (Launch.bat).' Warn
                    Wait-WNKey
                } else {
                    $WN.DryRun = -not $WN.DryRun
                    Write-WNLog "Simulation mode set to $($WN.DryRun)"
                    Initialize-WNConsole
                }
            }
        }
        } catch {
            # A failing module must not close the app: show the error and return to the menu
            Set-WNCursor $true
            Write-Host ''
            Write-WNStatus "Unexpected error in '$choice': $($_.Exception.Message)" Error
            Write-WNLog "At: $($_.InvocationInfo.PositionMessage)" -Level ERROR
            Wait-WNKey
        }
    }
} finally {
    Set-WNCursor $true
    Write-WNLog '==== exit'
}
Write-Host ''
Write-Host "  Bye. Log: $($WN.LogFile)" -ForegroundColor DarkGray
