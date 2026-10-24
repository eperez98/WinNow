# core/Tui.ps1
# Keyboard-driven terminal UI: arrow-key menus, multi-select check lists with search,
# confirmations. Falls back to numbered prompts when input is redirected.

function Initialize-WNConsole {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    try { $Host.UI.RawUI.WindowTitle = "$($WN.Name) $($WN.Version)$(if ($WN.DryRun) { ' [SIMULATION]' })" } catch { }
}

function Get-WNConsoleSize {
    try { return @{ Width = [Math]::Max(60, [Console]::WindowWidth); Height = [Math]::Max(20, [Console]::WindowHeight) } }
    catch { return @{ Width = 100; Height = 30 } }
}

function Set-WNCursor {
    param([bool]$Visible)
    try { [Console]::CursorVisible = $Visible } catch { }
}

# Writes coloured segments on one line and pads it so leftovers of a previous frame are erased.
# Each segment: @(text, foreground, background) - background optional.
function Write-WNSegments {
    param([object[]]$Segments, [int]$Width = (Get-WNConsoleSize).Width, [string]$FillBg)
    $used = 0
    foreach ($s in $Segments) {
        $text = [string]$s[0]
        if ($used + $text.Length -gt $Width - 1) { $text = $text.Substring(0, [Math]::Max(0, $Width - 1 - $used)) }
        if ($text.Length -eq 0) { continue }
        $params = @{ Object = $text; NoNewline = $true }
        if ($s.Count -gt 1 -and $s[1]) { $params.ForegroundColor = $s[1] }
        if ($s.Count -gt 2 -and $s[2]) { $params.BackgroundColor = $s[2] }
        Write-Host @params
        $used += $text.Length
    }
    $pad = ' ' * [Math]::Max(0, $Width - 1 - $used)
    if ($FillBg) { Write-Host $pad -BackgroundColor $FillBg } else { Write-Host $pad }
}

# Logo: the mark (a W with grains falling through it, as on Winnow_logo.png) next to the name.
$script:WNMark = @(
    @(' \\      // ', 'Green'),
    @('  \\ /\ //  ', 'Green'),
    @('   \V  V/   ', 'Cyan'),
    @('  o   o   o ', 'Yellow'),
    @('      o     ', 'Yellow')
)
$script:WNGlyphs = @{
    w = @('          ', '__      __', '\ \ /\ / /', ' \ V  V / ', '  \_/\_/  ')
    i = @(' _ ', '(_)', '| |', '| |', '|_|')
    n = @('       ', ' _ __  ', '| ''_ \ ', '| | | |', '|_| |_|')
    o = @('       ', '  ___  ', ' / _ \ ', '| (_) |', ' \___/ ')
}

function Write-WNBanner {
    $rowColors = 'Green', 'Green', 'Cyan', 'Cyan', 'DarkCyan'
    for ($r = 0; $r -lt 5; $r++) {
        $name = -join ('winnow'.ToCharArray() | ForEach-Object { $script:WNGlyphs["$_"][$r] })
        Write-Host '  ' -NoNewline
        Write-Host $script:WNMark[$r][0] -ForegroundColor $script:WNMark[$r][1] -NoNewline
        Write-Host "   $name" -ForegroundColor $rowColors[$r]
    }
    Write-Host '                 sift Windows down to what matters' -ForegroundColor DarkGray
}

function Write-WNHeader {
    param([string]$Title, [string]$Subtitle, [switch]$Banner)
    if ($WN.Interactive) { Clear-Host }
    $w = (Get-WNConsoleSize).Width
    $line = '=' * [Math]::Min(78, $w - 4)
    $admin = if ($WN.IsAdmin) { @('Admin', 'Green') } else { @('Not admin', 'Yellow') }
    Write-Host ''
    # The full banner needs ~7 extra rows; on shorter windows the menu would scroll it out of view
    if ($Banner -and (Get-WNConsoleSize).Height -ge 40) { Write-WNBanner; Write-Host '' }
    Write-Host "  $line" -ForegroundColor DarkCyan
    $seg = @(
        @('   ', $null), @('\/\/', 'Green'), @('.', 'Yellow'), @(' winnow', 'Cyan'), @(" $($WN.Version)", 'White'),
        @('  |  ', 'DarkGray'), @("$($WN.OSLabel) build $($WN.OSBuild)", 'Gray'),
        @('  |  ', 'DarkGray'), $admin
    )
    if ($WN.DryRun) { $seg += , @('  |  ', 'DarkGray'); $seg += , @(' SIMULATION ', 'Black', 'Magenta') }
    Write-WNSegments $seg
    Write-Host "  $line" -ForegroundColor DarkCyan
    if ($Title) {
        Write-Host ''
        Write-Host "  $Title" -ForegroundColor White -NoNewline
        if ($Subtitle) { Write-Host "  $Subtitle" -ForegroundColor DarkGray } else { Write-Host '' }
    }
    Write-Host ''
}

function Clear-WNKeyBuffer {
    # winget and other console tools query the terminal (cursor position, device attributes);
    # the terminal's answers land in the input buffer as ESC sequences and would be read as
    # Esc key presses, closing every menu up to the app itself. Drop anything pending.
    try { while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) } } catch { }
}

function Read-WNKey {
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -ne 'Escape') { return $k }
        # A real Esc arrives alone; an ESC followed immediately by more input is a terminal reply
        Start-Sleep -Milliseconds 30
        if (-not [Console]::KeyAvailable) { return $k }
        Clear-WNKeyBuffer
    }
}

function Read-WNConfirm {
    param([Parameter(Mandatory)][string]$Message, [switch]$DefaultYes)
    if ($WN.Yes) { return $true }
    $hint = if ($DefaultYes) { '[Y/n]' } else { '[y/N]' }
    Write-Host "  $Message $hint " -ForegroundColor Yellow -NoNewline
    if ($WN.Interactive) {
        Clear-WNKeyBuffer
        while ($true) {
            $k = Read-WNKey
            switch ($k.Key) {
                'Y'      { Write-Host 'y'; return $true }
                'N'      { Write-Host 'n'; return $false }
                'Escape' { Write-Host 'n'; return $false }
                'Enter'  { Write-Host $(if ($DefaultYes) { 'y' } else { 'n' }); return [bool]$DefaultYes }
            }
        }
    }
    $a = Read-Host
    if ([string]::IsNullOrWhiteSpace($a)) { return [bool]$DefaultYes }
    return $a.Trim() -match '^(y|yes|s|si)$'
}

function Read-WNText {
    param([Parameter(Mandatory)][string]$Prompt, [string]$Default)
    Set-WNCursor $true
    Clear-WNKeyBuffer
    $suffix = if ($Default) { " [$Default]" } else { '' }
    $a = Read-Host "  $Prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
    return $a.Trim()
}

function Wait-WNKey {
    if (-not $WN.Interactive) { return }
    Clear-WNKeyBuffer
    Write-Host ''
    Write-Host '  Press Enter to continue...' -ForegroundColor Cyan -NoNewline
    # Only Enter/Space continue, so a stray key from a finished command cannot skip this screen
    while ($true) { $k = Read-WNKey; if ($k.Key -in 'Enter', 'Spacebar', 'Escape') { break } }
    Write-Host ''
}

# Single-choice menu.
# Items: hashtables with Label, Value, optional Hint, Hotkey (single char), Separator=$true for section headers.
# Returns the Value of the chosen item, or $null on Esc / Back.
function Show-WNMenu {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Items,
        [string]$Subtitle,
        [string]$BackLabel = 'Back',
        [switch]$Banner
    )
    $items = @($Items) + @(@{ Separator = $true; Label = '' }, @{ Label = $BackLabel; Value = $null; Hotkey = '0'; IsBack = $true })
    $selectable = @(for ($i = 0; $i -lt $items.Count; $i++) { if (-not $items[$i].Separator) { $i } })

    # Number the selectable items that have no explicit hotkey
    $n = 1
    foreach ($i in $selectable) {
        if (-not $items[$i].Hotkey) { $items[$i].Hotkey = if ($n -le 9) { "$n" } else { [string][char](96 + $n - 9) }; $n++ }
    }

    if (-not $WN.Interactive) {
        Write-WNHeader $Title $Subtitle -Banner:$Banner
        foreach ($it in $items) {
            if ($it.Separator) { if ($it.Label) { Write-Host "  -- $($it.Label) --" -ForegroundColor DarkCyan }; continue }
            Write-Host ("   {0}) {1}" -f $it.Hotkey, $it.Label)
        }
        $a = Read-Host '  Select'
        if ($null -eq $a) { return $null }
        $hit = $items | Where-Object { -not $_.Separator -and $_.Hotkey -eq $a.Trim() } | Select-Object -First 1
        if ($hit) { return $hit.Value }
        return $null
    }

    $pos = 0
    Clear-WNKeyBuffer
    Set-WNCursor $false
    Write-WNHeader $Title $Subtitle -Banner:$Banner
    $top = [Console]::CursorTop
    while ($true) {
        [Console]::SetCursorPosition(0, $top)
        $width = (Get-WNConsoleSize).Width
        for ($i = 0; $i -lt $items.Count; $i++) {
            $it = $items[$i]
            if ($it.Separator) {
                if ($it.Label) { Write-WNSegments @(, @("   $($it.Label)", 'DarkCyan')) $width } else { Write-WNSegments @(, @('', $null)) $width }
                continue
            }
            $isSel = ($selectable[$pos] -eq $i)
            if ($isSel) {
                Write-WNSegments @(@('  > ', 'Cyan'), @(" $($it.Hotkey) ", 'Black', 'Cyan'), @(" $($it.Label) ", 'White', 'DarkCyan')) $width
            } else {
                Write-WNSegments @(@('    ', $null), @(" $($it.Hotkey) ", 'DarkGray'), @(" $($it.Label)", 'Gray')) $width
            }
        }
        Write-WNSegments @(, @('', $null)) $width
        $hint = $items[$selectable[$pos]].Hint
        Write-WNSegments @(, @("  $hint", 'DarkGray')) $width
        Write-WNSegments @(, @('', $null)) $width
        Write-WNSegments @(, @('  Up/Down move   Enter select   number = shortcut   Esc back', 'DarkGray')) $width

        $k = Read-WNKey
        $handled = $true
        switch ($k.Key) {
            'UpArrow'   { $pos = ($pos - 1 + $selectable.Count) % $selectable.Count }
            'DownArrow' { $pos = ($pos + 1) % $selectable.Count }
            'Home'      { $pos = 0 }
            'End'       { $pos = $selectable.Count - 1 }
            'Enter'     { Set-WNCursor $true; return $items[$selectable[$pos]].Value }
            'Escape'    { Set-WNCursor $true; return $null }
            'Backspace' { Set-WNCursor $true; return $null }
            default     { $handled = $false }
        }
        if ($handled) { continue }
        $ch = [string]$k.KeyChar
        if ($ch) {
            $hit = $items | Where-Object { -not $_.Separator -and $_.Hotkey -eq $ch.ToLower() } | Select-Object -First 1
            if ($hit) { Set-WNCursor $true; return $hit.Value }
        }
    }
}

# Multi-select list.
# Items: objects with Label, Value, optional Detail (shown for the focused row), Tag + TagColor (right column), Checked.
# Actions: ordered hashtable of key char -> action name, e.g. [ordered]@{ U = 'Undo' }. Enter always returns 'Enter'.
# Returns @{ Action = <name>; Items = <selected values> } or $null when cancelled.
function Show-WNCheckList {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Items,
        [string]$Subtitle,
        [string]$EnterLabel = 'apply',
        [System.Collections.IDictionary]$Actions = @{},
        [switch]$SingleFocusAction
    )
    $all = @($Items | ForEach-Object {
        [pscustomobject]@{ Label = $_.Label; Value = $_.Value; Detail = $_.Detail; Tag = $_.Tag; TagColor = $_.TagColor; Group = $_.Group; Checked = [bool]$_.Checked }
    })
    if ($all.Count -eq 0) { Write-WNStatus 'Nothing to show.' Info; Wait-WNKey; return $null }

    if (-not $WN.Interactive) { return (Show-WNCheckListFallback -Title $Title -Subtitle $Subtitle -All $all -Actions $Actions -EnterLabel $EnterLabel) }

    $filter = ''
    $pos = 0
    $offset = 0
    $searching = $false
    Clear-WNKeyBuffer
    Set-WNCursor $false
    Write-WNHeader $Title $Subtitle
    $top = [Console]::CursorTop

    while ($true) {
        # @() around the whole if: a one-item result would otherwise unroll to a bare object, and
        # indexing a PSCustomObject ($view[0]) returns $null on Windows PowerShell
        $view = @(if ($filter) { $all | Where-Object { $_.Label -like "*$filter*" -or $_.Detail -like "*$filter*" -or $_.Group -like "*$filter*" } } else { $all })
        $size = Get-WNConsoleSize
        $width = $size.Width
        $rows = [Math]::Max(5, $size.Height - $top - 8)
        if ($pos -ge $view.Count) { $pos = [Math]::Max(0, $view.Count - 1) }
        if ($pos -lt $offset) { $offset = $pos }
        if ($pos -ge $offset + $rows) { $offset = $pos - $rows + 1 }

        [Console]::SetCursorPosition(0, $top)
        $checkedCount = @($all | Where-Object Checked).Count
        $searchText = if ($searching) { "/${filter}_" } elseif ($filter) { "filter: $filter" } else { '' }
        Write-WNSegments @(@("  $checkedCount selected", 'Cyan'), @("   $($view.Count) shown", 'DarkGray'), @("   $searchText", 'Yellow')) $width

        $tagWidth = 12
        $lastGroup = $null
        for ($r = 0; $r -lt $rows; $r++) {
            $i = $offset + $r
            if ($i -ge $view.Count) { Write-WNSegments @(, @('', $null)) $width; continue }
            $it = $view[$i]
            $box = if ($it.Checked) { '[x]' } else { '[ ]' }
            $labelWidth = [Math]::Max(10, $width - $tagWidth - 12)
            $label = $it.Label
            if ($label.Length -gt $labelWidth) { $label = $label.Substring(0, $labelWidth - 1) + '~' }
            $label = $label.PadRight($labelWidth)
            $tag = ([string]$it.Tag).PadLeft($tagWidth)
            $tagColor = if ($it.TagColor) { $it.TagColor } else { 'DarkGray' }
            if ($i -eq $pos) {
                # Status colours (green, cyan...) are unreadable on the highlight bar, so the tag goes white there
                Write-WNSegments @(@('  >', 'Cyan'), @(" $box ", 'White', 'DarkCyan'), @("$label ", 'White', 'DarkCyan'), @($tag, 'White', 'DarkCyan')) $width
            } else {
                $boxColor = if ($it.Checked) { 'Green' } else { 'DarkGray' }
                Write-WNSegments @(@('   ', $null), @(" $box ", $boxColor), @("$label ", 'Gray'), @($tag, $tagColor)) $width
            }
        }
        $more = if ($view.Count -gt $rows) { "  rows $($offset + 1)-$([Math]::Min($view.Count, $offset + $rows)) of $($view.Count)" } else { '' }
        Write-WNSegments @(, @($more, 'DarkGray')) $width
        $detail = if ($view.Count -gt 0) { $view[$pos].Detail } else { 'No matches. Press Esc to clear the filter.' }
        # Detail can be long: show up to two wrapped lines
        $d1 = ''; $d2 = ''
        if ($detail) {
            $max = $width - 5
            if ($detail.Length -le $max) { $d1 = $detail } else {
                $cut = $detail.LastIndexOf(' ', $max); if ($cut -lt 20) { $cut = $max }
                $d1 = $detail.Substring(0, $cut); $d2 = $detail.Substring($cut).Trim()
                if ($d2.Length -gt $max) { $d2 = $d2.Substring(0, $max - 1) + '~' }
            }
        }
        Write-WNSegments @(, @("  $d1", 'Gray')) $width
        Write-WNSegments @(, @("  $d2", 'Gray')) $width
        Write-WNSegments @(, @('', $null)) $width
        $extra = ($Actions.Keys | ForEach-Object { "$_ $($Actions[$_].ToLower())" }) -join '   '
        Write-WNSegments @(, @("  Space select   A all/none   / search   Enter $EnterLabel   $extra   Esc back", 'DarkGray')) $width

        $k = Read-WNKey

        # Note: 'continue' inside a PowerShell switch only leaves the switch, not the while loop,
        # so each switch sets $handled and the loop continues after it.
        if ($searching) {
            $handled = $true
            switch ($k.Key) {
                'Enter'     { $searching = $false }
                'Escape'    { $searching = $false; $filter = '' }
                'Backspace' { if ($filter.Length -gt 0) { $filter = $filter.Substring(0, $filter.Length - 1) }; $pos = 0 }
                'UpArrow'   { $searching = $false; $handled = $false }
                'DownArrow' { $searching = $false; $handled = $false }
                default     { if (-not [char]::IsControl($k.KeyChar)) { $filter += $k.KeyChar; $pos = 0 } }
            }
            if ($handled) { continue }
        }

        $handled = $true
        switch ($k.Key) {
            'UpArrow'   { if ($view.Count) { $pos = ($pos - 1 + $view.Count) % $view.Count } }
            'DownArrow' { if ($view.Count) { $pos = ($pos + 1) % $view.Count } }
            'PageUp'    { $pos = [Math]::Max(0, $pos - $rows) }
            'PageDown'  { $pos = [Math]::Max(0, [Math]::Min($view.Count - 1, $pos + $rows)) }
            'Home'      { $pos = 0 }
            'End'       { $pos = [Math]::Max(0, $view.Count - 1) }
            'Spacebar'  { if ($view.Count) { $view[$pos].Checked = -not $view[$pos].Checked; if ($pos -lt $view.Count - 1) { $pos++ } } }
            'Escape'    { if ($filter) { $filter = '' } else { Set-WNCursor $true; return $null } }
            'Enter' {
                $sel = @($all | Where-Object Checked)
                if ($sel.Count -eq 0 -and $view.Count -gt 0) { $sel = @($view[$pos]) }
                Set-WNCursor $true
                return @{ Action = 'Enter'; Items = @($sel | ForEach-Object Value) }
            }
            default { $handled = $false }
        }
        if ($handled) { continue }
        $ch = ([string]$k.KeyChar).ToUpper()
        if ($ch -eq '/') { $searching = $true; continue }
        if ($ch -eq 'A') {
            $target = @($view | Where-Object { -not $_.Checked }).Count -gt 0
            foreach ($v in $view) { $v.Checked = $target }
            continue
        }
        if ($ch -and $Actions.Contains($ch)) {
            $sel = @($all | Where-Object Checked)
            if ($sel.Count -eq 0 -and $view.Count -gt 0) { $sel = @($view[$pos]) }
            Set-WNCursor $true
            return @{ Action = $Actions[$ch]; Items = @($sel | ForEach-Object Value) }
        }
    }
}

function Show-WNCheckListFallback {
    param($Title, $Subtitle, $All, $Actions, $EnterLabel)
    Write-WNHeader $Title $Subtitle
    for ($i = 0; $i -lt $All.Count; $i++) {
        Write-Host ("  {0,3}) {1,-55} {2}" -f ($i + 1), $All[$i].Label, $All[$i].Tag)
    }
    $a = Read-Host '  Numbers (e.g. 1,3,5-7 or a = all, empty = back)'
    if ([string]::IsNullOrWhiteSpace($a)) { return $null }
    $idx = New-Object System.Collections.Generic.List[int]
    if ($a.Trim() -eq 'a') { 0..($All.Count - 1) | ForEach-Object { $idx.Add($_) } }
    else {
        foreach ($part in ($a -split '[,\s]+' | Where-Object { $_ })) {
            if ($part -match '^(\d+)-(\d+)$') { [int]$matches[1]..[int]$matches[2] | ForEach-Object { $idx.Add($_ - 1) } }
            elseif ($part -match '^\d+$') { $idx.Add([int]$part - 1) }
        }
    }
    $values = @($idx | Where-Object { $_ -ge 0 -and $_ -lt $All.Count } | Select-Object -Unique | ForEach-Object { $All[$_].Value })
    if ($values.Count -eq 0) { return $null }
    $action = 'Enter'
    if ($Actions.Count -gt 0) {
        $opts = (@("Enter=$EnterLabel") + ($Actions.Keys | ForEach-Object { "$_=$($Actions[$_])" })) -join ', '
        $c = Read-Host "  Action ($opts)"
        if ($c -and $Actions.Contains($c.Trim().ToUpper())) { $action = $Actions[$c.Trim().ToUpper()] }
    }
    return @{ Action = $action; Items = $values }
}

function Show-WNText {
    # Paged display of text lines (logs, lists)
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines)
    Write-WNHeader $Title
    if ($Lines.Count -eq 0) { Write-Host '  (empty)' -ForegroundColor DarkGray; Wait-WNKey; return }
    $pageSize = [Math]::Max(10, (Get-WNConsoleSize).Height - 10)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        Write-Host "  $($Lines[$i])"
        if ($WN.Interactive -and (($i + 1) % $pageSize -eq 0) -and ($i + 1 -lt $Lines.Count)) {
            Write-Host '  -- more: any key, Esc to stop --' -ForegroundColor DarkGray -NoNewline
            $k = Read-WNKey
            Write-Host ''
            if ($k.Key -eq 'Escape') { return }
        }
    }
    Wait-WNKey
}
