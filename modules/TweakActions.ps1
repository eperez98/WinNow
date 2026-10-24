# modules/TweakActions.ps1
# Script parts of tweaks that cannot be expressed as plain registry/service entries.
# Referenced by name from config/tweaks.json (Invoke / Undo / Check).
# Invoke/Undo functions are never called in DryRun (the engine prints them instead);
# Check functions are read-only and run in every mode.

#region Helpers
function Test-WNDenyEveryone {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $everyone = New-Object Security.Principal.SecurityIdentifier('S-1-1-0')
        $rules = (Get-Acl -LiteralPath $Path -ErrorAction Stop).Access | Where-Object { $_.AccessControlType -eq 'Deny' }
        foreach ($r in $rules) {
            try { if ($r.IdentityReference.Translate([Security.Principal.SecurityIdentifier]) -eq $everyone) { return $true } } catch { }
        }
    } catch { }
    return $false
}

#endregion

#region Essential
function Invoke-WNRestorePointAction { [void](New-WNRestorePoint -Force) }

function Set-WNTelemetryExtras {
    try { Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop } catch { Write-WNStatus "Defender sample submission not changed: $($_.Exception.Message)" Warn 'Telemetry' }
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
}

function Undo-WNTelemetryExtras {
    try { Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction Stop } catch { Write-WNStatus "Defender sample submission not changed: $($_.Exception.Message)" Warn 'Telemetry' }
    [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', $null, 'Machine')
}

$script:StoreDb = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db"
function Set-WNStoreSearchBlock {
    if (-not (Test-Path $script:StoreDb)) { Write-WNStatus 'Store search database not found (Store never opened?), skipped' Skip; return }
    icacls $script:StoreDb /deny '*S-1-1-0:F' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "icacls exit code $LASTEXITCODE" }
}
function Undo-WNStoreSearchBlock {
    if (-not (Test-Path $script:StoreDb)) { return }
    icacls $script:StoreDb /remove:d '*S-1-1-0' | Out-Null
}
function Test-WNStoreSearchBlock { Test-WNDenyEveryone $script:StoreDb }

$script:ShellBags = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell'
function Set-WNExplorerAutoDiscovery {
    Remove-Item -Path "$script:ShellBags\Bags" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$script:ShellBags\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
    $all = "$script:ShellBags\Bags\AllFolders\Shell"
    if (-not (Test-Path $all)) { New-Item -Path $all -Force | Out-Null }
    New-ItemProperty -Path $all -Name 'FolderType' -Value 'NotSpecified' -PropertyType String -Force | Out-Null
    Write-WNStatus 'Sign out and back in to finish applying this change.' Info
}
function Undo-WNExplorerAutoDiscovery {
    Remove-Item -Path "$script:ShellBags\Bags" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$script:ShellBags\BagMRU" -Recurse -Force -ErrorAction SilentlyContinue
    Write-WNStatus 'Sign out and back in to finish applying this change.' Info
}
function Test-WNExplorerAutoDiscovery { (Get-WNRegistryValue "$script:ShellBags\Bags\AllFolders\Shell" 'FolderType') -eq 'NotSpecified' }

function Get-WNFolderSize {
    param([string]$Path)
    try { (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } catch { 0 }
}

function Invoke-WNDeleteTempFiles {
    $total = 0
    foreach ($dir in @($env:TEMP, "$env:SystemRoot\Temp") | Select-Object -Unique) {
        if (-not (Test-Path $dir)) { continue }
        $before = Get-WNFolderSize $dir
        # Files in use (including this session's own log helpers) are skipped silently
        Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $WN.DataDir } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $freed = $before - (Get-WNFolderSize $dir)
        $total += [Math]::Max(0, $freed)
        Write-WNStatus ("Cleaned {0} ({1:N1} MB)" -f $dir, ($freed / 1MB)) Ok 'Cleanup'
    }
    Write-WNStatus ("Freed {0:N1} MB in total" -f ($total / 1MB)) Info 'Cleanup'
}

function Invoke-WNDiskCleanup {
    # Pre-select cleanmgr handlers in profile 64 so /sagerun runs without dialogs
    $caches = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    foreach ($h in @('Active Setup Temp Folders', 'Downloaded Program Files', 'Internet Cache Files', 'Memory Dump Files',
                     'Old ChkDsk Files', 'Previous Installations', 'Recycle Bin', 'Setup Log Files',
                     'System error memory dump files', 'System error minidump files', 'Temporary Files',
                     'Temporary Setup Files', 'Thumbnail Cache', 'Update Cleanup', 'Windows Error Reporting Files',
                     'Windows Upgrade Log Files', 'Delivery Optimization Files')) {
        $k = Join-Path $caches $h
        if (Test-Path $k) { Set-ItemProperty -Path $k -Name 'StateFlags0064' -Type DWord -Value 2 -ErrorAction SilentlyContinue }
    }
    Write-WNStatus 'Running Disk Cleanup (cleanmgr /sagerun:64)...' Step 'Cleanup'
    Start-Process cleanmgr.exe -ArgumentList '/sagerun:64' -Wait -WindowStyle Hidden
    Write-WNStatus 'Running DISM component cleanup (this can take a while)...' Step 'Cleanup'
    [void](Invoke-WNNative -FilePath 'dism.exe' -ArgumentList @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase') -Component 'Cleanup')
}
#endregion

#region Privacy / hosts
$script:TelemetryHosts = @(
    'vortex.data.microsoft.com', 'vortex-win.data.microsoft.com', 'settings-win.data.microsoft.com',
    'watson.telemetry.microsoft.com', 'telecommand.telemetry.microsoft.com', 'oca.telemetry.microsoft.com',
    'sqm.telemetry.microsoft.com', 'telemetry.microsoft.com', 'statsfe2.update.microsoft.com.akadns.net'
)
$script:AdobeHosts = @(
    'activate.adobe.com', 'activate-sea.adobe.com', 'activate-sjc0.adobe.com', 'adobe-dns.adobe.com',
    'adobe-dns-2.adobe.com', 'adobe-dns-3.adobe.com', 'adobe-dns-4.adobe.com', 'adobeereg.com', 'ereg.adobe.com',
    'ereg.wip3.adobe.com', '3dns.adobe.com', '3dns-3.adobe.com', '3dns-4.adobe.com', 'cc-api-data.adobe.io',
    'ims-na1.adobelogin.com'
)
function Add-WNHostsTelemetry    { Add-WNHostsBlock -Name 'telemetry' -Domains $script:TelemetryHosts }
function Remove-WNHostsTelemetry { Remove-WNHostsBlock -Name 'telemetry' }
function Test-WNHostsTelemetry   { Test-WNHostsBlock -Name 'telemetry' }
function Add-WNHostsAdobe        { Add-WNHostsBlock -Name 'adobe' -Domains $script:AdobeHosts }
function Remove-WNHostsAdobe     { Remove-WNHostsBlock -Name 'adobe' }
function Test-WNHostsAdobe       { Test-WNHostsBlock -Name 'adobe' }
#endregion

#region Performance
$script:PlanBalanced = '381b4222-f694-41f0-9685-ff5bb260df2e'
$script:PlanHigh     = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:PlanUltimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
# Fixed GUIDs for our own copies so the active plan can be recognised on any language
$script:PlanHighCopy     = '3c3fd9a8-2b0e-4c55-9a15-5d1f1c2d8a01'
$script:PlanUltimateCopy = '3c3fd9a8-2b0e-4c55-9a15-5d1f1c2d8a02'

function Get-WNActivePlan { (powercfg /getactivescheme) -join ' ' }

function Set-WNPlanFromTemplate {
    param([string]$Template, [string]$Copy)
    powercfg /setactive $Template 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    # Template hidden on this system (Modern Standby): duplicate it under our fixed GUID
    if ((powercfg /list) -notmatch $Copy) { powercfg /duplicatescheme $Template $Copy | Out-Null }
    powercfg /setactive $Copy | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "powercfg could not activate plan (exit $LASTEXITCODE)" }
}

function Set-WNPowerPlanHigh     { Set-WNPlanFromTemplate $script:PlanHigh $script:PlanHighCopy }
function Set-WNPowerPlanUltimate { Set-WNPlanFromTemplate $script:PlanUltimate $script:PlanUltimateCopy }
function Set-WNPowerPlanBalanced {
    powercfg /setactive $script:PlanBalanced | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "powercfg could not activate Balanced (exit $LASTEXITCODE)" }
}
function Test-WNPowerPlanHigh     { $a = Get-WNActivePlan; ($a -match $script:PlanHigh) -or ($a -match $script:PlanHighCopy) }
function Test-WNPowerPlanUltimate { $a = Get-WNActivePlan; ($a -match $script:PlanUltimate) -or ($a -match $script:PlanUltimateCopy) }

function Disable-WNHibernation { [void](Invoke-WNNative -FilePath 'powercfg.exe' -ArgumentList @('/hibernate', 'off') -Component 'Power') }
function Enable-WNHibernation  { [void](Invoke-WNNative -FilePath 'powercfg.exe' -ArgumentList @('/hibernate', 'on') -Component 'Power') }

function Set-WNUserPrefMaskPerformance {
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00))
}
function Undo-WNUserPrefMaskPerformance {
    # Windows default mask (animations, shadows, smooth scrolling on)
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x9E, 0x1E, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00))
}
#endregion

#region Interface
$script:ClassicMenuKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
function Set-WNClassicContextMenu {
    New-Item -Path "$script:ClassicMenuKey\InprocServer32" -Force | Out-Null
    Set-ItemProperty -Path "$script:ClassicMenuKey\InprocServer32" -Name '(default)' -Value '' -Force
}
function Undo-WNClassicContextMenu { Remove-Item -Path $script:ClassicMenuKey -Recurse -Force -ErrorAction SilentlyContinue }
function Test-WNClassicContextMenu { Test-Path "$script:ClassicMenuKey\InprocServer32" }

function Stop-WNWidgets {
    Get-Process -Name 'Widgets', 'WidgetService' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
#endregion

#region Bloatware: OneDrive / Edge
function Test-WNOneDriveRemoved {
    $paths = @("$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe", "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe", "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe")
    -not ($paths | Where-Object { $_ -and (Test-Path $_) })
}

$script:OneDriveNavKey = 'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'

function Remove-WNOneDrive {
    if (Test-WNOneDriveRemoved) { Write-WNStatus 'OneDrive is not installed' Skip; return }
    Get-Process -Name 'OneDrive', 'FileCoAuth' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # winget covers per-user and per-machine installs; the setup shipped with Windows is the fallback
    $code = Invoke-WNWinget @('uninstall', '--id', 'Microsoft.OneDrive', '-e', '--silent')
    if ($code -ne 0) {
        $setup = Get-ChildItem -Path "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ErrorAction SilentlyContinue |
                 Select-Object -First 1
        if ($setup) {
            Write-WNStatus 'Running the OneDrive uninstaller shipped with Windows...' Step
            Start-Process -FilePath $setup.FullName -ArgumentList '/uninstall' -Wait
        }
    }

    # Only OneDrive's own app data goes; the synced folder ($env:OneDrive) is never touched
    foreach ($appData in "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:ProgramData\Microsoft OneDrive") {
        if (Test-Path -LiteralPath $appData) { Remove-Item -LiteralPath $appData -Recurse -Force -ErrorAction SilentlyContinue }
    }
    # Hide the leftover OneDrive entry in the Explorer navigation pane
    if (-not (Test-Path $script:OneDriveNavKey)) { New-Item -Path $script:OneDriveNavKey -Force | Out-Null }
    Set-ItemProperty -Path $script:OneDriveNavKey -Name 'System.IsPinnedToNameSpaceTree' -Type DWord -Value 0

    if ($env:OneDrive -and (Test-Path -LiteralPath $env:OneDrive)) { Write-WNStatus "Your files are still in $env:OneDrive" Info }
    if (Test-WNOneDriveRemoved) { Write-WNStatus 'OneDrive removed' Ok } else { Write-WNStatus 'OneDrive.exe is still present after uninstalling' Warn }
}

function Install-WNOneDrive {
    [void](Invoke-WNWinget @('install', '--id', 'Microsoft.OneDrive', '-e', '--source', 'winget', '--accept-package-agreements', '--silent'))
    Remove-ItemProperty -Path $script:OneDriveNavKey -Name 'System.IsPinnedToNameSpaceTree' -ErrorAction SilentlyContinue
}

$script:EdgeDir = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
function Test-WNEdgeRemoved { -not (Test-Path (Join-Path $script:EdgeDir 'msedge.exe')) }

$script:EdgeUpdateDev = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev'

function Remove-WNEdge {
    # Newest version folder holds the installer that matches the running build
    $setup = Get-ChildItem -Path $script:EdgeDir -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -as [version] } | Sort-Object { [version]$_.Name } |
             ForEach-Object { Join-Path $_.FullName 'Installer\setup.exe' } | Where-Object { Test-Path $_ } |
             Select-Object -Last 1
    if (-not $setup) { Write-WNStatus 'Microsoft Edge is not installed' Skip; return }
    # Edge Update reads this value and then allows setup.exe to remove the browser
    if (-not (Test-Path $script:EdgeUpdateDev)) { New-Item -Path $script:EdgeUpdateDev -Force | Out-Null }
    Set-ItemProperty -Path $script:EdgeUpdateDev -Name 'AllowUninstall' -Type DWord -Value 1
    Get-Process -Name 'msedge' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath $setup -ArgumentList '--uninstall', '--system-level', '--force-uninstall' -Wait
    if (Test-WNEdgeRemoved) { Write-WNStatus 'Microsoft Edge removed' Ok }
    else { Write-WNStatus 'Edge is still installed: some Windows builds only allow removing it in the EEA.' Warn }
}

function Install-WNEdge {
    Remove-ItemProperty -Path $script:EdgeUpdateDev -Name 'AllowUninstall' -ErrorAction SilentlyContinue
    [void](Invoke-WNWinget @('install', '--id', 'Microsoft.Edge', '-e', '--source', 'winget', '--accept-package-agreements', '--silent'))
}
#endregion

#region Advanced
function Disable-WNRecallFeature {
    $f = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction SilentlyContinue
    if (-not $f) { Write-WNStatus 'Recall is not available on this PC, policies only' Skip; return }
    if ($f.State -ne 'Disabled') {
        Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -NoRestart -ErrorAction Stop | Out-Null
        Write-WNStatus 'Recall feature disabled (restart to finish)' Ok
    }
}

function Enable-WNRecallFeature {
    if (Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction SilentlyContinue) {
        Enable-WindowsOptionalFeature -Online -FeatureName 'Recall' -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
}

function Disable-WNTeredo { netsh interface teredo set state disabled | Out-Null }
function Enable-WNTeredo  { netsh interface teredo set state default | Out-Null }
function Disable-WNIPv6Binding { Disable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue }
function Enable-WNIPv6Binding  { Enable-NetAdapterBinding -Name '*' -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue }

function Get-WNMemoryKB { [int64]((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB) }
function Set-WNSvcHostSplit {
    # A threshold above installed RAM turns service-host splitting off
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Type DWord -Value (Get-WNMemoryKB) -Force
}
function Undo-WNSvcHostSplit {
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Type DWord -Value 3670016 -Force
}
function Test-WNSvcHostSplit {
    $v = Get-WNRegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB'
    ($null -ne $v) -and ([int64]$v -ge (Get-WNMemoryKB))
}

function Disable-WNReservedStorage { [void](Invoke-WNNative -FilePath 'dism.exe' -ArgumentList @('/Online', '/Set-ReservedStorageState', '/State:Disabled')) }
function Enable-WNReservedStorage  { [void](Invoke-WNNative -FilePath 'dism.exe' -ArgumentList @('/Online', '/Set-ReservedStorageState', '/State:Enabled')) }
#endregion
