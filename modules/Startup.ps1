# modules/Startup.ps1
# Startup Manager. Uses the same StartupApproved flags as Task Manager, so nothing is deleted
# and every change can be flipped back (here or in Task Manager).

$script:ApprovedBase = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'

function Get-WNStartupEntries {
    $sources = @(
        @{ Hive = 'HKCU:'; Key = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run'; Scope = 'User' }
        @{ Hive = 'HKLM:'; Key = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run'; Scope = 'Machine' }
        @{ Hive = 'HKLM:'; Key = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run32'; Scope = 'Machine (32-bit)' }
    )
    foreach ($s in $sources) {
        $path = "$($s.Hive)\$($s.Key)"
        if (-not (Test-Path $path)) { continue }
        $props = Get-ItemProperty -Path $path
        foreach ($p in $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' }) {
            [pscustomobject]@{ Name = $p.Name; Command = [string]$p.Value; Scope = $s.Scope; ApprovedPath = "$($s.Hive)\$script:ApprovedBase\$($s.Approved)" }
        }
    }
    $folders = @(
        @{ Path = [Environment]::GetFolderPath('Startup'); Hive = 'HKCU:'; Scope = 'User folder' }
        @{ Path = [Environment]::GetFolderPath('CommonStartup'); Hive = 'HKLM:'; Scope = 'All users folder' }
    )
    foreach ($f in $folders) {
        if (-not $f.Path -or -not (Test-Path $f.Path)) { continue }
        foreach ($file in Get-ChildItem -Path $f.Path -File -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini') {
            [pscustomobject]@{ Name = $file.Name; Command = $file.FullName; Scope = $f.Scope; ApprovedPath = "$($f.Hive)\$script:ApprovedBase\StartupFolder" }
        }
    }
}

function Test-WNStartupEnabled {
    param($Entry)
    $v = Get-WNRegistryValue $Entry.ApprovedPath $Entry.Name
    if ($null -eq $v -or $v.Count -eq 0) { return $true }
    return (($v[0] -band 1) -eq 0)
}

function Set-WNStartupEnabled {
    param($Entry, [bool]$Enabled)
    $state = if ($Enabled) { 'enable' } else { 'disable' }
    if ($WN.DryRun) { Write-WNStatus "Would $state startup item '$($Entry.Name)'" Dry 'Startup'; return }
    # 12 bytes: flag + FILETIME of the change (Task Manager format)
    $bytes = New-Object byte[] 12
    $bytes[0] = if ($Enabled) { 2 } else { 3 }
    if (-not $Enabled) { [BitConverter]::GetBytes((Get-Date).ToFileTimeUtc()).CopyTo($bytes, 4) }
    try {
        if (-not (Test-Path $Entry.ApprovedPath)) { New-Item -Path $Entry.ApprovedPath -Force | Out-Null }
        Set-ItemProperty -Path $Entry.ApprovedPath -Name $Entry.Name -Type Binary -Value $bytes -ErrorAction Stop
        Write-WNStatus "$($Entry.Name): $($state)d" Ok 'Startup'
    } catch {
        Write-WNStatus "$($Entry.Name): $($_.Exception.Message)" Error 'Startup'
    }
}

function Show-WNStartupMenu {
    while ($true) {
        $entries = @(Get-WNStartupEntries)
        $items = foreach ($e in $entries) {
            $on = Test-WNStartupEnabled $e
            [pscustomobject]@{
                Label    = "$($e.Name)  [$($e.Scope)]"
                Value    = $e
                Detail   = $e.Command
                Tag      = $(if ($on) { 'ENABLED' } else { 'DISABLED' })
                TagColor = $(if ($on) { 'Green' } else { 'DarkGray' })
            }
        }
        $r = Show-WNCheckList -Title 'Startup Manager' -Subtitle 'Same switches as Task Manager > Startup apps' -Items @($items) `
             -EnterLabel 'flip' -Actions ([ordered]@{ E = 'Enable'; D = 'Disable' })
        if (-not $r) { return }
        if (-not (Test-WNCanChange)) { Wait-WNKey; continue }
        Write-WNHeader 'Startup Manager'
        $regs = @($r.Items | ForEach-Object { [pscustomobject]@{ Path = $_.ApprovedPath; Name = $_.Name } })
        if (-not (Start-WNChange -Label 'startup apps' -Registry $regs -Items @($r.Items | ForEach-Object Name))) { Wait-WNKey; continue }
        foreach ($e in $r.Items) {
            $target = switch ($r.Action) { 'Enable' { $true } 'Disable' { $false } default { -not (Test-WNStartupEnabled $e) } }
            Set-WNStartupEnabled -Entry $e -Enabled $target
        }
        Wait-WNKey
    }
}
