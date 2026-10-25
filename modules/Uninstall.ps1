# modules/Uninstall.ps1
# Uninstall any installed program (not only catalog apps): desktop programs from the same
# registry keys Settings > Apps reads, plus Microsoft Store apps.

$script:UninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Get-WNInstalledPrograms {
    param([switch]$Refresh)
    if (-not $Refresh -and $WN.Cache.ContainsKey('Programs')) { return $WN.Cache.Programs }
    $seen = @{}
    $list = foreach ($e in Get-ItemProperty -Path $script:UninstallRoots -ErrorAction SilentlyContinue) {
        # Hidden components, updates and entries without an uninstaller are not shown in Settings either
        if (-not $e.DisplayName -or $e.SystemComponent -eq 1 -or $e.ParentKeyName) { continue }
        if ($e.ReleaseType -in 'Update', 'Hotfix', 'Security Update') { continue }
        if (-not $e.UninstallString -and -not $e.QuietUninstallString) { continue }
        $id = "$($e.DisplayName)|$($e.DisplayVersion)"
        if ($seen.ContainsKey($id)) { continue }
        $seen[$id] = $true
        $msi = if ($e.WindowsInstaller -eq 1 -and $e.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') { $e.PSChildName } else { $null }
        [pscustomobject]@{
            Name      = [string]$e.DisplayName
            Version   = [string]$e.DisplayVersion
            Publisher = [string]$e.Publisher
            SizeMB    = if ($e.EstimatedSize) { [Math]::Round($e.EstimatedSize / 1024) } else { $null }
            MsiCode   = $msi
            Quiet     = [string]$e.QuietUninstallString
            Command   = [string]$e.UninstallString
            Silent    = [bool]($msi -or $e.QuietUninstallString)
        }
    }
    $WN.Cache.Programs = @($list | Sort-Object Name)
    return $WN.Cache.Programs
}

function Get-WNStoreApps {
    param([switch]$Refresh)
    if (-not $Refresh -and $WN.Cache.ContainsKey('StoreApps')) { return $WN.Cache.StoreApps }
    Initialize-WNAppx
    # Only apps installed from the Store; frameworks and system apps are left out
    $WN.Cache.StoreApps = @(Get-AppxPackage -ErrorAction SilentlyContinue |
        Where-Object { -not $_.IsFramework -and -not $_.NonRemovable -and "$($_.SignatureKind)" -eq 'Store' } |
        Sort-Object Name)
    return $WN.Cache.StoreApps
}

function Invoke-WNProgramUninstall {
    # Returns the exit code of the uninstaller
    param([Parameter(Mandatory)]$Program)
    if ($Program.MsiCode) {
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/x', $Program.MsiCode, '/qn', '/norestart' -Wait -PassThru
        return $p.ExitCode
    }
    $cmd = if ($Program.Quiet) { $Program.Quiet } else { $Program.Command }
    # cmd /s /c runs the stored command line exactly as Windows does, whatever its quoting
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/s /c `"$cmd`"" -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

function Uninstall-WNPrograms {
    param([Parameter(Mandatory)][object[]]$Programs)
    if (-not (Start-WNChange -Label 'uninstall programs' -Apps -Items @($Programs | ForEach-Object Name))) { return }
    $ok = 0
    foreach ($pr in $Programs) {
        Write-Host ''
        if ($WN.DryRun) {
            $how = if ($pr.MsiCode) { "msiexec /x $($pr.MsiCode) /qn" } elseif ($pr.Quiet) { $pr.Quiet } else { $pr.Command }
            Write-WNStatus (T 'un.dry' $pr.Name $how) Dry 'Uninstall'
            $ok++
            continue
        }
        Write-WNStatus (T 'un.running' $pr.Name) Step 'Uninstall'
        try {
            $code = Invoke-WNProgramUninstall $pr
            Write-WNLog "Uninstall $($pr.Name) exit $code" -Component 'Uninstall'
            switch ($code) {
                { $_ -in 0 }          { Write-WNStatus (T 'un.done' $pr.Name) Ok 'Uninstall'; $ok++ }
                { $_ -in 3010, 1641 } { Write-WNStatus (T 'un.reboot' $pr.Name) Ok 'Uninstall'; $ok++ }
                1605                  { Write-WNStatus (T 'un.notFound' $pr.Name) Skip 'Uninstall'; $ok++ }
                default               { Write-WNStatus (T 'un.fail' $pr.Name $code) Warn 'Uninstall' }
            }
        } catch {
            Write-WNStatus (T 'un.fail' $pr.Name $_.Exception.Message) Error 'Uninstall'
        }
    }
    Write-Host ''
    Write-Host ('  ' + (T 'un.summary' $ok $Programs.Count)) -ForegroundColor Cyan
    $WN.Cache.Remove('Programs')
    $WN.Cache.Remove('InstalledApps')
}

function Uninstall-WNStoreApps {
    param([Parameter(Mandatory)][object[]]$Packages)
    if (-not (Start-WNChange -Label 'uninstall store apps' -Apps -Items @($Packages | ForEach-Object Name))) { return }
    $ok = 0
    foreach ($p in $Packages) {
        if ($WN.DryRun) { Write-WNStatus (T 'appx.dry' $p.Name $p.Version) Dry 'Uninstall'; $ok++; continue }
        try {
            Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
            Write-WNStatus (T 'un.storeDone' $p.Name) Ok 'Uninstall'
            $ok++
        } catch {
            Write-WNStatus (T 'un.storeFail' $p.Name $_.Exception.Message) Error 'Uninstall'
        }
    }
    Write-Host ''
    Write-Host ('  ' + (T 'un.summary' $ok $Packages.Count)) -ForegroundColor Cyan
    $WN.Cache.Remove('StoreApps')
}

function Show-WNDesktopPrograms {
    while ($true) {
        $items = foreach ($p in (Get-WNInstalledPrograms)) {
            $size = if ($p.SizeMB) { "$($p.SizeMB) MB" } else { '-' }
            [pscustomobject]@{
                Label    = $p.Name
                Value    = $p
                Detail   = T 'un.detail' $(if ($p.Publisher) { $p.Publisher } else { '-' }) $(if ($p.Version) { $p.Version } else { '-' }) $size
                Tag      = $(if ($p.Silent) { T 'un.tagSilent' } else { T 'un.tagWizard' })
                TagColor = $(if ($p.Silent) { 'Green' } else { 'Yellow' })
                Group    = $p.Publisher
            }
        }
        $r = Show-WNCheckList -Title (T 'un.desktopTitle') -Subtitle (T 'un.subtitle') -Items @($items) -EnterLabel (T 'enter.uninstall')
        if (-not $r) { return }
        Write-WNHeader (T 'un.confirmTitle' @($r.Items).Count)
        foreach ($p in $r.Items) {
            $mode = if ($p.Silent) { T 'un.tagSilent' } else { T 'un.tagWizard' }
            Write-Host ("   - {0,-55} {1}" -f $p.Name, $mode) -ForegroundColor $(if ($p.Silent) { 'Gray' } else { 'Yellow' })
        }
        Write-Host ''
        if ($r.Items | Where-Object { -not $_.Silent }) { Write-Host ('  ' + (T 'un.wizardNote')) -ForegroundColor Yellow }
        if ($WN.DryRun) { Write-Host ('  ' + (T 'tw.simNote')) -ForegroundColor Magenta }
        if (-not (Read-WNConfirm (T 'un.confirm'))) { continue }
        Uninstall-WNPrograms -Programs $r.Items
        Wait-WNKey
    }
}

function Show-WNStoreAppList {
    while ($true) {
        $items = foreach ($p in (Get-WNStoreApps)) {
            [pscustomobject]@{
                Label    = $p.Name
                Value    = $p
                Detail   = T 'un.detail' $p.Publisher $p.Version '-'
                Tag      = ''
                TagColor = 'DarkGray'
            }
        }
        $r = Show-WNCheckList -Title (T 'un.storeTitle') -Subtitle (T 'un.subtitle') -Items @($items) -EnterLabel (T 'enter.uninstall')
        if (-not $r) { return }
        Write-WNHeader (T 'un.confirmTitle' @($r.Items).Count)
        $r.Items | ForEach-Object { Write-Host "   - $($_.Name)  $($_.Version)" }
        Write-Host ''
        if ($WN.DryRun) { Write-Host ('  ' + (T 'tw.simNote')) -ForegroundColor Magenta }
        if (-not (Read-WNConfirm (T 'un.confirm'))) { continue }
        Uninstall-WNStoreApps -Packages $r.Items
        Wait-WNKey
    }
}

function Show-WNUninstallMenu {
    Write-WNStatus (T 'un.reading') Info
    while ($true) {
        $desktop = @(Get-WNInstalledPrograms)
        $store = @(Get-WNStoreApps)
        $items = @(
            @{ Label = (T 'un.menuDesktop' $desktop.Count); Value = 'desktop'; Hint = (T 'un.menuDesktopHint') }
            @{ Label = (T 'un.menuStore' $store.Count); Value = 'store'; Hint = (T 'un.menuStoreHint') }
            @{ Separator = $true; Label = '' }
            @{ Label = (T 'un.menuRefresh'); Value = 'refresh'; Hotkey = 'r'; Hint = (T 'un.menuRefreshHint') }
        )
        $choice = Show-WNMenu -Title (T 'un.title') -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'desktop' { Show-WNDesktopPrograms }
            'store'   { Show-WNStoreAppList }
            'refresh' { [void](Get-WNInstalledPrograms -Refresh); [void](Get-WNStoreApps -Refresh) }
        }
    }
}
