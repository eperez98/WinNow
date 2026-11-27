# gui/Experience.ps1
# Glassware palettes share the same surfaces and use separate accents for primary actions and text.
$glassware = @{
    Light = @{
        Bg = '#FFF0F2F7'; GlassBg = '#EEF0F2F7'; Card = '#EFFFFFFF'; CardBorder = '#260D274E'; Hover = '#FFF4F8FF'
        Layer = '#D9FAFAFC'; LayerBorder = '#2B6480A8'; Fg = '#FF152137'; FgDim = '#FF495970'
        AccentSolid = '#FF1556BF'; Accent = '#FF1556BF'; AccentText = '#FF174FAA'; Selected = '#262765CF'
    }
    Dark = @{
        Bg = '#FF111D2B'; GlassBg = '#EE111D2B'; Card = '#FF263447'; CardBorder = '#38BCCFEC'; Hover = '#FF34475F'
        Layer = '#E6192636'; LayerBorder = '#3BA2B9D9'; Fg = '#FFF4F7FC'; FgDim = '#FFBECCDF'
        AccentSolid = '#FF205DC0'; Accent = '#FF74ADFF'; AccentText = '#FFA8CDFF'; Selected = '#735383DD'
    }
    Navidad = @{
        Bg = '#FF101F1C'; GlassBg = '#EE101F1C'; Card = '#FF263B34'; CardBorder = '#4CD2CAAD'; Hover = '#FF354B41'
        Layer = '#E61C2D26'; LayerBorder = '#49ACBAA3'; Fg = '#FFFCF8EF'; FgDim = '#FFD7DDCD'
        AccentSolid = '#FFA62D46'; Accent = '#FFF0CC81'; AccentText = '#FFFFDF9F'; Selected = '#779A3E50'
    }
}
foreach ($name in $glassware.Keys) {
    foreach ($token in $glassware[$name].Keys) { $script:WNGuiThemes[$name][$token] = $glassware[$name][$token] }
    $script:WNGuiThemeSwatch[$name] = @($glassware[$name].Bg, $glassware[$name].AccentSolid)
}

# Colour blobs behind the glass and the surface of the open navigation pane
$script:WNGuiGlass = @{
    Dark    = @{ Blobs = @('#FF45638A'); NavBg = @('#EE2D425B@0', '#ED142236@1'); Popup = '#FF233147' }
    Light   = @{ Blobs = @('#FFACCBED'); NavBg = @('#F5EDF3FB@0', '#E2C9D9F2@1'); Popup = '#FFFBFAF8' }
    Navidad = @{ Blobs = @('#FF56765B'); NavBg = @('#EF31483D@0', '#F02C2023@1'); Popup = '#FF26362F' }
}

function Test-WNGuiLight { $script:WNGui.ThemeName -eq 'Light' }

function Update-WNGuiGlass {
    # The current theme's blobs and pane surface (called by Set-WNGuiTheme)
    $g = $script:WNGui
    $gl = $script:WNGuiGlass[$g.ThemeName]
    if (-not $gl) { return }
    $g.Window.Resources['NavBg'] = [Windows.Media.Brush](ConvertTo-WNBrush $gl.NavBg)
    $g.Window.Resources['Popup'] = [Windows.Media.Brush](ConvertTo-WNBrush $gl.Popup)
    $cv = $g.Window.FindName('Blobs')
    if (-not $cv) { return }
    $i = 0
    foreach ($e in $cv.Children) {
        $c = @($gl.Blobs)[$i++]
        if (-not $c) { $e.Visibility = 'Collapsed'; continue }
        $col = [Windows.Media.ColorConverter]::ConvertFromString($c)
        $rg = New-Object Windows.Media.RadialGradientBrush
        $rg.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.Color]::FromArgb(150, $col.R, $col.G, $col.B)), 0))
        $rg.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.Color]::FromArgb(0, $col.R, $col.G, $col.B)), 1))
        $e.Fill = $rg
        $e.Visibility = 'Visible'
    }
}

function Update-WNGuiTweakSelection {
    $g = $script:WNGui
    $selected = @($g.TweakList.Rows | Where-Object Selected)
    $g.TweakSelectionTitle.Text = T 'glassware.selected' $selected.Count
    $hidden = @($selected | Where-Object { -not $g.TweakList.View.Contains($_) }).Count
    $g.TweakHidden.Text = T 'glassware.hidden' $hidden
    $g.TweakHidden.Visibility = if ($hidden) { 'Visible' } else { 'Collapsed' }
    $g.TweakSelectionItems.Children.Clear()
    if (-not $selected.Count) {
        [void]$g.TweakSelectionItems.Children.Add((New-WNGuiText (T 'glassware.empty') -Dim -Wrap))
    }
    foreach ($row in $selected) {
        $item = New-Object Windows.Controls.DockPanel
        $item.Margin = '0,0,0,8'
        $remove = New-WNGuiButton (T 'glassware.remove') -Tag $row -Always -OnClick { $this.Tag.Selected = $false }
        $remove.ToolTip = T 'glassware.removeNamed' $row.Name
        [Windows.Automation.AutomationProperties]::SetName($remove, $remove.ToolTip)
        [Windows.Controls.DockPanel]::SetDock($remove, 'Right')
        [void]$item.Children.Add($remove)
        [void]$item.Children.Add((New-WNGuiText $row.Name -Wrap -Margin '0,0,6,0'))
        [void]$g.TweakSelectionItems.Children.Add($item)
    }
}

function Update-WNGuiGlasswareLayout {
    $g = $script:WNGui
    if (-not $g.Ctl.SidebarColumn) { return }
    $wide = $g.Window.ActualWidth -ge 1060
    Set-WNGuiNavExpanded ($wide -and -not $g.NavCompactPreferred)
    if (-not $g.TweakSide) { return }
    [Windows.Controls.DockPanel]::SetDock($g.TweakSide, $(if ($wide) { 'Right' } else { 'Bottom' }))
    $g.TweakSide.Width = if ($wide) { 250 } else { [double]::NaN }
    $g.TweakSide.Height = if ($wide) { [double]::NaN } else { 150 }
    $g.TweakSide.Margin = if ($wide) { '12,0,0,0' } else { '0,8,0,0' }
}

function Show-WNGuiChangeReview {
    param([string]$Message, [object[]]$Rows, [switch]$RestorePoint)
    $g = $script:WNGui
    $dialog = New-Object Windows.Window
    $dialog.Owner = $g.Window
    $dialog.WindowStartupLocation = 'CenterOwner'
    $dialog.SizeToContent = 'Height'
    $dialog.Width = 700
    $dialog.MaxHeight = [Windows.SystemParameters]::WorkArea.Height
    $dialog.ResizeMode = 'NoResize'
    $dialog.ShowInTaskbar = $false
    $dialog.Title = T 'glassware.review'
    $dialog.FontFamily = $g.Window.FontFamily
    $dialog.FontSize = $g.Window.FontSize
    $dialog.Resources.MergedDictionaries.Add($g.Window.Resources)
    $dialog.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'Popup')
    $dialog.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'Fg')
    $heading = New-WNGuiText $dialog.Title -Bold -Size 24
    $intro = New-WNGuiText $Message -Dim -Wrap -Margin '0,6,0,14'
    $items = New-Object Windows.Controls.ItemsControl
    $items.ItemTemplate = $g.Window.Resources['ReviewTableRow']
    $items.ItemsSource = $Rows
    $scroll = New-WNGuiScroll $items
    $scroll.MaxHeight = [Math]::Max(90, [Windows.SystemParameters]::WorkArea.Height - 450)
    $table = New-WNGuiTweakTable $scroll (T 'glassware.change')
    $restore = New-Object Windows.Controls.CheckBox
    $restore.Content = T 'glassware.restore'
    $restore.IsChecked = $true
    $restore.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'Fg')
    $restore.Margin = '0,10,0,0'
    $note = New-WNGuiText (T $(if ($WN.DryRun) { 'gui.noteSim' } else { 'gui.noteBackup' })) -Dim -Wrap -Margin '0,12,0,0'
    $cancel = New-WNGuiButton (T 'glassware.cancel') -Always
    $cancel.IsCancel = $true
    $action = T $(if ($WN.DryRun) { 'glassware.simulate' } else { 'glassware.applyCount' }) $Rows.Count
    $apply = New-WNGuiButton $action -Accent -Always -OnClick { [Windows.Window]::GetWindow($this).DialogResult = $true }
    $buttons = New-WNGuiPanel -Children @($cancel, $apply)
    $buttons.HorizontalAlignment = 'Right'
    $buttons.Margin = '0,18,0,0'
    $dialog.Content = New-WNGuiPanel -Orientation Vertical -Children @($heading, $intro, $table, $(if ($RestorePoint) { $restore }), $note, $buttons)
    $dialog.Content.Margin = '24'
    if ($dialog.ShowDialog() -ne $true) { return $false }
    $g.SkipRp = $RestorePoint -and -not $restore.IsChecked
    return $true
}

#region Navigation pane
function New-WNGuiNavItem {
    param([string]$Key, [string]$Glyph, [string]$Label, [switch]$Child, [switch]$Expandable)
    $g = $script:WNGui
    $r = New-Object Windows.Controls.RadioButton
    $r.Style = $g.Window.Resources['NavItem']
    $r.Tag = [string][char][Convert]::ToInt32($Glyph, 16)
    $r.Name = 'Nav_' + ($Key -replace '\W', '_')
    # Own group per item: Set-WNGuiNavSelection marks the page and, for a tool, its group too
    $r.GroupName = $r.Name
    $text = New-WNGuiText $Label -Size $(if ($Child) { 13 } else { 13.5 })
    $text.TextTrimming = 'CharacterEllipsis'
    if ($Expandable) {
        # The chevron opens the group's tools in the pane without leaving the page
        $chev = New-Object Windows.Controls.Button
        $chev.Style = $g.Window.Resources['NavChevron']
        $chev.Content = [string][char]0xE70D
        $chev.ToolTip = T 'nav.showTools'
        $chev.Tag = $r.Name
        [Windows.Automation.AutomationProperties]::SetName($chev, (T 'nav.showTools'))
        $chev.Add_Click({ param($s, $e) $e.Handled = $true; Switch-WNGuiNavGroup $this.Tag })
        $dock = New-Object Windows.Controls.DockPanel
        [Windows.Controls.DockPanel]::SetDock($chev, 'Right')
        [void]$dock.Children.Add($chev)
        [void]$dock.Children.Add($text)
        $r.Content = $dock
        $g.NavChevrons[$r.Name] = $chev
    } else {
        $r.Content = $text
    }
    if ($Child) { $r.Margin = '22,1,6,1'; $r.Height = 34 }
    $r.ToolTip = $Label
    [Windows.Automation.AutomationProperties]::SetName($r, $Label)
    return $r
}

function Switch-WNGuiNavGroup {
    # Progressive disclosure: a group shows its tools under it (the pane opens first if it is compact)
    param([string]$Name, [switch]$Open)
    $g = $script:WNGui
    $kids = $g.NavKids[$Name]
    if (-not $kids) { return }
    if (-not $g.NavExpanded) { Set-WNGuiNavExpanded $true }
    $show = if ($Open) { $true } else { $kids.Visibility -ne 'Visible' }
    $kids.Visibility = if ($show) { 'Visible' } else { 'Collapsed' }
    $chev = $g.NavChevrons[$Name]
    if ($chev) { $chev.Content = [string][char]$(if ($show) { 0xE70E } else { 0xE70D }) }
    if ($show) {
        $kids.Opacity = 0
        $kids.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-Object Windows.Media.Animation.DoubleAnimation 0, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds(220))))
    }
}

function Set-WNGuiNavSelection {
    # The page's item is marked, and for a tool its group as well, so the compact pane still shows where you are
    param([string]$Id)
    $g = $script:WNGui
    $on = @($g.NavButtons[$Id], $g.NavGroupOf[$Id]) | Where-Object { $_ }
    foreach ($b in $g.NavAll) { $b.IsChecked = [bool]($on | Where-Object { [object]::ReferenceEquals($_, $b) }) }
}

function Set-WNGuiNavWidth {
    # Compact: every item is just its 48 px icon column, so its rounded selection fits the pane; expanded: full width
    $g = $script:WNGui
    foreach ($panel in @($g.Ctl.NavPanel, $g.Ctl.NavFooter)) {
        foreach ($it in $panel.Children) { if ($it -is [Windows.Controls.RadioButton]) { $it.Width = if ($g.NavExpanded) { [double]::NaN } else { 48 }; $it.HorizontalAlignment = if ($g.NavExpanded) { 'Stretch' } else { 'Left' } } }
    }
}

function Set-WNGuiNavExpanded {
    param([bool]$On)
    $g = $script:WNGui
    $g.NavExpanded = $On
    $g.Ctl.SidebarColumn.Width = [Windows.GridLength]::new($(if ($On) { 204 } else { 72 }))
    $g.Ctl.SidebarBrand.Visibility = if ($On) { 'Visible' } else { 'Collapsed' }
    $g.Ctl.NavToggle.Width = if ($On) { 36 } else { 44 }
    $g.Ctl.NavToggle.HorizontalAlignment = if ($On) { 'Right' } else { 'Center' }
    Set-WNGuiNavWidth
    if (-not $On) {
        foreach ($k in $g.NavKids.Keys) {
            $g.NavKids[$k].Visibility = 'Collapsed'
            $g.NavChevrons[$k].Content = [string][char]0xE70D
        }
    }
}

function Build-WNGuiNav {
    # Home, one item per group of tools (each opens its tools as cards; expanded, it lists them), then What's new,
    # Support, Terminal mode and About at the foot
    $g = $script:WNGui
    $ctl = $g.Ctl
    $g.NavTargets = @{}; $g.NavKids = @{}; $g.NavChevrons = @{}; $g.NavGroupOf = @{}; $g.NavExpanded = $false
    $g.NavAll = New-Object 'System.Collections.Generic.List[object]'
    $go = {
        $g = $script:WNGui
        $t = $g.NavTargets[$this.Name]
        if ($t.Action) { $this.IsChecked = $false; & $t.Action; return }
        if ($t.Group -and $g.NavExpanded) { Switch-WNGuiNavGroup $this.Name -Open }
        if ($g.Current -ne $t.Page) { Show-WNGuiPage $t.Page }
    }
    $add = {
        param($Item, $Panel, [string]$Page, [scriptblock]$Action, [switch]$Group)
        $g.NavTargets[$Item.Name] = @{ Page = $Page; Action = $Action; Group = [bool]$Group }
        $Item.Add_Click($go)
        if ($Page) { $g.NavAll.Add($Item) }
        [void]$Panel.Children.Add($Item)
    }
    $homeItem = New-WNGuiNavItem 'home' 'E80F' (T 'gui.navHome')
    & $add $homeItem $ctl.NavPanel 'home'
    $g.NavButtons['home'] = $homeItem
    $primary = [ordered]@{ tweaks = 'glassware.adjustments'; apps = 'glassware.apps'; repair = 'glassware.repair' }
    foreach ($id in $primary.Keys) {
        $page = $g.Pages[$id]
        $item = New-WNGuiNavItem $id $page.Icon (T $primary[$id])
        & $add $item $ctl.NavPanel $id
        $g.NavButtons[$id] = $item
    }
    [void]$ctl.NavPanel.Children.Add((New-Object Windows.Controls.Separator -Property @{ Margin = '12,8,12,8'; Opacity = 0.28 }))
    $groupIcons = @{ 'main.secOptimize' = 'E713'; 'main.secApps' = 'E71D'; 'main.secMaintain' = 'E90F'; 'main.secNetwork' = 'E774'; 'main.secSystem' = 'E7F4'; 'main.secTool' = 'E8F1' }
    $sections = @($g.Pages.Values | Where-Object { $_.Section -and $_.Id -ne 'about' } | ForEach-Object { $_.Section } | Select-Object -Unique)
    foreach ($sec in $sections) {
        $members = @($g.Pages.Values | Where-Object { $_.Section -eq $sec -and $_.Id -ne 'about' })
        Register-WNGuiPage "grp:$sec" $groupIcons[$sec] $sec (T $sec) (T 'gui.groupSub' $members.Count) ${function:Build-WNGuiGroup}
        $g.Pages["grp:$sec"].Group = $true
        $grp = New-WNGuiNavItem "grp:$sec" $groupIcons[$sec] (T $sec) -Expandable
        & $add $grp $ctl.NavPanel "grp:$sec" -Group
        $g.NavButtons["grp:$sec"] = $grp
        $kids = New-Object Windows.Controls.StackPanel
        $kids.Visibility = 'Collapsed'
        foreach ($pg in $members | Where-Object { $_.Id -notin $primary.Keys }) {
            $it = New-WNGuiNavItem $pg.Id $pg.Icon $pg.Title -Child
            & $add $it $kids $pg.Id
            $g.NavButtons[$pg.Id] = $it
            $g.NavGroupOf[$pg.Id] = $grp
        }
        [void]$ctl.NavPanel.Children.Add($kids)
        $g.NavKids[$grp.Name] = $kids
    }
    $news = New-WNGuiNavItem 'news' 'E789' (T 'gui.railNews')
    & $add $news $ctl.NavFooter '' { Show-WNGuiNews -All }
    $don = New-WNGuiNavItem 'donate' 'EB51' (T 'gui.railDonate')
    $don.ToolTip = T 'about.donateTip'
    & $add $don $ctl.NavFooter '' { Start-Process $WN.Donate }
    # Terminal mode: the same tools in the console; this window closes
    $term = New-WNGuiNavItem 'terminal' 'E756' (T 'nav.terminal')
    $term.ToolTip = T 'nav.terminalTip'
    & $add $term $ctl.NavFooter '' { Switch-WNGuiToTerminal }
    $about = New-WNGuiNavItem 'about' 'E946' (T 'gui.railAbout')
    & $add $about $ctl.NavFooter 'about'
    $g.NavButtons['about'] = $about

    Set-WNGuiNavExpanded $true
    $ctl.NavToggle.ToolTip = T 'nav.toggle'
    [Windows.Automation.AutomationProperties]::SetName($ctl.NavToggle, (T 'nav.toggle'))
    $ctl.NavToggle.Add_Click({
        $g = $script:WNGui
        $g.NavCompactPreferred = $g.NavExpanded
        Set-WNGuiNavExpanded (-not $g.NavExpanded)
    })
    $g.Window.Add_SizeChanged({ if ($_.WidthChanged) { Update-WNGuiGlasswareLayout } })
}
#endregion

#region What's new slides
# Slides per version, in order. Each id has news.<id>.t / news.<id>.x in i18n.json and an optional picture,
# gui/news/<lang>/<id>.png. 'design' lets you pick a theme; 'end' (always last) asks how WinNow starts.
$script:WNNewsByVersion = [ordered]@{
    '1.7' = @('design', 'nav', 'start', 'profiles')
    '1.7.1' = @('winget')
    '1.7.2' = @('upgrade')
}

function Get-WNGuiNewsSlides {
    # The slides of every version after the last one seen (all of them for someone coming from 1.6), then 'end';
    # -All: every slide, for the menu
    param([switch]$All)
    $seen = (Get-WNSettings).NewsSeen
    $from = [version]'0.0'
    if ($seen -and -not $All) { try { $from = [version]$seen } catch { } }
    $list = foreach ($k in $script:WNNewsByVersion.Keys) { if ([version]$k -gt $from) { $script:WNNewsByVersion[$k] } }
    @($list) + 'end'
}

function Test-WNGuiNewsDue {
    # Once per version, for people who used an older one. A first start (no settings yet) skips it.
    $s = Get-WNSettings
    if ($s.NewsSeen -eq $WN.Version) { return $false }
    $old = [bool]@($s.PSObject.Properties | Where-Object { $_.Name -in 'Lang', 'Mode', 'GuiTheme', 'TourSeen', 'ShortcutAsked' }).Count
    if (-not $old) { Save-WNSetting 'NewsSeen' $WN.Version }
    return $old
}

function New-WNGuiNewsSlide {
    param([string]$Id, [double]$Width)
    $g = $script:WNGui
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Width = $Width
    # Pictures in the interface language, else English
    $pic = @("gui\news\$($WN.Lang)\$Id.png", "gui\news\en\$Id.png") | ForEach-Object { Join-Path $WN.Root $_ } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $frame = New-Object Windows.Controls.Border
    $frame.Height = 268
    $frame.CornerRadius = 12
    $frame.BorderThickness = 1
    $frame.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $frame.Margin = '28,0,28,0'
    if ($pic) {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit(); $bmp.CacheOption = 'OnLoad'; $bmp.UriSource = New-Object Uri $pic; $bmp.EndInit(); $bmp.Freeze()
        if ($Id -in 'start', 'end', 'exit', 'task') {
            # The launcher and the dialogs show whole, on the card surface
            $frame.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Card')
            $img = New-Object Windows.Controls.Image
            $img.Source = $bmp
            $img.Margin = '12'
            $frame.Child = $img
        } else {
            # Window shots fill the frame from the top
            $ib = New-Object Windows.Media.ImageBrush $bmp
            $ib.Stretch = 'UniformToFill'
            $ib.AlignmentY = 'Top'
            $frame.Background = $ib
        }
    } else {
        $frame.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Card')
        $frame.Child = New-WNGuiIcon 'E789' 64 -Accent
        $frame.Child.HorizontalAlignment = 'Center'
    }
    [void]$sp.Children.Add($frame)
    $title = New-WNGuiText (T "news.$Id.t") -Size 21 -Bold -Margin '28,18,28,0'
    $title.FontFamily = 'Segoe UI Variable Display, Segoe UI'
    [void]$sp.Children.Add($title)
    [void]$sp.Children.Add((New-WNGuiText (T "news.$Id.x") -Dim -Wrap -Size 13.5 -Margin '28,6,28,0'))
    if ($Id -eq 'design') {
        # Pick the new look right here
        $row = New-WNGuiPanel -Wrap
        $row.Margin = '24,12,24,0'
        $names = $script:WNGuiThemeNames
        foreach ($n in $names) {
            $b = New-Object Windows.Controls.Button
            $b.Style = $g.Window.Resources['PillBtn']
            $b.Margin = '4'
            $b.Padding = '12,6'
            $b.Tag = $n
            $c = $script:WNGuiThemeSwatch[$n]
            $sw = New-Object Windows.Shapes.Ellipse
            $sw.Width = 14; $sw.Height = 14; $sw.Margin = '0,0,8,0'
            $sw.Fill = [Windows.Media.Brush](ConvertTo-WNBrush @("$($c[0])@0", "$($c[0])@0.5", "$($c[1])@0.5", "$($c[1])@1") -Diagonal)
            $b.Content = New-WNGuiPanel -Children @($sw, (New-WNGuiText (T "gui.themeOpt$n") -Size 12.5))
            [Windows.Automation.AutomationProperties]::SetName($b, (T "gui.themeOpt$n"))
            $b.Add_Click({ Set-WNGuiTheme $this.Tag -Save })
            [void]$row.Children.Add($b)
        }
        [void]$sp.Children.Add($row)
    }
    if ($Id -eq 'end') {
        # How WinNow starts next time, and the start sound
        $s = Get-WNSettings
        $row = New-WNGuiPanel
        $row.Margin = '28,14,28,0'
        [void]$row.Children.Add((New-WNGuiText (T 'news.startIn') -Bold -Margin '0,0,12,0'))
        foreach ($m in 'gui', 'terminal') {
            $rb = New-Object Windows.Controls.RadioButton
            $rb.Style = $g.Window.Resources['Seg']
            $rb.GroupName = 'newsStart'
            $rb.Margin = '0,0,6,0'
            $rb.Content = T $(if ($m -eq 'gui') { 'news.startGui' } else { 'news.startTerm' })
            $rb.Tag = $m
            $rb.IsChecked = ($m -eq 'terminal') -eq ($s.Mode -eq 'terminal')
            $rb.Add_Checked({ Save-WNSetting 'Mode' $this.Tag })
            [void]$row.Children.Add($rb)
        }
        [void]$sp.Children.Add($row)
        $snd = New-Object Windows.Controls.CheckBox
        $snd.Content = T 'news.sound'
        $snd.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'Fg')
        $snd.Margin = '28,12,28,0'
        $snd.IsChecked = $s.Sound -ne $false
        $snd.Add_Click({ Save-WNSetting 'Sound' ([bool]$this.IsChecked) })
        [void]$sp.Children.Add($snd)
    }
    return $sp
}

function Show-WNGuiNewsSlide {
    # Slides move sideways: the strip glides to the chosen slide
    param([int]$Index)
    $n = $script:WNGui.News
    $count = $script:WNGui.News.List.Count
    $Index = [Math]::Max(0, [Math]::Min($count - 1, $Index))
    $n.Index = $Index
    $a = New-Object Windows.Media.Animation.DoubleAnimation (-$Index * $n.Width), ([Windows.Duration][TimeSpan]::FromMilliseconds(420))
    $a.EasingFunction = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseInOut' }
    $n.Shift.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $a)
    $i = 0
    foreach ($d in $n.Dots.Children) {
        $on = $i++ -eq $Index
        $d.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $(if ($on) { 'AccentSolid' } else { 'CardBorder' }))
        $d.Width = if ($on) { 22 } else { 8 }
    }
    $n.Back.Visibility = if ($Index -gt 0) { 'Visible' } else { 'Hidden' }
    $last = $Index -eq $count - 1
    $n.NextText.Text = if ($last) { T 'news.done' } else { T 'news.next' }
    $n.Step.Text = T 'news.step' ($Index + 1) $count
}

function Hide-WNGuiNews {
    $g = $script:WNGui
    if (-not $g.News) { return }
    Save-WNSetting 'NewsSeen' $WN.Version
    $out = New-Object Windows.Media.Animation.DoubleAnimation 0, ([Windows.Duration][TimeSpan]::FromMilliseconds(180))
    $out.Add_Completed({ $l = $script:WNGui.News; if ($l) { $script:WNGui.Window.FindName('Root').Children.Remove($l.Layer); $script:WNGui.News = $null } })
    $g.News.Layer.BeginAnimation([Windows.UIElement]::OpacityProperty, $out)
}

function Show-WNGuiNews {
    # What's new: a card over the window with slides that move sideways (Next / Back, arrow keys). At start it shows
    # the versions after the last one seen; -All (the menu) shows every slide.
    param([switch]$All)
    $g = $script:WNGui
    if ($g.News) { return }
    $slides = Get-WNGuiNewsSlides -All:$All
    $root = $g.Window.FindName('Root')
    $w = 760
    $layer = New-Object Windows.Controls.Grid
    $layer.Background = [Windows.Media.Brush](ConvertTo-WNBrush '#80000000')
    [Windows.Controls.Grid]::SetColumnSpan($layer, 2)
    [Windows.Controls.Panel]::SetZIndex($layer, 60)
    $card = New-Object Windows.Controls.Border
    $card.Width = $w
    $card.HorizontalAlignment = 'Center'; $card.VerticalAlignment = 'Center'
    $card.CornerRadius = 18
    $card.BorderThickness = 1
    $card.Padding = '0,20,0,18'
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Popup')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $card.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 40; ShadowDepth = 8; Opacity = 0.4; Direction = 270 }
    $grid = New-Object Windows.Controls.Grid
    foreach ($h in 'Auto', '*', 'Auto') { $rd = New-Object Windows.Controls.RowDefinition; $rd.Height = $h; $grid.RowDefinitions.Add($rd) }

    # Header: title and Skip
    $head = New-Object Windows.Controls.DockPanel
    $head.Margin = '28,0,20,14'
    $skip = New-WNGuiButton (T 'news.skip') -Always -OnClick { Hide-WNGuiNews }
    [Windows.Controls.DockPanel]::SetDock($skip, 'Right')
    [void]$head.Children.Add($skip)
    $ht = New-WNGuiText (T 'news.title' $WN.Version) -Size 15 -Bold
    [void]$head.Children.Add($ht)
    [void]$grid.Children.Add($head)

    # The strip of slides inside a clipped viewport
    $view = New-Object Windows.Controls.Border
    $view.ClipToBounds = $true
    $view.Height = 470
    [Windows.Controls.Grid]::SetRow($view, 1)
    $strip = New-Object Windows.Controls.StackPanel
    $strip.Orientation = 'Horizontal'
    $strip.HorizontalAlignment = 'Left'
    $shift = New-Object Windows.Media.TranslateTransform 0, 0
    $strip.RenderTransform = $shift
    foreach ($id in $slides) { [void]$strip.Children.Add((New-WNGuiNewsSlide $id $w)) }
    # A Canvas does not clip the strip to the first slide; the viewport clips what is outside
    $cv = New-Object Windows.Controls.Canvas
    [void]$cv.Children.Add($strip)
    $view.Child = $cv
    [void]$grid.Children.Add($view)

    # Footer: dots and step, Back / Next
    $foot = New-Object Windows.Controls.DockPanel
    $foot.Margin = '28,10,20,0'
    [Windows.Controls.Grid]::SetRow($foot, 2)
    $next = New-WNGuiButton (T 'news.next') -Accent -Always -OnClick {
        $n = $script:WNGui.News
        if ($n.Index -ge $script:WNGui.News.List.Count - 1) { Hide-WNGuiNews } else { Show-WNGuiNewsSlide ($n.Index + 1) }
    }
    $back = New-WNGuiButton (T 'news.back') -Always -OnClick { Show-WNGuiNewsSlide ($script:WNGui.News.Index - 1) }
    $back.Margin = '0,0,8,0'
    $btns = New-WNGuiPanel -Children @($back, $next)
    [Windows.Controls.DockPanel]::SetDock($btns, 'Right')
    [void]$foot.Children.Add($btns)
    $dots = New-WNGuiPanel
    $dots.VerticalAlignment = 'Center'
    foreach ($id in $slides) {
        $d = New-Object Windows.Shapes.Rectangle
        $d.Height = 8; $d.Width = 8; $d.RadiusX = 4; $d.RadiusY = 4; $d.Margin = '0,0,6,0'
        [void]$dots.Children.Add($d)
    }
    $step = New-WNGuiText '' -Dim -Size 12 -Margin '8,0,0,0'
    [void]$foot.Children.Add((New-WNGuiPanel -Children @($dots, $step)))
    [void]$grid.Children.Add($foot)
    $card.Child = $grid
    [void]$layer.Children.Add($card)
    $layer.Add_KeyDown({
        param($s, $e)
        $n = $script:WNGui.News
        switch ($e.Key) {
            'Right' { Show-WNGuiNewsSlide ($n.Index + 1); $e.Handled = $true }
            'Left' { Show-WNGuiNewsSlide ($n.Index - 1); $e.Handled = $true }
            'Escape' { Hide-WNGuiNews; $e.Handled = $true }
        }
    })
    [void]$root.Children.Add($layer)
    $g.News = @{ Layer = $layer; Shift = $shift; Dots = $dots; Back = $back; NextText = $next.Content.Children[0]; Step = $step; Width = $w; Index = 0; List = $slides }
    Show-WNGuiNewsSlide 0
    $layer.Opacity = 0
    $layer.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-Object Windows.Media.Animation.DoubleAnimation 0, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds(260))))
    $sc = New-Object Windows.Media.ScaleTransform 0.96, 0.96
    $card.RenderTransformOrigin = '0.5,0.5'
    $card.RenderTransform = $sc
    $ga = New-Object Windows.Media.Animation.DoubleAnimation 0.96, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds(320))
    $ga.EasingFunction = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
    $sc.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $ga)
    $sc.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $ga)
    [void]$next.Focus()
}
#endregion
