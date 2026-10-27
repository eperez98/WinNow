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

.PARAMETER Lang
    Interface language: en or es. Without it the interactive app asks at startup.

.PARAMETER GUI
    Open the graphical interface (preview) instead of the terminal menus.

.PARAMETER NoUpdateCheck
    Do not ask GitHub for a newer release at startup.

.EXAMPLE
    .\Winnow.ps1
    .\Winnow.ps1 -DryRun
    .\Winnow.ps1 -Preset Standard -Yes
    .\Winnow.ps1 -Apply Telemetry,ClassicContextMenu -DryRun
    .\Winnow.ps1 -Status
    .\Winnow.ps1 -Lang es
    .\Winnow.ps1 -GUI
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
    [ValidateSet('en', 'es')][string]$Lang,
    [switch]$GUI,
    [switch]$NoUpdateCheck,
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
    # The GUI does not need its console window in front
    $style = if ($GUI) { 'Minimized' } else { 'Normal' }
    try { Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs -WindowStyle $style -ErrorAction Stop }
    catch { Write-Host '  Elevation was cancelled. Run with -DryRun to explore without admin rights.' -ForegroundColor Red; exit 1 }
    exit 0
}

# ---- Load ------------------------------------------------------------------------------------
foreach ($f in @(Get-ChildItem "$root\core\*.ps1") + @(Get-ChildItem "$root\modules\*.ps1")) { . $f.FullName }
Initialize-WNContext -Root $root -DryRun:$DryRun -Yes:$Yes -NoRestorePoint:$NoRestorePoint
try { Import-WNConfig } catch { Write-Host "  [ERROR] $_" -ForegroundColor Red; exit 1 }
Set-WNLanguage $(if ($Lang) { $Lang } else { 'en' })

# ---- Scripted mode -----------------------------------------------------------------------------
function Resolve-WNTweakKeys {
    param([string[]]$Keys)
    $keys = @($Keys | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $found = @()
    foreach ($k in $keys) {
        $t = Get-WNTweak $k
        if ($t) { $found += $t } else { Write-WNStatus (T 'main.unknownTweak' $k) Error }
    }
    return $found
}

if ($List) {
    Write-Host ''
    $WN.Config.tweaks | Sort-Object Category, Name | Format-Table @{ n = 'Key'; e = { $_.Key } }, Category, Type, Risk, Level, Name -AutoSize | Out-Host
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
            if ($a) { $a } else { Write-WNStatus (T 'main.unknownApp' $id) Error }
        }
        if ($apps) { Install-WNApps -Apps @($apps) }
    }
    exit ([int]($WN.ErrorCount -gt 0))
}

# ---- Graphical interface (preview) -------------------------------------------------------------
if ($GUI) {
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
        # WPF needs a single-threaded apartment; Windows PowerShell 5.1 starts in one
        $a = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GUI', '-NoElevate')
        if ($DryRun) { $a += '-DryRun' }
        if ($Lang) { $a += '-Lang', $Lang }
        Start-Process powershell.exe -ArgumentList $a -WindowStyle Minimized
        exit 0
    }
    if (-not $WN.IsAdmin) { $WN.DryRun = $true }
    $l = if ($Lang) { $Lang } elseif ((Get-WNSettings).Lang -in 'en', 'es') { (Get-WNSettings).Lang } else { 'en' }
    Set-WNLanguage $l
    . "$root\gui\Gui.ps1"
    if (-not $NoUpdateCheck -and (Invoke-WNGuiUpdateCheck)) { Restart-WNApp -Gui; exit 0 }
    # Switching language closes the window and opens it again in the other language
    while ($next = Show-WNGui) { Set-WNLanguage $next; Save-WNSetting 'Lang' $next }
    exit 0
}

# ---- Interactive -------------------------------------------------------------------------------
Initialize-WNConsole
if (-not $WN.IsAdmin -and -not $WN.DryRun) { $WN.DryRun = $true }
if (-not $Lang) {
    $picked = Show-WNLanguagePicker
    if (-not $picked) { Set-WNCursor $true; exit 0 }
    Set-WNLanguage $picked
}
# Every start: newer release on GitHub? (quiet when offline or up to date). First start: offer the shortcut.
if (-not $NoUpdateCheck -and (Invoke-WNUpdateCheck)) { Restart-WNApp; exit 0 }
if (-not (Get-WNSettings).ShortcutAsked) { Show-WNShortcutOffer }

try {
    while ($true) {
        $sim = if ($WN.DryRun) { T 'main.simOn' } else { T 'main.simOff' }
        # Same groups and order as the GUI sidebar; 1-9 for the everyday modules, letters for the rest
        $items = @(
            @{ Separator = $true; Label = (T 'main.secOptimize') }
            @{ Label = (T 'main.tweaks'); Value = 'tweaks'; Hint = (T 'main.tweaksHint' @($WN.Config.tweaks | Where-Object Type -ne 'Toggle').Count) }
            @{ Label = (T 'main.prefs'); Value = 'prefs'; Hint = (T 'main.prefsHint') }
            @{ Label = (T 'main.services'); Value = 'services'; Hint = (T 'main.servicesHint') }
            @{ Label = (T 'main.startup'); Value = 'startup'; Hint = (T 'main.startupHint') }
            @{ Separator = $true; Label = (T 'main.secApps') }
            @{ Label = (T 'main.apps'); Value = 'apps'; Hint = (T 'main.appsHint' @($WN.Config.apps).Count) }
            @{ Label = (T 'main.uninstall'); Value = 'uninstall'; Hint = (T 'main.uninstallHint') }
            @{ Separator = $true; Label = (T 'main.secMaintain') }
            @{ Label = (T 'main.repair'); Value = 'repair'; Hint = (T 'main.repairHint') }
            @{ Label = (T 'main.updates'); Value = 'updates'; Hint = (T 'main.updatesHint') }
            @{ Label = (T 'main.backups'); Value = 'backups'; Hint = (T 'main.backupsHint') }
            @{ Separator = $true; Label = (T 'main.secNetwork') }
            @{ Label = (T 'main.dns'); Value = 'dns'; Hint = (T 'main.dnsHint'); Hotkey = 'd' }
            @{ Label = (T 'main.hosts'); Value = 'hosts'; Hint = (T 'main.hostsHint'); Hotkey = 'h' }
            @{ Separator = $true; Label = (T 'main.secSystem') }
            @{ Label = (T 'main.info'); Value = 'info'; Hint = (T 'main.infoHint'); Hotkey = 'y' }
            @{ Label = (T 'main.logs'); Value = 'logs'; Hint = $WN.LogFile; Hotkey = 'l' }
            @{ Separator = $true; Label = (T 'main.secTool') }
            @{ Label = (T 'main.gui'); Value = 'gui'; Hint = (T 'main.guiHint'); Hotkey = 'g' }
            @{ Label = (T 'main.update'); Value = 'update'; Hint = (T 'main.updateHint'); Hotkey = 'u' }
            @{ Label = (T 'main.shortcut'); Value = 'shortcut'; Hint = (T 'main.shortcutHint'); Hotkey = 'k' }
            @{ Label = (T 'lang.menu'); Value = 'lang'; Hint = (T 'lang.menuHint'); Hotkey = 'i' }
            @{ Label = (T 'main.sim' $sim); Value = 'sim'; Hint = (T 'main.simHint'); Hotkey = 'm' }
        )
        $choice = Show-WNMenu -Title (T 'main.title') -Items $items -BackLabel (T 'menu.exit') -Banner
        if (-not $choice) {
            # Ask before leaving so a stray Esc can never close the app on its own
            if (-not $WN.Interactive) { break }
            Write-Host ''
            if (Read-WNConfirm (T 'main.exitConfirm') -DefaultYes) { break } else { continue }
        }
        try {
        switch ($choice) {
            'tweaks'   { Show-WNTweaksMenu }
            'prefs'    { Show-WNToggles }
            'apps'     { Show-WNAppsMenu }
            'uninstall' { Show-WNUninstallMenu }
            'services' { Show-WNServicesMenu }
            'startup'  { Show-WNStartupMenu }
            'repair'   { Show-WNRepairMenu }
            'updates'  { Show-WNUpdatesMenu }
            'dns'      { Show-WNDnsMenu }
            'hosts'    { Show-WNHostsMenu }
            'backups'  { Show-WNBackupsMenu }
            'gui' {
                $a = @('-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GUI', '-NoElevate', '-Lang', $WN.Lang)
                if ($WN.DryRun) { $a += '-DryRun' }
                Start-Process powershell.exe -ArgumentList $a -WindowStyle Minimized
                Write-WNStatus (T 'main.guiOpened') Ok
            }
            'update'   { if (Invoke-WNUpdateCheck -Manual) { Restart-WNApp; exit 0 } }
            'shortcut' { Write-WNHeader (T 'main.shortcut'); [void](New-WNShortcut); Save-WNSetting 'ShortcutAsked' $true; Wait-WNKey }
            'info'     { Show-WNSystemInfo }
            'logs'     { Show-WNLogsMenu }
            'lang'     { $l = if ($WN.Lang -eq 'es') { 'en' } else { 'es' }; Set-WNLanguage $l; Save-WNSetting 'Lang' $l; Initialize-WNConsole }
            'sim' {
                if ($WN.DryRun -and -not $WN.IsAdmin) {
                    Write-WNHeader (T 'main.simTitle')
                    Write-WNStatus (T 'main.simNeedAdmin') Warn
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
            Write-WNStatus (T 'main.error' $choice $_.Exception.Message) Error
            Write-WNLog "At: $($_.InvocationInfo.PositionMessage)" -Level ERROR
            Wait-WNKey
        }
    }
} finally {
    Set-WNCursor $true
    Write-WNLog '==== exit'
}
Write-Host ''
Write-Host ('  ' + (T 'main.bye' $WN.LogFile)) -ForegroundColor DarkGray
