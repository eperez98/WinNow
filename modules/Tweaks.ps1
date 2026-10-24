# modules/Tweaks.ps1
# Tweaks, presets and preference toggles screens.

$script:TweakCategories = @(
    @{ Name = 'Essential';   Hint = 'Safe privacy and cleanup tweaks recommended for everyone' }
    @{ Name = 'Privacy';     Hint = 'Telemetry hosts, camera/mic, Copilot, Edge and Brave debloat' }
    @{ Name = 'Performance'; Hint = 'Power plans, services, visual effects, gaming' }
    @{ Name = 'Interface';   Hint = 'Context menu, Explorer, widgets, notifications' }
    @{ Name = 'Bloatware';   Hint = 'Remove preinstalled apps, Xbox, OneDrive, Edge' }
    @{ Name = 'Advanced';    Hint = 'Network stack, hosts blocks, AI removal - read descriptions first' }
)

function Get-WNStateTag {
    param([string]$State, [switch]$Toggle)
    if ($Toggle) {
        switch ($State) {
            'Applied' { return @('ON', 'Green') }
            'Partial' { return @('MIXED', 'Yellow') }
            default   { return @('OFF', 'DarkGray') }
        }
    }
    switch ($State) {
        'Applied'    { @('APPLIED', 'Green') }
        'Partial'    { @('PARTIAL', 'Yellow') }
        'NotApplied' { @('-', 'DarkGray') }
        'Action'     { @('ACTION', 'DarkCyan') }
        default      { @('?', 'DarkGray') }
    }
}

function ConvertTo-WNTweakItems {
    param([object[]]$Tweaks, [string[]]$Checked = @(), [switch]$Toggle, [switch]$ShowCategory)
    foreach ($t in $Tweaks) {
        $tag = Get-WNStateTag (Get-WNTweakState $t) -Toggle:$Toggle
        $risk = if ($t.Risk -ne 'Low') { " ($($t.Risk.ToUpper()) RISK)" } else { '' }
        $label = if ($ShowCategory) { "$($t.Name)  [$($t.Category)]" } else { $t.Name }
        [pscustomobject]@{
            Label    = "$label$risk"
            Value    = $t
            Detail   = $t.Description
            Tag      = $tag[0]
            TagColor = $tag[1]
            Group    = $t.Category
            Checked  = ($Checked -contains $t.Key)
        }
    }
}

function Confirm-WNTweakPlan {
    param([object[]]$Tweaks, [switch]$Undo)
    $verb = if ($Undo) { 'UNDO' } else { 'APPLY' }
    Write-WNHeader "Confirm: $verb $(@($Tweaks).Count) item(s)"
    foreach ($t in $Tweaks) {
        $color = switch ($t.Risk) { 'High' { 'Red' } 'Medium' { 'Yellow' } default { 'Gray' } }
        $note = if ($t.Type -eq 'Action' -and -not $Undo) { '  (one-shot, not undoable)' } elseif ($t.Appx -and -not $Undo) { '  (removes apps)' } else { '' }
        Write-Host ("   - {0,-52} {1,-6}{2}" -f $t.Name, $t.Risk, $note) -ForegroundColor $color
    }
    Write-Host ''
    if ($WN.DryRun) { Write-Host '  SIMULATION: nothing will be changed, every step is only printed.' -ForegroundColor Magenta }
    elseif (-not $WN.RestorePointDone -and -not $WN.NoRestorePoint) { Write-Host '  A System Restore Point will be created first.' -ForegroundColor DarkGray }
    if (-not $Undo -and ($Tweaks | Where-Object { $_.Risk -eq 'High' })) {
        Write-Host '  This list contains HIGH risk items.' -ForegroundColor Red
    }
    return (Read-WNConfirm 'Proceed?')
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
        $r = Show-WNCheckList -Title $Title -Items $items -Subtitle 'Space to select, Enter to apply' -EnterLabel 'apply' -Actions ([ordered]@{ U = 'Undo' })
        if (-not $r) { return }
        $Checked = @()
        Invoke-WNTweakSelection -Tweaks $r.Items -Undo:($r.Action -eq 'Undo')
    }
}

function Show-WNToggles {
    $toggles = @($WN.Config.tweaks | Where-Object { $_.Type -eq 'Toggle' })
    while ($true) {
        $items = @(ConvertTo-WNTweakItems -Tweaks $toggles -Toggle)
        $r = Show-WNCheckList -Title 'Preferences' -Items $items -Subtitle 'Enter flips the selected switches ON <-> OFF' -EnterLabel 'flip'
        if (-not $r) { return }
        $turnOn  = @($r.Items | Where-Object { (Get-WNTweakState $_) -ne 'Applied' })
        $turnOff = @($r.Items | Where-Object { (Get-WNTweakState $_) -eq 'Applied' })
        Write-WNHeader 'Preferences'
        foreach ($t in $turnOn)  { Write-Host "   $($t.Name)  ->  ON"  -ForegroundColor Green }
        foreach ($t in $turnOff) { Write-Host "   $($t.Name)  ->  OFF" -ForegroundColor Yellow }
        Write-Host ''
        if (-not (Read-WNConfirm 'Apply these changes?' -DefaultYes)) { continue }
        if ($turnOn.Count)  { Invoke-WNTweakBatch -Tweaks $turnOn }
        if ($turnOff.Count) { Invoke-WNTweakBatch -Tweaks $turnOff -Undo }
        Wait-WNKey
    }
}

function Show-WNPresets {
    $items = foreach ($name in $WN.Config.presets.PSObject.Properties.Name) {
        $p = $WN.Config.presets.$name
        @{ Label = "$name  ($(@($p.Tweaks).Count) items)"; Value = $name; Hint = $p.Description }
    }
    $choice = Show-WNMenu -Title 'Presets' -Subtitle 'Opens the preset pre-selected so you can review it' -Items @($items)
    if (-not $choice) { return }
    $keys = @($WN.Config.presets.$choice.Tweaks)
    $tweaks = @($keys | ForEach-Object { Get-WNTweak $_ } | Where-Object { $_ })
    Show-WNTweakList -Title "Preset: $choice" -Tweaks $tweaks -Checked $keys -ShowCategory
}

function Show-WNUndoApplied {
    Write-WNStatus 'Checking which tweaks are currently applied...' Info
    $applied = @($WN.Config.tweaks | Where-Object { $_.Type -eq 'Tweak' -and (Get-WNTweakState $_) -in 'Applied', 'Partial' })
    if ($applied.Count -eq 0) { Write-WNStatus 'No applied tweaks detected.' Ok; Wait-WNKey; return }
    $items = @(ConvertTo-WNTweakItems -Tweaks $applied -ShowCategory -Checked @($applied.Key))
    $r = Show-WNCheckList -Title 'Undo applied tweaks' -Items $items -Subtitle 'All detected tweaks are pre-selected' -EnterLabel 'undo'
    if ($r) { Invoke-WNTweakSelection -Tweaks $r.Items -Undo }
}

function Show-WNTweaksMenu {
    while ($true) {
        $items = @()
        foreach ($c in $script:TweakCategories) {
            $count = @($WN.Config.tweaks | Where-Object { $_.Category -eq $c.Name }).Count
            if ($count) { $items += @{ Label = "$($c.Name)  ($count)"; Value = "cat:$($c.Name)"; Hint = $c.Hint } }
        }
        $items += @{ Separator = $true; Label = '' }
        $items += @{ Label = 'Presets (Minimal / Standard / Heavy)'; Value = 'presets'; Hint = 'Pre-selected bundles you can review before applying'; Hotkey = 'p' }
        $items += @{ Label = 'All tweaks (search)'; Value = 'all'; Hint = 'Every tweak in one list, press / to search'; Hotkey = 's' }
        $items += @{ Label = 'Undo applied tweaks'; Value = 'undo'; Hint = 'Detects applied tweaks and reverts the ones you choose'; Hotkey = 'u' }

        $choice = Show-WNMenu -Title 'Tweaks' -Items $items
        if (-not $choice) { return }
        switch -Wildcard ($choice) {
            'cat:*'   { $cat = $choice.Substring(4); Show-WNTweakList -Title "Tweaks - $cat" -Tweaks @($WN.Config.tweaks | Where-Object { $_.Category -eq $cat }) }
            'presets' { Show-WNPresets }
            'all'     { Show-WNTweakList -Title 'All tweaks' -Tweaks @($WN.Config.tweaks | Where-Object { $_.Type -ne 'Toggle' }) -ShowCategory }
            'undo'    { Show-WNUndoApplied }
        }
    }
}
