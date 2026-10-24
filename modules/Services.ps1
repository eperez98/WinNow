# modules/Services.ps1
# Services Manager: compare current startup type with the recommendation and apply or restore it.

function Show-WNServicesMenu {
    while ($true) {
        $items = foreach ($s in $WN.Config.services) {
            $cur = Get-WNServiceStartup $s.Name
            if ($null -eq $cur) { $tag = 'missing'; $color = 'DarkGray' }
            elseif ($cur -eq $s.Recommended) { $tag = $cur; $color = 'Green' }
            else { $tag = $cur; $color = 'Yellow' }
            $risk = if ($s.Risk -ne 'Low') { " ($($s.Risk.ToUpper()) RISK)" } else { '' }
            [pscustomobject]@{
                Label    = "$($s.DisplayName)$risk"
                Value    = $s
                Detail   = "$($s.Name): $($s.Description)  | recommended: $($s.Recommended), Windows default: $($s.Default)"
                Tag      = $tag
                TagColor = $color
                Group    = $s.Category
            }
        }
        $r = Show-WNCheckList -Title 'Services Manager' -Subtitle 'Green = already at recommended' -Items @($items) `
             -EnterLabel 'set recommended' -Actions ([ordered]@{ D = 'Default'; M = 'Manual' })
        if (-not $r) { return }
        if (-not (Test-WNCanChange)) { Wait-WNKey; continue }

        Write-WNHeader 'Services Manager'
        $plan = foreach ($s in $r.Items) {
            $target = switch ($r.Action) { 'Default' { $s.Default } 'Manual' { 'Manual' } default { $s.Recommended } }
            Write-Host ("   {0,-45} {1,-22} -> {2}" -f $s.DisplayName, (Get-WNServiceStartup $s.Name), $target)
            [pscustomobject]@{ Name = $s.Name; Target = $target }
        }
        Write-Host ''
        if (-not (Read-WNConfirm 'Apply?' -DefaultYes)) { continue }
        if (-not (Start-WNChange -Label 'services' -Services @($plan | ForEach-Object Name))) { continue }
        foreach ($p in $plan) {
            $before = $WN.ErrorCount
            Set-WNService -Name $p.Name -StartupType $p.Target
            if ($WN.ErrorCount -eq $before) { Write-WNStatus "$($p.Name) -> $($p.Target)" $(if ($WN.DryRun) { 'Dry' } else { 'Ok' }) 'Service' }
        }
        Wait-WNKey
    }
}
