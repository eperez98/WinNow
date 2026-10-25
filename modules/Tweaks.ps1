# modules/Tweaks.ps1
# Tweaks, presets and preference toggles screens.

$script:TweakCategories = @('Essential', 'Privacy', 'Performance', 'Interface', 'Bloatware', 'Advanced')

function Get-WNStateTag {
    param([string]$State, [switch]$Toggle)
    if ($Toggle) {
        switch ($State) {
            'Applied' { return @((T 'state.On'), 'Green') }
            'Partial' { return @((T 'state.Mixed'), 'Yellow') }
            default   { return @((T 'state.Off'), 'DarkGray') }
        }
    }
    switch ($State) {
        'Applied'    { @((T 'state.Applied'), 'Green') }
        'Partial'    { @((T 'state.Partial'), 'Yellow') }
        'NotApplied' { @('-', 'DarkGray') }
        'Action'     { @((T 'state.Action'), 'DarkCyan') }
        default      { @('?', 'DarkGray') }
    }
}

function ConvertTo-WNTweakItems {
    param([object[]]$Tweaks, [string[]]$Checked = @(), [switch]$Toggle, [switch]$ShowCategory)
    foreach ($t in $Tweaks) {
        $tag = Get-WNStateTag (Get-WNTweakState $t) -Toggle:$Toggle
        $risk = if ($t.Risk -ne 'Low') { T 'common.risk' (T "risk.$($t.Risk)").ToUpper() } else { '' }
        $label = if ($ShowCategory) { "$($t.Name)  [$(T "cat.$($t.Category)")]" } else { $t.Name }
        [pscustomobject]@{
            Label    = "$label$risk"
            Value    = $t
            Detail   = $t.Description
            Tag      = $tag[0]
            TagColor = $tag[1]
            Group    = T "cat.$($t.Category)"
            Checked  = ($Checked -contains $t.Key)
        }
    }
}

function Confirm-WNTweakPlan {
    param([object[]]$Tweaks, [switch]$Undo)
    $verb = if ($Undo) { T 'verb.undoCaps' } else { T 'verb.applyCaps' }
    Write-WNHeader (T 'tw.confirmTitle' $verb @($Tweaks).Count)
    foreach ($t in $Tweaks) {
        $color = switch ($t.Risk) { 'High' { 'Red' } 'Medium' { 'Yellow' } default { 'Gray' } }
        $note = if ($t.Type -eq 'Action' -and -not $Undo) { T 'tw.noteOneShot' } elseif ($t.Appx -and -not $Undo) { T 'tw.noteRemovesApps' } else { '' }
        Write-Host ("   - {0,-52} {1,-6}{2}" -f $t.Name, (T "risk.$($t.Risk)"), $note) -ForegroundColor $color
    }
    Write-Host ''
    if ($WN.DryRun) { Write-Host ('  ' + (T 'tw.simNote')) -ForegroundColor Magenta }
    elseif (-not $WN.RestorePointDone -and -not $WN.NoRestorePoint) { Write-Host ('  ' + (T 'tw.rpNote')) -ForegroundColor DarkGray }
    if (-not $Undo -and ($Tweaks | Where-Object { $_.Risk -eq 'High' })) {
        Write-Host ('  ' + (T 'tw.highRisk')) -ForegroundColor Red
    }
    return (Read-WNConfirm (T 'common.proceed'))
}

function Invoke-WNTweakSelection {
    param([object[]]$Tweaks, [switch]$Undo)
    if (-not $Tweaks -or @($Tweaks).Count -eq 0) { return }
    if (-not (Confirm-WNTweakPlan -Tweaks $Tweaks -Undo:$Undo)) { return }
    Invoke-WNTweakBatch -Tweaks $Tweaks -Undo:$Undo
    Wait-WNKey
}

function Show-WNTweakList {
    param([string]$Title, [object[]]$Tweaks, [string[]]$Checked = @(), [switch]$ShowCategory)
    while ($true) {
        $items = @(ConvertTo-WNTweakItems -Tweaks $Tweaks -Checked $Checked -ShowCategory:$ShowCategory)
        $r = Show-WNCheckList -Title $Title -Items $items -Subtitle (T 'tw.listSubtitle') -EnterLabel (T 'enter.apply') -Actions ([ordered]@{ U = 'Undo' })
        if (-not $r) { return }
        $Checked = @()
        Invoke-WNTweakSelection -Tweaks $r.Items -Undo:($r.Action -eq 'Undo')
    }
}

function Show-WNToggles {
    $toggles = @($WN.Config.tweaks | Where-Object { $_.Type -eq 'Toggle' })
    while ($true) {
        $items = @(ConvertTo-WNTweakItems -Tweaks $toggles -Toggle)
        $r = Show-WNCheckList -Title (T 'pref.title') -Items $items -Subtitle (T 'pref.subtitle') -EnterLabel (T 'enter.flip')
        if (-not $r) { return }
        $turnOn  = @($r.Items | Where-Object { (Get-WNTweakState $_) -ne 'Applied' })
        $turnOff = @($r.Items | Where-Object { (Get-WNTweakState $_) -eq 'Applied' })
        Write-WNHeader (T 'pref.title')
        foreach ($t in $turnOn)  { Write-Host "   $($t.Name)  ->  $(T 'state.On')"  -ForegroundColor Green }
        foreach ($t in $turnOff) { Write-Host "   $($t.Name)  ->  $(T 'state.Off')" -ForegroundColor Yellow }
        Write-Host ''
        if (-not (Read-WNConfirm (T 'pref.apply') -DefaultYes)) { continue }
        if ($turnOn.Count)  { Invoke-WNTweakBatch -Tweaks $turnOn }
        if ($turnOff.Count) { Invoke-WNTweakBatch -Tweaks $turnOff -Undo }
        Wait-WNKey
    }
}

function Show-WNPresets {
    $items = foreach ($name in $WN.Config.presets.PSObject.Properties.Name) {
        $p = $WN.Config.presets.$name
        @{ Label = (T 'preset.item' (T "preset.$name") @($p.Tweaks).Count); Value = $name; Hint = $p.Description }
    }
    $choice = Show-WNMenu -Title (T 'preset.title') -Subtitle (T 'preset.subtitle') -Items @($items)
    if (-not $choice) { return }
    $keys = @($WN.Config.presets.$choice.Tweaks)
    $tweaks = @($keys | ForEach-Object { Get-WNTweak $_ } | Where-Object { $_ })
    Show-WNTweakList -Title (T 'preset.listTitle' (T "preset.$choice")) -Tweaks $tweaks -Checked $keys -ShowCategory
}

function Show-WNUndoApplied {
    Write-WNStatus (T 'undo.checking') Info
    $applied = @($WN.Config.tweaks | Where-Object { $_.Type -eq 'Tweak' -and (Get-WNTweakState $_) -in 'Applied', 'Partial' })
    if ($applied.Count -eq 0) { Write-WNStatus (T 'undo.none') Ok; Wait-WNKey; return }
    $items = @(ConvertTo-WNTweakItems -Tweaks $applied -ShowCategory -Checked @($applied.Key))
    $r = Show-WNCheckList -Title (T 'undo.title') -Items $items -Subtitle (T 'undo.subtitle') -EnterLabel (T 'enter.undo')
    if ($r) { Invoke-WNTweakSelection -Tweaks $r.Items -Undo }
}

function Show-WNTweaksMenu {
    while ($true) {
        $items = @()
        foreach ($c in $script:TweakCategories) {
            $count = @($WN.Config.tweaks | Where-Object { $_.Category -eq $c }).Count
            if ($count) { $items += @{ Label = "$(T "cat.$c")  ($count)"; Value = "cat:$c"; Hint = (T "catHint.$c") } }
        }
        $items += @{ Separator = $true; Label = '' }
        $items += @{ Label = (T 'tw.menuPresets'); Value = 'presets'; Hint = (T 'tw.menuPresetsHint'); Hotkey = 'p' }
        $items += @{ Label = (T 'tw.menuAll'); Value = 'all'; Hint = (T 'tw.menuAllHint'); Hotkey = 's' }
        $items += @{ Label = (T 'tw.menuUndo'); Value = 'undo'; Hint = (T 'tw.menuUndoHint'); Hotkey = 'u' }

        $choice = Show-WNMenu -Title (T 'tw.title') -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'cat:*'   { $cat = $choice.Substring(4); Show-WNTweakList -Title (T 'tw.catTitle' (T "cat.$cat")) -Tweaks @($WN.Config.tweaks | Where-Object { $_.Category -eq $cat }) }
            'presets' { Show-WNPresets }
            'all'     { Show-WNTweakList -Title (T 'tw.all') -Tweaks @($WN.Config.tweaks | Where-Object { $_.Type -ne 'Toggle' }) -ShowCategory }
            'undo'    { Show-WNUndoApplied }
        }
    }
}
