# modules/Network.ps1
# DNS changer and hosts file blocks. Hosts helpers are also used by tweaks.

$script:HostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"

#region Hosts
function Get-WNHostsLines { if (Test-Path $script:HostsFile) { @(Get-Content -Path $script:HostsFile -ErrorAction SilentlyContinue) } else { @() } }

function Backup-WNHosts {
    $dest = Join-Path $WN.DataDir ("backup\hosts_{0}.bak" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Copy-Item -Path $script:HostsFile -Destination $dest -Force
    Write-WNLog "hosts backed up to $dest" -Component 'Hosts'
}

function Set-WNHostsLines {
    param([string[]]$Lines)
    Backup-WNHosts
    # Defender or an editor can hold the file briefly; retry a few times
    for ($try = 1; $try -le 3; $try++) {
        try { Set-Content -Path $script:HostsFile -Value $Lines -Encoding ASCII -Force -ErrorAction Stop; return }
        catch { if ($try -eq 3) { throw }; Start-Sleep -Milliseconds 500 }
    }
}

# Blocks are written between markers so they can be removed exactly
function Get-WNHostsMarkers { param([string]$Name, [string]$Brand = 'Winnow') @("# >>> ${Brand}:$Name", "# <<< ${Brand}:$Name") }
# Blocks written before the rename used the old tool name; they are still detected and removed
$script:HostsBrands = @('Winnow', 'WinTooler')

function Test-WNHostsBlock {
    param([Parameter(Mandatory)][string]$Name)
    $lines = Get-WNHostsLines
    foreach ($b in $script:HostsBrands) { if ($lines -contains (Get-WNHostsMarkers $Name $b)[0]) { return $true } }
    return $false
}

function Remove-WNHostsBlock {
    param([Parameter(Mandatory)][string]$Name)
    $begins = $script:HostsBrands | ForEach-Object { (Get-WNHostsMarkers $Name $_)[0] }
    $ends = $script:HostsBrands | ForEach-Object { (Get-WNHostsMarkers $Name $_)[1] }
    $out = New-Object System.Collections.Generic.List[string]
    $inside = $false
    foreach ($l in (Get-WNHostsLines)) {
        if ($begins -contains $l) { $inside = $true; continue }
        if ($ends -contains $l) { $inside = $false; continue }
        if (-not $inside) { $out.Add($l) }
    }
    Set-WNHostsLines $out.ToArray()
    [void](ipconfig /flushdns)
}

function Add-WNHostsBlock {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string[]]$Domains)
    if (Test-WNHostsBlock $Name) { Remove-WNHostsBlock $Name }
    $begin, $end = Get-WNHostsMarkers $Name
    $lines = @(Get-WNHostsLines)
    while ($lines.Count -and [string]::IsNullOrWhiteSpace($lines[-1])) { $lines = $lines[0..($lines.Count - 2)] }
    $lines += ''
    $lines += $begin
    $lines += ($Domains | ForEach-Object { "0.0.0.0 $_" })
    $lines += $end
    Set-WNHostsLines $lines
    [void](ipconfig /flushdns)
    Write-WNStatus (T 'hosts.added' $Domains.Count $Name) Info 'Hosts'
}
#endregion

#region DNS
function Get-WNActiveAdapters { @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up') }

function Get-WNCurrentDns {
    foreach ($a in (Get-WNActiveAdapters)) {
        [pscustomobject]@{
            Name = $a.Name
            IPv4 = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ', '
            IPv6 = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue).ServerAddresses -join ', '
        }
    }
}

function Show-WNCurrentDns {
    foreach ($d in (Get-WNCurrentDns)) {
        Write-Host ("   {0,-28} IPv4: {1}" -f $d.Name, $(if ($d.IPv4) { $d.IPv4 } else { T 'dns.none' })) -ForegroundColor Gray
        if ($d.IPv6) { Write-Host ("   {0,-28} IPv6: {1}" -f '', $d.IPv6) -ForegroundColor DarkGray }
    }
}

function Set-WNDns {
    param([Parameter(Mandatory)][string]$Provider)
    if (-not (Test-WNCanChange)) { return }
    $adapters = Get-WNActiveAdapters
    if ($adapters.Count -eq 0) { Write-WNStatus (T 'dns.noAdapters') Warn 'DNS'; return }
    if (-not (Start-WNChange -Label "dns $Provider" -Dns)) { return }
    $dns = if ($Provider -ne 'DHCP') { $WN.Config.dns.$Provider } else { $null }
    foreach ($a in $adapters) {
        if ($Provider -eq 'DHCP') {
            if ($WN.DryRun) { Write-WNStatus (T 'dns.dryDhcp' $a.Name) Dry 'DNS'; continue }
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-WNStatus "'$($a.Name)' -> DHCP" Ok 'DNS'
            continue
        }
        $v4 = @($dns.Primary, $dns.Secondary | Where-Object { $_ })
        $v6 = @($dns.Primary6, $dns.Secondary6 | Where-Object { $_ })
        if ($WN.DryRun) { Write-WNStatus (T 'dns.drySet' $a.Name ($v4 -join ', ') ($v6 -join ', ')) Dry 'DNS'; continue }
        try {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ($v4 + $v6) -ErrorAction Stop
            Write-WNStatus "'$($a.Name)' -> $Provider ($($v4 -join ', '))" Ok 'DNS'
        } catch {
            Write-WNStatus "'$($a.Name)': $($_.Exception.Message)" Error 'DNS'
        }
    }
    if (-not $WN.DryRun) { Clear-DnsClientCache -ErrorAction SilentlyContinue }
}

function Show-WNDnsMenu {
    while ($true) {
        $items = @()
        foreach ($p in $WN.Config.dns.PSObject.Properties) {
            $items += @{ Label = ($p.Name -replace '_', ' '); Value = $p.Name; Hint = "$($p.Value.Primary), $($p.Value.Secondary)" }
        }
        $items += @{ Separator = $true; Label = '' }
        $items += @{ Label = (T 'dns.dhcp'); Value = 'DHCP'; Hotkey = 'd'; Hint = (T 'dns.dhcpHint') }
        $items += @{ Label = (T 'dns.show'); Value = 'show'; Hotkey = 'c'; Hint = (T 'dns.showHint') }
        $choice = Show-WNMenu -Title (T 'dns.title') -Subtitle (T 'dns.subtitle') -Items $items
        if (-not $choice) { return }
        Write-WNHeader 'DNS'
        if ($choice -ne 'show') {
            Set-WNDns -Provider $choice
            Write-Host ''
        }
        Show-WNCurrentDns
        Wait-WNKey
    }
}
#endregion

function Show-WNHostsMenu {
    while ($true) {
        $tele = if (Test-WNHostsBlock 'telemetry') { T 'hosts.on' } else { T 'hosts.off' }
        $adobe = if (Test-WNHostsBlock 'adobe') { T 'hosts.on' } else { T 'hosts.off' }
        $items = @(
            @{ Label = (T 'hosts.view'); Value = 'view'; Hint = (T 'hosts.viewHint') }
            @{ Label = (T 'hosts.tele' $tele); Value = 'TelemetryHosts'; Hint = (T 'hosts.teleHint') }
            @{ Label = (T 'hosts.adobe' $adobe); Value = 'AdobeHosts'; Hint = (T 'hosts.adobeHint') }
            @{ Label = (T 'hosts.edit'); Value = 'edit'; Hint = (T 'hosts.editHint') }
            @{ Label = (T 'hosts.backups'); Value = 'backups'; Hint = (Join-Path $WN.DataDir 'backup') }
        )
        $choice = Show-WNMenu -Title (T 'hosts.title') -Items $items
        if (-not $choice) { return }
        switch ($choice) {
            'view' { Show-WNText (T 'hosts.viewTitle') @(Get-WNHostsLines | Where-Object { $_ -and $_.Trim() -notmatch '^#' }) }
            'edit' { if (Test-WNCanChange) { if (-not $WN.DryRun) { if (Start-WNChange -Label 'hosts edit') { Backup-WNHosts; Start-Process notepad.exe $script:HostsFile } } else { Write-WNStatus (T 'hosts.dryEdit') Dry; Wait-WNKey } } }
            'backups' { Start-Process explorer.exe (Join-Path $WN.DataDir 'backup') }
            default {
                $t = Get-WNTweak $choice
                $isOn = (Get-WNTweakState $t) -eq 'Applied'
                Invoke-WNTweakSelection -Tweaks @($t) -Undo:$isOn
            }
        }
    }
}
