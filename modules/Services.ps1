# modules/Services.ps1
# Services Manager: compare current startup type with the recommendation and apply or restore it.

function Show-WNServicesMenu {
    while ($true) {
        $items = foreach ($s in $WN.Config.services) {
            $cur = Get-WNServiceStartup $s.Name
            if ($null -eq $cur) { $tag = T 'svc.missing'; $color = 'DarkGray' }
            elseif ($cur -eq $s.Recommended) { $tag = $cur; $color = 'Green' }
            else { $tag = $cur; $color = 'Yellow' }
            $risk = if ($s.Risk -ne 'Low') { T 'common.risk' (T "risk.$($s.Risk)").ToUpper() } else { '' }
            [pscustomobject]@{
                Label    = "$($s.DisplayName)$risk"
                Value    = $s
                Detail   = T 'svc.detail' $s.Name $s.Description $s.Recommended $s.Default
                Tag      = $tag
                TagColor = $color
                Group    = $s.Category
            }
        }
        $r = Show-WNCheckList -Title (T 'svc.title') -Subtitle (T 'svc.subtitle') -Items @($items) `
             -EnterLabel (T 'enter.recommended') -Actions ([ordered]@{ D = 'Default'; M = 'Manual' })
        if (-not $r) { return }
        if (-not (Test-WNCanChange)) { Wait-WNKey; continue }

        Write-WNHeader (T 'svc.title')
        $plan = foreach ($s in $r.Items) {
            $target = switch ($r.Action) { 'Default' { $s.Default } 'Manual' { 'Manual' } default { $s.Recommended } }
            Write-Host ("   {0,-45} {1,-22} -> {2}" -f $s.DisplayName, (Get-WNServiceStartup $s.Name), $target)
            [pscustomobject]@{ Name = $s.Name; Target = $target }
        }
        Write-Host ''
        if (-not (Read-WNConfirm (T 'svc.apply') -DefaultYes)) { continue }
        if (-not (Start-WNChange -Label 'services' -Services @($plan | ForEach-Object Name))) { continue }
        foreach ($p in $plan) {
            $before = $WN.ErrorCount
            Set-WNService -Name $p.Name -StartupType $p.Target
            if ($WN.ErrorCount -eq $before) { Write-WNStatus "$($p.Name) -> $($p.Target)" $(if ($WN.DryRun) { 'Dry' } else { 'Ok' }) 'Service' }
        }
        Wait-WNKey
    }
}
