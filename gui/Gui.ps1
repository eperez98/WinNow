# gui/Gui.ps1
# Graphical interface (release candidate) with every module of the terminal edition: a translucent,
# flat layout in light and dark (acrylic backdrop on Windows 11, iOS-style cards), with a sidebar,
# a search bar and, on the home page, a banner and a tile for each tool.
# Changes run in a background runspace that loads core/ and modules/ like the terminal does, so
# restore points, backups, undo and simulation mode behave exactly the same. Quick read-only
# queries (registry, files) run on the UI thread; anything slow (CIM, winget, appx) in the worker.

$script:WNGuiTypes = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public class WNRow : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    void Notify(string p) { var h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(p)); }
    bool selected; string badge; object badgeBg, badgeFg;
    public string Key { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public string Group { get; set; }
    public string State { get; set; }
    public string Kind { get; set; }
    public object Item { get; set; }
    public bool Selected { get { return selected; } set { selected = value; Notify("Selected"); } }
    public string Badge { get { return badge; } set { badge = value; Notify("Badge"); Notify("BadgeVisibility"); } }
    public object BadgeBg { get { return badgeBg; } set { badgeBg = value; Notify("BadgeBg"); } }
    public object BadgeFg { get { return badgeFg; } set { badgeFg = value; Notify("BadgeFg"); } }
    public string BadgeVisibility { get { return String.IsNullOrEmpty(badge) ? "Collapsed" : "Visible"; } }
}

public static class WNDwm {
    [StructLayout(LayoutKind.Sequential)]
    struct Margins { public int Left, Right, Top, Bottom; }
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    [DllImport("dwmapi.dll")] static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref Margins m);
    // 20 = DWMWA_USE_IMMERSIVE_DARK_MODE: title bar and backdrop tint follow the theme
    public static void SetDark(IntPtr hwnd, bool dark) { int d = dark ? 1 : 0; DwmSetWindowAttribute(hwnd, 20, ref d, 4); }
    // 38 = DWMWA_SYSTEMBACKDROP_TYPE, 3 = acrylic: the translucent, blurred Windows 11 backdrop
    public static bool Acrylic(IntPtr hwnd) {
        var m = new Margins { Left = -1, Right = -1, Top = -1, Bottom = -1 };
        if (DwmExtendFrameIntoClientArea(hwnd, ref m) != 0) return false;
        int b = 3;
        return DwmSetWindowAttribute(hwnd, 38, ref b, 4) == 0;
    }
}
'@

# Brush specs: '#AARRGGBB' is a solid colour; an array is a vertical gradient ('#color@offset' for hard stops).
# Bg is used without the acrylic backdrop (Windows 10, older 11); GlassBg tints the backdrop when it is on.
$script:WNGuiThemes = @{
    Dark  = @{
        Bg = '#FF1C1C1E'; GlassBg = '#80141416'; Pane = '#33000000'; Card = '#1FFFFFFF'; CardBorder = '#26FFFFFF'; Hover = '#30FFFFFF'
        Selected = '#330A84FF'; Fg = '#FFFFFFFF'; FgDim = '#FFC7C7CC'; Accent = '#FF0A84FF'; AccentSolid = '#FF0A84FF'; AccentFg = '#FFFFFFFF'; AccentText = '#FF64B5FF'
        Warn = '#FFFFB340'; WarnBg = '#33FF9F0A'
        Badges = @{ Applied = '#3330D158|#FF7EE2A0'; Partial = '#33FF9F0A|#FFFFD285'; Action = '#330A84FF|#FF9CCBFF'; None = '#26FFFFFF|#FFE5E5EA'; Danger = '#33FF453A|#FFFF9F98' }
    }
    Light = @{
        Bg = '#FFF2F2F7'; GlassBg = '#99F2F2F7'; Pane = '#59FFFFFF'; Card = '#B3FFFFFF'; CardBorder = '#1A000000'; Hover = '#E6FFFFFF'
        Selected = '#1F007AFF'; Fg = '#FF1C1C1E'; FgDim = '#FF5C5C61'; Accent = '#FF0071E3'; AccentSolid = '#FF0071E3'; AccentFg = '#FFFFFFFF'; AccentText = '#FF0060C7'
        Warn = '#FF8F5300'; WarnBg = '#26FF9500'
        Badges = @{ Applied = '#2634C759|#FF1B7A36'; Partial = '#26FF9500|#FF8F5300'; Action = '#1F007AFF|#FF0058B8'; None = '#14000000|#FF3A3A3C'; Danger = '#26FF3B30|#FFB3261E' }
    }
}
# Tool icon colours per sidebar group (diagonal gradients, like app icons)
$script:WNGuiArt = @{
    'main.secOptimize' = @('#FFFF9F0A', '#FFFF6B00')
    'main.secApps'     = @('#FFBF5AF2', '#FF7D3CE0')
    'main.secMaintain' = @('#FF30D158', '#FF14A34A')
    'main.secNetwork'  = @('#FF40A9FF', '#FF0A6CFF')
    'main.secSystem'   = @('#FF98989D', '#FF636366')
}

#region Helpers
function ConvertTo-WNBrush {
    param($Spec, [switch]$Diagonal)
    if ($Spec -is [string]) { return (New-Object Windows.Media.BrushConverter).ConvertFromString($Spec) }
    $b = New-Object Windows.Media.LinearGradientBrush
    $b.StartPoint = '0,0'
    $b.EndPoint = if ($Diagonal) { '1,1' } else { '0,1' }
    $n = @($Spec).Count
    for ($i = 0; $i -lt $n; $i++) {
        $color, $offset = $Spec[$i] -split '@'
        if (-not $offset) { $offset = if ($n -gt 1) { $i / ($n - 1) } else { 0 } }
        $b.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.ColorConverter]::ConvertFromString($color)), ([double]$offset)))
    }
    return $b
}

function Set-WNGuiBadge {
    param([Parameter(Mandatory)]$Row, [string]$Text, [string]$Kind = 'None')
    $bg, $fg = $script:WNGui.Theme.Badges[$Kind] -split '\|'
    $Row.Kind = $Kind
    $Row.Badge = $Text
    # Casts unwrap the PSObject that New-Object returns; WPF needs the Brush itself in object slots
    $Row.BadgeBg = [Windows.Media.Brush](ConvertTo-WNBrush $bg)
    $Row.BadgeFg = [Windows.Media.Brush](ConvertTo-WNBrush $fg)
}

function Add-WNGuiLog {
    param([string]$Line)
    $g = $script:WNGui
    $g.Log.AppendText("$Line`r`n")
    $g.Log.ScrollToEnd()
    if ($Line.Trim()) { $g.Status.Text = $Line.Trim() }
}

function Set-WNGuiBusy {
    param([bool]$On, [string]$Label)
    $g = $script:WNGui
    $g.Busy.Visibility = if ($On) { 'Visible' } else { 'Collapsed' }
    foreach ($b in $g.ActionButtons) { $b.IsEnabled = -not $On }
    $g.SimToggle.IsEnabled = (-not $On) -and $WN.IsAdmin
    $g.Status.Text = if ($On) { T 'gui.busy' $Label } else { T 'gui.ready' }
}

function Start-WNGuiJob {
    # Runs $Script in the worker runspace. Write-Host output streams into the log; $OnDone gets the output.
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Script, [object[]]$Arguments = @(), [scriptblock]$OnDone)
    $g = $script:WNGui
    # Page loads can be requested while another job runs (action buttons are disabled meanwhile): queue them
    if ($g.Job) { $g.Queue.Add(@{ Label = $Label; Script = $Script; Arguments = $Arguments; OnDone = $OnDone }); return }
    $ps = [powershell]::Create()
    $ps.Runspace = $g.Runspace
    [void]$ps.AddScript($Script)
    foreach ($a in $Arguments) { [void]$ps.AddArgument($a) }
    Add-WNGuiLog "---- $Label"
    $g.Job = @{ PS = $ps; Handle = $ps.BeginInvoke(); Label = $Label; OnDone = $OnDone; Read = 0; Line = '' }
    Set-WNGuiBusy $true $Label
    $g.Timer.Start()
}

function Receive-WNGuiJob {
    # Timer tick: copy new Write-Host records to the log, then finish the job when it completes
    $g = $script:WNGui
    $job = $g.Job
    if (-not $job) { $g.Timer.Stop(); return }
    $info = $job.PS.Streams.Information
    while ($job.Read -lt $info.Count) {
        $m = $info[$job.Read].MessageData
        $job.Read++
        if ($m -is [System.Management.Automation.HostInformationMessage]) {
            $job.Line += $m.Message
            if ($m.NoNewLine) { continue }
        } else { $job.Line += "$m" }
        Add-WNGuiLog $job.Line
        $job.Line = ''
    }
    if (-not $job.Handle.IsCompleted) { return }
    $g.Timer.Stop()
    $out = $null
    try { $out = $job.PS.EndInvoke($job.Handle) } catch { Add-WNGuiLog "ERROR: $($_.Exception.Message)" }
    foreach ($e in $job.PS.Streams.Error) { Add-WNGuiLog "ERROR: $e" }
    $job.PS.Dispose()
    $g.Job = $null
    Set-WNGuiBusy $false
    if ($job.OnDone) {
        try { & $job.OnDone @($out) } catch { Add-WNGuiLog "ERROR: $($_.Exception.Message)" }
    }
    if (-not $g.Job -and $g.Queue.Count) {
        $next = $g.Queue[0]
        $g.Queue.RemoveAt(0)
        Start-WNGuiJob @next
    }
}

function New-WNGuiWorker {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript({
        param($root, $dry, $lang, $noRp)
        foreach ($f in @(Get-ChildItem "$root\core\*.ps1") + @(Get-ChildItem "$root\modules\*.ps1")) { . $f.FullName }
        # -Yes: the window already asked; no console prompt can be answered from here
        Initialize-WNContext -Root $root -DryRun:$dry -Yes -NoRestorePoint:$noRp
        Import-WNConfig
        Set-WNLanguage $lang
        $WN.Interactive = $false
        $WN.Gui = $true
    }.ToString()).AddArgument($WN.Root).AddArgument($WN.DryRun).AddArgument($WN.Lang).AddArgument($WN.NoRestorePoint)
    [void]$ps.Invoke()
    foreach ($e in $ps.Streams.Error) { Write-WNLog "GUI worker init: $e" -Level ERROR -Component 'Gui' }
    $ps.Dispose()
    return $rs
}

function Confirm-WNGui {
    param([string]$Message, [switch]$Danger)
    $note = if ($WN.DryRun) { T 'gui.noteSim' } else { T 'gui.noteReal' }
    $icon = if ($Danger) { 'Warning' } else { 'Question' }
    $r = [Windows.MessageBox]::Show($script:WNGui.Window, "$Message`n`n$note", 'Winnow', 'YesNo', $icon, 'No')
    return ($r -eq 'Yes')
}

function Show-WNGuiInfo { param([string]$Message) [void][Windows.MessageBox]::Show($script:WNGui.Window, $Message, 'Winnow') }

function Get-WNGuiSelected {
    param($Rows)
    $sel = @($Rows | Where-Object Selected)
    if (-not $sel.Count) { Show-WNGuiInfo (T 'gui.noneSelected') }
    return $sel
}

function Update-WNGuiFilter {
    # One search box for every page: filters the current page's list by text, plus the page's own
    # level (Tweaks) or badge (installed apps) filter
    $g = $script:WNGui
    $p = $g.Pages[$g.Current]
    if (-not $p -or -not $p.List) { return }
    $q = $g.Ctl.SearchBox.Text.Trim()
    $lvl = $p.Level
    $badge = $p.OnlyBadge
    $p.List.View.Filter = if ($q -or $lvl -or $badge) {
        [Predicate[object]] { param($r)
            (-not $lvl -or $r.Item.Level -eq $lvl) -and (-not $badge -or $r.Badge -eq $badge) -and
            (-not $q -or ("$($r.Name) $($r.Description)").IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0) }.GetNewClosure()
    } else { $null }
    if ($p.OnFilter) { & $p.OnFilter $p }
}
#endregion

#region Element builders
function New-WNGuiText {
    param([string]$Text, [string]$Style, [switch]$Dim, [double]$Size, [string]$Margin, [switch]$Bold, [switch]$Wrap, [switch]$Accent)
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $Text
    if ($Style) { $t.Style = $script:WNGui.Window.Resources[$Style] }
    if ($Dim) { $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'FgDim') }
    if ($Accent) { $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'AccentText') }
    if ($Size) { $t.FontSize = $Size }
    if ($Margin) { $t.Margin = $Margin }
    if ($Bold) { $t.FontWeight = 'SemiBold' }
    if ($Wrap) { $t.TextWrapping = 'Wrap' }
    $t.VerticalAlignment = 'Center'
    return $t
}

function New-WNGuiIcon {
    param([string]$Glyph, [double]$Size = 16, [switch]$Accent)
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = [string][char][Convert]::ToInt32($Glyph, 16)
    $t.FontFamily = $script:WNGui.Window.Resources['Icons']
    $t.FontSize = $Size
    $t.VerticalAlignment = 'Center'
    if ($Accent) { $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'AccentText') }
    return $t
}

function New-WNGuiButton {
    # Action buttons are disabled while a job runs (unless -Always)
    param([string]$Text, [string]$Icon, [switch]$Accent, $Tag, [scriptblock]$OnClick, [switch]$Always)
    $b = New-Object Windows.Controls.Button
    $b.Style = $script:WNGui.Window.Resources[$(if ($Accent) { 'AccentBtn' } else { 'Btn' })]
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    if ($Icon) { $i = New-WNGuiIcon $Icon 14; $i.Margin = '0,0,8,0'; [void]$sp.Children.Add($i) }
    [void]$sp.Children.Add((New-WNGuiText $Text))
    $b.Content = $sp
    $b.Tag = $Tag
    [Windows.Automation.AutomationProperties]::SetName($b, $Text)
    if ($OnClick) { $b.Add_Click($OnClick) }
    if (-not $Always) { $script:WNGui.ActionButtons.Add($b) }
    return $b
}

function New-WNGuiPanel {
    param([string]$Orientation = 'Horizontal', [object[]]$Children = @(), [switch]$Wrap)
    $p = if ($Wrap) { New-Object Windows.Controls.WrapPanel } else { New-Object Windows.Controls.StackPanel }
    $p.Orientation = $Orientation
    foreach ($c in $Children) { if ($c) { [void]$p.Children.Add($c) } }
    return $p
}

function New-WNGuiGlass {
    param($Content, [double]$Width)
    $c = New-Object Windows.Controls.ContentControl
    $c.Style = $script:WNGui.Window.Resources['Glass']
    $c.Content = $Content
    $c.Focusable = $false
    if ($Width) { $c.Width = $Width; $c.Margin = '0,0,10,10' }
    return $c
}

function New-WNGuiCard {
    # Panel: icon, title, description, optional extra content and buttons on the right
    param([string]$Title, [string]$Text, [string]$Icon, [object[]]$Buttons = @(), $Extra, [double]$Width)
    $dock = New-Object Windows.Controls.DockPanel
    if ($Buttons.Count) {
        $right = New-WNGuiPanel -Children $Buttons
        $right.VerticalAlignment = 'Center'
        $right.Margin = '12,0,0,0'
        [Windows.Controls.DockPanel]::SetDock($right, 'Right')
        [void]$dock.Children.Add($right)
    }
    if ($Icon) {
        $i = New-WNGuiIcon $Icon 22 -Accent
        $i.Margin = '0,0,16,0'
        [Windows.Controls.DockPanel]::SetDock($i, 'Left')
        [void]$dock.Children.Add($i)
    }
    $body = New-WNGuiPanel -Orientation Vertical -Children @(
        $(if ($Title) { New-WNGuiText $Title -Bold -Wrap }),
        $(if ($Text) { New-WNGuiText $Text -Dim -Size 12.5 -Wrap -Margin '0,2,0,0' }),
        $Extra)
    $body.VerticalAlignment = 'Center'
    [void]$dock.Children.Add($body)
    return (New-WNGuiGlass $dock -Width $Width)
}

function New-WNGuiScroll {
    param($Content)
    $s = New-Object Windows.Controls.ScrollViewer
    $s.VerticalScrollBarVisibility = 'Auto'
    $s.Padding = '0,0,8,0'
    $s.Content = $Content
    return $s
}

function New-WNGuiList {
    # Check list bound to WNRow objects; returns @{ List; Rows; View }
    param([switch]$Grouped)
    $l = New-Object Windows.Controls.ListBox
    $l.Style = $script:WNGui.Window.Resources['List']
    $rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    $view = [Windows.Data.CollectionViewSource]::GetDefaultView($rows)
    if ($Grouped) {
        $view.GroupDescriptions.Add((New-Object Windows.Data.PropertyGroupDescription 'Group'))
        $gs = New-Object Windows.Controls.GroupStyle
        $gs.HeaderTemplate = [Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><TextBlock Text="{Binding Name}" FontSize="15" FontWeight="SemiBold" Margin="2,12,0,8"/></DataTemplate>')
        $l.GroupStyle.Add($gs)
    }
    $l.ItemsSource = $view
    $list = @{ List = $l; Rows = $rows; View = $view }
    # Kept so a theme switch can recolour every badge
    $script:WNGui.Lists.Add($list)
    return $list
}

function Set-WNGuiRows {
    # Replaces the rows of a list from @{ Key; Name; Description; Group; Item } hashtables
    param($List, [object[]]$Items)
    $List.Rows.Clear()
    foreach ($i in $Items) { $List.Rows.Add((New-Object WNRow -Property $i)) }
}

function New-WNGuiSegments {
    # Pill tabs; $OnChange gets the selected value through $this.Tag
    param([string]$Group, [object[]]$Options, [scriptblock]$OnChange)
    $p = New-WNGuiPanel
    $p.Margin = '0,0,12,0'
    $first = $true
    foreach ($o in $Options) {
        $r = New-Object Windows.Controls.RadioButton
        $r.Style = $script:WNGui.Window.Resources['Seg']
        $r.GroupName = $Group
        $r.Content = $o.Text
        $r.Tag = $o.Value
        $r.IsChecked = $first
        $first = $false
        $r.Add_Checked($OnChange)
        [void]$p.Children.Add($r)
    }
    return $p
}

function New-WNGuiImage {
    param([string]$File, [double]$Size, [double]$Opacity = 1)
    $path = Join-Path $WN.Root "LOGO\$File"
    if (-not (Test-Path $path)) { return $null }
    $i = New-Object Windows.Controls.Image
    $i.Source = New-Object Windows.Media.Imaging.BitmapImage (New-Object Uri $path)
    $i.Width = $Size; $i.Height = $Size
    $i.Opacity = $Opacity
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($i, 'HighQuality')
    return $i
}
#endregion

#region Pages
# Each page: @{ Id; Icon; Section; Title; Sub; Build } -> Build fills Actions / Toolbar / Body and may set
# List (searched by the top bar), OnSearch (Enter in the search box), OnShow and OnFilter
function Register-WNGuiPage {
    param([string]$Id, [string]$Icon, [string]$Section, [string]$Title, [string]$Sub, [scriptblock]$Build, [string]$Hint)
    $script:WNGui.Pages[$Id] = @{ Id = $Id; Icon = $Icon; Section = $Section; Title = $Title; Sub = $Sub; Hint = $Hint; Build = $Build; Built = $false; Shown = 0 }
}

function Show-WNGuiPage {
    param([string]$Id)
    $g = $script:WNGui
    $p = $g.Pages[$Id]
    if (-not $p.Built) {
        $p.Actions = New-WNGuiPanel
        $p.Toolbar = New-WNGuiPanel -Wrap
        & $p.Build $p
        $p.Built = $true
    }
    $g.Ctl.PageTitle.Text = $p.Title
    $g.Ctl.PageSub.Text = $p.Sub
    $g.Ctl.Header.Visibility = if ($p.NoHeader) { 'Collapsed' } else { 'Visible' }
    $g.Ctl.ActionsHost.Content = $p.Actions
    $g.Ctl.ToolbarHost.Content = $p.Toolbar
    $g.Ctl.ToolbarHost.Visibility = if ($p.Toolbar.Children.Count) { 'Visible' } else { 'Collapsed' }
    $g.Ctl.BodyHost.Content = $p.Body
    $g.Current = $Id
    # The search box follows the page: cleared, with a page-specific hint, off where there is nothing to search
    $box = $g.Ctl.SearchBox
    $box.Text = ''
    $box.Tag = if ($p.SearchHint) { $p.SearchHint } elseif ($p.List) { T 'gui.search' } else { T 'gui.searchOff' }
    $box.IsEnabled = [bool]($p.List -or $p.OnSearch)
    if ($g.NavButtons[$Id].IsChecked -ne $true) { $g.NavButtons[$Id].IsChecked = $true }
    $p.Shown++
    if ($p.OnShow) { & $p.OnShow $p }
}

function Add-WNGuiActions { param($Page, [object[]]$Buttons) foreach ($b in $Buttons) { [void]$Page.Actions.Children.Add($b) } }
function Add-WNGuiTools { param($Page, [object[]]$Items) foreach ($i in $Items) { [void]$Page.Toolbar.Children.Add($i) } }

# ---- Tweak states (Tweaks and Preferences share them)
function Update-WNGuiTweakStates {
    Start-WNGuiJob -Label (T 'gui.readingStates') -Script {
        $s = @{}
        foreach ($t in $WN.Config.tweaks) { $s[$t.Key] = Get-WNTweakState $t }
        $s
    }.ToString() -OnDone {
        param($out)
        $states = $out[0]
        $g = $script:WNGui
        foreach ($r in $g.TweakList.Rows) {
            $r.State = $states[$r.Key]
            $kind, $key = switch ($r.State) { 'Applied' { 'Applied', 'gui.stApplied' } 'Partial' { 'Partial', 'gui.stPartial' } 'Action' { 'Action', 'gui.stAction' } 'NotApplied' { 'None', 'gui.stNot' } default { 'None', 'gui.stUnknown' } }
            Set-WNGuiBadge $r (T $key) $kind
        }
        foreach ($r in $g.PrefList.Rows) {
            $r.State = $states[$r.Key]
            if ($r.State -eq 'Applied') { Set-WNGuiBadge $r (T 'gui.on') 'Applied' } elseif ($r.State -eq 'Partial') { Set-WNGuiBadge $r (T 'gui.mixed') 'Partial' } else { Set-WNGuiBadge $r (T 'gui.off') 'None' }
        }
    }
}

function Invoke-WNGuiTweaks {
    # $Undo: undo the selected keys; $Flip: preferences, turn each selected switch to the other state
    param([string[]]$Keys, [switch]$Undo, [switch]$Flip, [string]$Label)
    Start-WNGuiJob -Label $Label -Arguments @($WN.DryRun, $Keys, [bool]$Undo, [bool]$Flip) -Script {
        param($dry, $keys, $undo, $flip)
        $WN.DryRun = $dry
        $tweaks = @($keys | ForEach-Object { Get-WNTweak $_ })
        if ($flip) {
            $on = @($tweaks | Where-Object { (Get-WNTweakState $_) -ne 'Applied' })
            $off = @($tweaks | Where-Object { (Get-WNTweakState $_) -eq 'Applied' })
            if ($on.Count) { Invoke-WNTweakBatch -Tweaks $on }
            if ($off.Count) { Invoke-WNTweakBatch -Tweaks $off -Undo }
        } else {
            Invoke-WNTweakBatch -Tweaks $tweaks -Undo:$undo
        }
    }.ToString() -OnDone {
        foreach ($l in $script:WNGui.TweakList, $script:WNGui.PrefList) { foreach ($r in $l.Rows) { $r.Selected = $false } }
        Update-WNGuiTweakStates
    }
}

function Set-WNGuiTweakLevel {
    # Recommended / Advanced / All tab: list filter plus the matching explanation card
    param([string]$Level)
    $g = $script:WNGui
    $p = $g.Pages['tweaks']
    $p.Level = if ($Level -eq 'All') { $null } else { $Level }
    $g.TweakNote.Visibility = if ($p.Level) { 'Visible' } else { 'Collapsed' }
    if ($p.Level) {
        $adv = $p.Level -eq 'Advanced'
        $g.TweakNoteIcon.Text = [string][char]$(if ($adv) { 0xE7BA } else { 0xE73E })
        $g.TweakNoteTitle.Text = T $(if ($adv) { 'gui.advInfoTitle' } else { 'gui.recInfoTitle' })
        $g.TweakNoteText.Text = T $(if ($adv) { 'gui.advInfo' } else { 'gui.recInfo' })
    }
    Update-WNGuiFilter
}

function Build-WNGuiTweaks {
    param($p)
    $g = $script:WNGui
    $list = New-WNGuiList -Grouped
    $order = 'Essential', 'Privacy', 'Performance', 'Interface', 'Bloatware', 'Advanced'
    Set-WNGuiRows $list @($WN.Config.tweaks | Where-Object Type -ne 'Toggle' | Sort-Object { [array]::IndexOf($order, $_.Category) }, Name | ForEach-Object {
        $risk = if ($_.Risk -ne 'Low') { (T 'gui.risk' (T "risk.$($_.Risk)")) + '  -  ' } else { '' }
        @{ Key = $_.Key; Name = $_.Name; Description = "$risk$($_.Description)"; Group = (T "cat.$($_.Category)"); Item = $_ } })
    $g.TweakList = $list
    $p.List = $list

    # Explanation card above the list: gentle changes vs. changes that need care
    $g.TweakNoteIcon = New-WNGuiIcon 'E73E' 20 -Accent
    $g.TweakNoteIcon.Margin = '0,0,14,0'
    $g.TweakNoteIcon.VerticalAlignment = 'Top'
    $g.TweakNoteTitle = New-WNGuiText '' -Bold
    $g.TweakNoteText = New-WNGuiText '' -Dim -Size 12.5 -Wrap -Margin '0,2,0,0'
    $g.TweakNote = New-WNGuiGlass (New-WNGuiPanel -Children @($g.TweakNoteIcon, (New-WNGuiPanel -Orientation Vertical -Children @($g.TweakNoteTitle, $g.TweakNoteText))))
    $g.TweakNoteText.MaxWidth = 900
    $dock = New-Object Windows.Controls.DockPanel
    [Windows.Controls.DockPanel]::SetDock($g.TweakNote, 'Top')
    [void]$dock.Children.Add($g.TweakNote)
    [void]$dock.Children.Add($list.List)
    $p.Body = $dock

    $all = @($WN.Config.tweaks | Where-Object Type -ne 'Toggle')
    $preset = {
        $keys = @($WN.Config.presets.($this.Tag).Tweaks)
        foreach ($r in $script:WNGui.TweakList.Rows) { $r.Selected = $keys -contains $r.Key }
    }
    $g.TweakSegs = New-WNGuiSegments 'tweakLevel' @(
        @{ Text = (T 'gui.levelRec' @($all | Where-Object Level -eq 'Recommended').Count); Value = 'Recommended' },
        @{ Text = (T 'gui.levelAdv' @($all | Where-Object Level -eq 'Advanced').Count); Value = 'Advanced' },
        @{ Text = (T 'gui.levelAll' $all.Count); Value = 'All' }) { Set-WNGuiTweakLevel $this.Tag }
    Add-WNGuiTools $p @(
        $g.TweakSegs,
        (New-WNGuiText (T 'gui.preset') -Dim -Margin '4,0,8,0'),
        (New-WNGuiButton (T 'preset.Minimal') -Tag 'Minimal' -OnClick $preset),
        (New-WNGuiButton (T 'preset.Standard') -Tag 'Standard' -OnClick $preset),
        (New-WNGuiButton (T 'preset.Heavy') -Tag 'Heavy' -OnClick $preset),
        (New-WNGuiButton (T 'gui.markApplied') -Icon 'E81C' -OnClick {
            foreach ($r in $script:WNGui.TweakList.Rows) { $r.Selected = $r.Item.Type -eq 'Tweak' -and $r.State -in 'Applied', 'Partial' }
        }),
        (New-WNGuiButton (T 'gui.clear') -OnClick { foreach ($r in $script:WNGui.TweakList.Rows) { $r.Selected = $false } })
    )
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.undo') -Icon 'E7A7' -OnClick {
            $sel = Get-WNGuiSelected $script:WNGui.TweakList.Rows
            if ($sel.Count -and (Confirm-WNGui (T 'gui.confirmUndo' $sel.Count))) { Invoke-WNGuiTweaks -Keys @($sel.Key) -Undo -Label (T 'gui.undo') }
        }),
        (New-WNGuiButton (T 'gui.apply') -Icon 'E73E' -Accent -OnClick {
            $sel = Get-WNGuiSelected $script:WNGui.TweakList.Rows
            if (-not $sel.Count) { return }
            $adv = @($sel | Where-Object { $_.Item.Level -eq 'Advanced' })
            $msg = T 'gui.confirmApply' $sel.Count
            if ($adv.Count) { $msg += "`n`n" + (T 'gui.advSelected' (($adv.Name) -join ', ')) }
            if (Confirm-WNGui $msg -Danger:([bool]$adv.Count)) { Invoke-WNGuiTweaks -Keys @($sel.Key) -Label (T 'gui.apply') }
        })
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Set-WNGuiTweakLevel 'Recommended'; Update-WNGuiTweakStates } }
}

function Build-WNGuiPrefs {
    param($p)
    $list = New-WNGuiList
    Set-WNGuiRows $list @($WN.Config.tweaks | Where-Object Type -eq 'Toggle' | Sort-Object Name |
        ForEach-Object { @{ Key = $_.Key; Name = $_.Name; Description = $_.Description; Item = $_ } })
    $script:WNGui.PrefList = $list
    $p.List = $list
    $p.Body = $list.List
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.flip') -Icon 'E8AB' -Accent -OnClick {
            $sel = Get-WNGuiSelected $script:WNGui.PrefList.Rows
            if ($sel.Count -and (Confirm-WNGui (T 'gui.confirmFlip' $sel.Count))) { Invoke-WNGuiTweaks -Keys @($sel.Key) -Flip -Label (T 'gui.flip') }
        })
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiTweakStates } }
}

# ---- Services
function Update-WNGuiServices {
    Start-WNGuiJob -Label (T 'gui.readingServices') -Script {
        $s = @{}
        foreach ($svc in $WN.Config.services) { $s[$svc.Name] = Get-WNServiceStartup $svc.Name }
        $s
    }.ToString() -OnDone {
        param($out)
        $cur = $out[0]
        foreach ($r in $script:WNGui.SvcList.Rows) {
            $c = $cur[$r.Key]
            if ($null -eq $c) { Set-WNGuiBadge $r (T 'svc.missing') 'None' }
            elseif ($c -eq $r.Item.Recommended) { Set-WNGuiBadge $r $c 'Applied' }
            else { Set-WNGuiBadge $r $c 'Partial' }
        }
    }
}

function Build-WNGuiServices {
    param($p)
    $list = New-WNGuiList -Grouped
    Set-WNGuiRows $list @($WN.Config.services | Sort-Object Category, DisplayName | ForEach-Object {
        @{ Key = $_.Name; Name = $_.DisplayName; Group = $_.Category; Item = $_
           Description = T 'gui.svcDetail' $_.Name $_.Description $_.Recommended $_.Default } })
    $script:WNGui.SvcList = $list
    $p.List = $list
    $p.Body = $list.List
    $set = {
        $mode = $this.Tag
        $sel = Get-WNGuiSelected $script:WNGui.SvcList.Rows
        if (-not $sel.Count) { return }
        # Inside switch $_ is the switch value, so the row needs its own variable
        $plan = @(foreach ($r in $sel) {
            $target = switch ($mode) { 'Default' { $r.Item.Default } 'Manual' { 'Manual' } default { $r.Item.Recommended } }
            @{ Name = $r.Key; Target = $target }
        })
        $lines = ($plan | ForEach-Object { "$($_.Name) -> $($_.Target)" }) -join "`n"
        if (-not (Confirm-WNGui "$(T 'gui.confirmServices' $plan.Count)`n`n$lines")) { return }
        Start-WNGuiJob -Label (T 'svc.title') -Arguments @($WN.DryRun, $plan) -Script {
            param($dry, $plan)
            $WN.DryRun = $dry
            if (-not (Start-WNChange -Label 'services' -Services @($plan | ForEach-Object { $_.Name }))) { return }
            foreach ($x in $plan) {
                $before = $WN.ErrorCount
                Set-WNService -Name $x.Name -StartupType $x.Target
                if ($WN.ErrorCount -eq $before) { Write-WNStatus "$($x.Name) -> $($x.Target)" $(if ($WN.DryRun) { 'Dry' } else { 'Ok' }) 'Service' }
            }
        }.ToString() -OnDone { foreach ($r in $script:WNGui.SvcList.Rows) { $r.Selected = $false }; Update-WNGuiServices }
    }
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.svcDefault') -Tag 'Default' -OnClick $set),
        (New-WNGuiButton 'Manual' -Tag 'Manual' -OnClick $set),
        (New-WNGuiButton (T 'gui.svcRecommended') -Icon 'E73E' -Accent -Tag 'Recommended' -OnClick $set)
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiServices } }
}

# ---- Startup apps
function Update-WNGuiStartup {
    Start-WNGuiJob -Label (T 'gui.readingStartup') -Script {
        foreach ($e in Get-WNStartupEntries) { $e | Add-Member -NotePropertyName Enabled -NotePropertyValue (Test-WNStartupEnabled $e) -PassThru }
    }.ToString() -OnDone {
        param($out)
        $l = $script:WNGui.StartupList
        Set-WNGuiRows $l @(@($out) | ForEach-Object { @{ Key = $_.Name; Name = $_.Name; Description = "$(T $_.Scope)  -  $($_.Command)"; Item = $_ } })
        foreach ($r in $l.Rows) { if ($r.Item.Enabled) { Set-WNGuiBadge $r (T 'gui.enabled') 'Applied' } else { Set-WNGuiBadge $r (T 'gui.disabled') 'None' } }
    }
}

function Build-WNGuiStartup {
    param($p)
    $list = New-WNGuiList
    $script:WNGui.StartupList = $list
    $p.List = $list
    $p.Body = $list.List
    $set = {
        $enable = $this.Tag -eq 'on'
        $sel = Get-WNGuiSelected $script:WNGui.StartupList.Rows
        if (-not $sel.Count) { return }
        if (-not (Confirm-WNGui (T $(if ($enable) { 'gui.confirmEnable' } else { 'gui.confirmDisable' }) $sel.Count))) { return }
        Start-WNGuiJob -Label (T 'st.title') -Arguments @($WN.DryRun, @($sel.Item), $enable) -Script {
            param($dry, $entries, $enable)
            $WN.DryRun = $dry
            $regs = @($entries | ForEach-Object { [pscustomobject]@{ Path = $_.ApprovedPath; Name = $_.Name } })
            if (-not (Start-WNChange -Label 'startup apps' -Registry $regs -Items @($entries | ForEach-Object Name))) { return }
            foreach ($e in $entries) { Set-WNStartupEnabled -Entry $e -Enabled $enable }
        }.ToString() -OnDone { Update-WNGuiStartup }
    }
    Add-WNGuiTools $p @((New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -OnClick { Update-WNGuiStartup }))
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.enable') -Tag 'on' -OnClick $set),
        (New-WNGuiButton (T 'gui.disable') -Icon 'E711' -Accent -Tag 'off' -OnClick $set)
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiStartup } }
}

# ---- Apps
function Set-WNGuiApps {
    # Fills the apps list with catalog apps or winget search results (same object shape)
    param([object[]]$Apps)
    $g = $script:WNGui
    Set-WNGuiRows $g.AppList @($Apps | ForEach-Object {
        # Catalog apps have a category and a text description; winget results only a version
        @{ Key = $_.Winget; Name = $_.Name; Item = $_
           Description = $(if ($_.Category) { "$($_.Category)  -  $($_.Description)  -  $($_.Winget)" } else { "$($_.Winget)  $($_.Description)" }) } })
    Update-WNGuiAppBadges
    Update-WNGuiFilter
}

function Update-WNGuiAppBadges {
    $g = $script:WNGui
    foreach ($r in $g.AppList.Rows) {
        if ($g.InstalledIds -and $g.InstalledIds.Contains($r.Key)) { Set-WNGuiBadge $r (T 'gui.installed') 'Applied' }
        elseif ($r.Item.Foss) { Set-WNGuiBadge $r 'FOSS' 'Action' }
        else { $r.Badge = $null }
    }
}

function Update-WNGuiInstalled {
    Start-WNGuiJob -Label (T 'apps.reading') -Script { [string[]]@((Get-WNInstalledAppIds -Refresh) | ForEach-Object { $_ }) }.ToString() -OnDone {
        param($out)
        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($id in @($out)) { [void]$set.Add([string]$id) }
        $script:WNGui.InstalledIds = $set
        Update-WNGuiAppBadges
        Update-WNGuiFilter
    }
}

function Build-WNGuiApps {
    param($p)
    $g = $script:WNGui
    $g.AppList = New-WNGuiList
    $g.AppCount = New-WNGuiText '' -Dim -Margin '4,0,0,0'
    $p.List = $g.AppList
    $p.Body = $g.AppList.List
    $p.SearchHint = T 'gui.searchApps'
    $p.OnFilter = { $script:WNGui.AppCount.Text = T 'gui.results' @($script:WNGui.AppList.View).Count }
    # Enter in the top search box looks the name up in all of winget
    $p.OnSearch = {
        $q = $script:WNGui.Ctl.SearchBox.Text.Trim()
        if (-not $q) { return }
        Start-WNGuiJob -Label (T 'gui.searchWinget') -Arguments @(, $q) -Script { param($q) @(Search-WNWinget $q) }.ToString() -OnDone {
            param($out)
            $g = $script:WNGui
            $g.Pages['apps'].OnlyBadge = $null
            # Results are already the answer to the query; showing them unfiltered avoids hiding ids that differ from the name
            $g.Ctl.SearchBox.Text = ''
            Set-WNGuiApps @($out)
        }
    }
    Add-WNGuiTools $p @(
        (New-WNGuiSegments 'appsView' @(@{ Text = (T 'gui.catalog'); Value = 'all' }, @{ Text = (T 'gui.installedOnly'); Value = 'installed' }) {
            $g = $script:WNGui
            $g.Pages['apps'].OnlyBadge = if ($this.Tag -eq 'installed') { T 'gui.installed' } else { $null }
            if ($this.Tag -eq 'all') { Set-WNGuiApps @($WN.Config.apps | Sort-Object Name) } else { Update-WNGuiFilter }
        }),
        (New-WNGuiButton (T 'gui.searchWinget') -Icon 'E721' -OnClick { & $script:WNGui.Pages['apps'].OnSearch }),
        $g.AppCount
    )
    $run = {
        $mode = $this.Tag
        $g = $script:WNGui
        if ($mode -eq 'upgrade') {
            if (-not (Confirm-WNGui (T 'apps.upgradeAsk'))) { return }
            Start-WNGuiJob -Label (T 'apps.upgradeTitle') -Arguments @(, $WN.DryRun) -Script {
                param($dry)
                $WN.DryRun = $dry
                if (Start-WNChange -Label 'upgrade all apps' -Apps) { [void](Invoke-WNWinget @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--silent')) }
            }.ToString() -OnDone { Update-WNGuiInstalled }
            return
        }
        $sel = Get-WNGuiSelected $g.AppList.Rows
        if (-not $sel.Count) { return }
        $key = if ($mode -eq 'install') { 'gui.confirmInstall' } else { 'gui.confirmUninstallApps' }
        if (-not (Confirm-WNGui (T $key $sel.Count))) { return }
        Start-WNGuiJob -Label (T $(if ($mode -eq 'install') { 'gui.install' } else { 'gui.uninstallApps' })) -Arguments @($WN.DryRun, @($sel.Item), $mode) -Script {
            param($dry, $apps, $mode)
            $WN.DryRun = $dry
            if ($mode -eq 'install') { Install-WNApps -Apps @($apps) } else { Uninstall-WNApps -Apps @($apps) }
        }.ToString() -OnDone { foreach ($r in $script:WNGui.AppList.Rows) { $r.Selected = $false }; Update-WNGuiInstalled }
    }
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.upgradeAll') -Icon 'E895' -Tag 'upgrade' -OnClick $run),
        (New-WNGuiButton (T 'gui.uninstallApps') -Icon 'E74D' -Tag 'uninstall' -OnClick $run),
        (New-WNGuiButton (T 'gui.install') -Icon 'E896' -Accent -Tag 'install' -OnClick $run)
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Set-WNGuiApps @($WN.Config.apps | Sort-Object Name); Update-WNGuiInstalled } }
}

# ---- Uninstall programs
function Update-WNGuiPrograms {
    $store = $script:WNGui.UninstallMode -eq 'store'
    Start-WNGuiJob -Label (T 'un.reading') -Arguments @(, $store) -Script {
        param($store)
        if ($store) { @(Get-WNStoreApps -Refresh) } else { @(Get-WNInstalledPrograms -Refresh) }
    }.ToString() -OnDone {
        param($out)
        $g = $script:WNGui
        $store = $g.UninstallMode -eq 'store'
        Set-WNGuiRows $g.ProgramList @(@($out) | ForEach-Object {
            if ($store) { @{ Key = $_.PackageFullName; Name = $_.Name; Description = T 'un.detail' $_.Publisher $_.Version '-'; Item = $_ } }
            else {
                $size = if ($_.SizeMB) { "$($_.SizeMB) MB" } else { '-' }
                @{ Key = $_.Name; Name = $_.Name; Item = $_
                   Description = T 'un.detail' $(if ($_.Publisher) { $_.Publisher } else { '-' }) $(if ($_.Version) { $_.Version } else { '-' }) $size }
            }
        })
        if (-not $store) { foreach ($r in $g.ProgramList.Rows) { if ($r.Item.Silent) { Set-WNGuiBadge $r (T 'un.tagSilent') 'Applied' } else { Set-WNGuiBadge $r (T 'un.tagWizard') 'Partial' } } }
        Update-WNGuiFilter
    }
}

function Build-WNGuiUninstall {
    param($p)
    $g = $script:WNGui
    $g.ProgramList = New-WNGuiList
    $g.UninstallMode = 'desktop'
    $p.List = $g.ProgramList
    $p.Body = $g.ProgramList.List
    Add-WNGuiTools $p @(
        (New-WNGuiSegments 'uninstall' @(@{ Text = (T 'un.desktopTitle'); Value = 'desktop' }, @{ Text = (T 'un.storeTitle'); Value = 'store' }) {
            $script:WNGui.UninstallMode = $this.Tag
            if ($script:WNGui.Pages['uninstall'].Built) { Update-WNGuiPrograms }
        }),
        (New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -OnClick { Update-WNGuiPrograms })
    )
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'gui.uninstallSel') -Icon 'E74D' -Accent -OnClick {
            $g = $script:WNGui
            $sel = Get-WNGuiSelected $g.ProgramList.Rows
            if (-not $sel.Count) { return }
            $store = $g.UninstallMode -eq 'store'
            $msg = T 'un.confirmTitle' $sel.Count
            if (-not $store -and ($sel | Where-Object { -not $_.Item.Silent })) { $msg += "`n`n" + (T 'un.wizardNote') }
            if (-not (Confirm-WNGui $msg -Danger)) { return }
            Start-WNGuiJob -Label (T 'un.title') -Arguments @($WN.DryRun, @($sel.Item), $store) -Script {
                param($dry, $items, $store)
                $WN.DryRun = $dry
                if ($store) { Uninstall-WNStoreApps -Packages @($items) } else { Uninstall-WNPrograms -Programs @($items) }
            }.ToString() -OnDone { Update-WNGuiPrograms }
        })
    )
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiPrograms } }
}

# ---- Repair
function Build-WNGuiRepair {
    param($p)
    $stack = New-WNGuiPanel -Orientation Vertical
    $run = {
        $t = $script:RepairTasks | Where-Object { $_.Id -eq $this.Tag } | Select-Object -First 1
        $msg = T 'gui.confirmRun' (T $t.Label)
        if ($t.Warning) { $msg += "`n`n" + (T $t.Warning) }
        if (-not $t.ReadOnly -or $t.NeedsConfirm) { if (-not (Confirm-WNGui $msg -Danger:([bool]$t.NeedsConfirm))) { return } }
        Start-WNGuiJob -Label (T $t.Label) -Arguments @($WN.DryRun, $t.Id) -Script { param($dry, $id) $WN.DryRun = $dry; Invoke-WNRepairTask $id }.ToString()
    }
    $section = $null
    foreach ($t in $script:RepairTasks) {
        if ($t.Section -ne $section) { $section = $t.Section; [void]$stack.Children.Add((New-WNGuiText (T $section) -Style Section)) }
        $icon = switch ($t.Section) { 'rep.secFiles' { 'E90F' } 'rep.secCleanup' { 'E74D' } default { 'E774' } }
        [void]$stack.Children.Add((New-WNGuiCard -Title (T $t.Label) -Text (T $t.Hint) -Icon $icon -Buttons @(New-WNGuiButton (T 'gui.run') -Icon 'E768' -Tag $t.Id -OnClick $run)))
    }
    $p.Body = New-WNGuiScroll $stack
}

# ---- Windows Update
function Update-WNGuiUpdateStatus {
    $g = $script:WNGui
    $g.UpdStatus.Children.Clear()
    foreach ($r in (Get-WNUpdateStatus)) {
        $v = if ($null -eq $r[1] -or "$($r[1])" -eq '') { T 'common.default' } else { "$($r[1])" }
        $row = New-Object Windows.Controls.DockPanel
        $val = New-WNGuiText $v -Bold
        [Windows.Controls.DockPanel]::SetDock($val, 'Right')
        [void]$row.Children.Add($val)
        [void]$row.Children.Add((New-WNGuiText $r[0] -Dim))
        $row.Margin = '0,3'
        [void]$g.UpdStatus.Children.Add($row)
    }
}

function Build-WNGuiUpdates {
    param($p)
    $g = $script:WNGui
    $g.UpdStatus = New-WNGuiPanel -Orientation Vertical
    $g.UpdStatus.Margin = '0,8,0,0'
    $g.PauseDays = New-Object Windows.Controls.TextBox
    $g.PauseDays.Style = $g.Window.Resources['Box']
    $g.PauseDays.Width = 70
    $g.PauseDays.Text = '7'
    [Windows.Automation.AutomationProperties]::SetName($g.PauseDays, (T 'upd.askDays'))
    $run = {
        $mode = $this.Tag
        $g = $script:WNGui
        $days = 0
        if ($mode -eq 'pause') {
            $d = $g.PauseDays.Text.Trim()
            if ($d -notmatch '^\d+$' -or [int]$d -lt 1 -or [int]$d -gt 35) { Show-WNGuiInfo (T 'upd.badDays'); return }
            $days = [int]$d
        }
        $ask = switch ($mode) { 'rec' { T 'upd.askRec' } 'default' { T 'upd.askDefault' } 'pause' { T 'gui.askPause' $days } default { T 'upd.resume' } }
        if (-not (Confirm-WNGui $ask)) { return }
        Start-WNGuiJob -Label 'Windows Update' -Arguments @($WN.DryRun, $mode, $days) -Script {
            param($dry, $mode, $days)
            $WN.DryRun = $dry
            if (-not (Start-WNUpdateChange "updates $mode")) { return }
            switch ($mode) { 'rec' { Set-WNUpdatesRecommended } 'default' { Set-WNUpdatesDefault } 'pause' { Suspend-WNUpdates -Days $days } 'resume' { Resume-WNUpdates } }
        }.ToString() -OnDone { Update-WNGuiUpdateStatus }
    }
    $pauseExtra = New-WNGuiPanel -Children @($g.PauseDays, (New-WNGuiText (T 'gui.days') -Dim))
    $pauseExtra.Margin = '0,8,0,0'
    $stack = New-WNGuiPanel -Orientation Vertical -Children @(
        (New-WNGuiCard -Title (T 'upd.status') -Text (T 'upd.statusHint') -Icon 'E946' -Extra $g.UpdStatus),
        (New-WNGuiCard -Title (T 'upd.rec') -Text (T 'upd.recHint') -Icon 'E73E' -Buttons @(New-WNGuiButton (T 'gui.applyOne') -Accent -Tag 'rec' -OnClick $run)),
        (New-WNGuiCard -Title (T 'upd.default') -Text (T 'upd.defaultHint') -Icon 'E777' -Buttons @(New-WNGuiButton (T 'gui.restore') -Tag 'default' -OnClick $run)),
        (New-WNGuiCard -Title (T 'gui.pause') -Text (T 'upd.pauseHint') -Icon 'E769' -Extra $pauseExtra -Buttons @(New-WNGuiButton (T 'gui.pauseBtn') -Tag 'pause' -OnClick $run)),
        (New-WNGuiCard -Title (T 'upd.resume') -Text (T 'upd.resumeHint') -Icon 'E768' -Buttons @(New-WNGuiButton (T 'gui.resumeBtn') -Tag 'resume' -OnClick $run)),
        (New-WNGuiCard -Title (T 'upd.open') -Text 'ms-settings:windowsupdate' -Icon 'E8A7' -Buttons @(New-WNGuiButton (T 'gui.open') -Always -OnClick { Start-Process 'ms-settings:windowsupdate' }))
    )
    $p.Body = New-WNGuiScroll $stack
    $p.OnShow = { Update-WNGuiUpdateStatus }
}

# ---- Backups & restore
function Update-WNGuiBackups {
    $g = $script:WNGui
    if ($g.BackupMode -eq 'rp') {
        Start-WNGuiJob -Label (T 'bkm.rpList') -Script { @(Get-WNRestorePointList) }.ToString() -OnDone {
            param($out)
            Set-WNGuiRows $script:WNGui.BackupList @(@($out) | Sort-Object Created -Descending | ForEach-Object {
                @{ Key = "$($_.Sequence)"; Name = $_.Description; Description = '#{0}  -  {1:yyyy-MM-dd HH:mm}' -f $_.Sequence, $_.Created; Item = $_ } })
            if (-not $script:WNGui.BackupList.Rows.Count) { $script:WNGui.Status.Text = T 'bkm.rpNone' }
            Update-WNGuiFilter
        }
    } else {
        Set-WNGuiRows $g.BackupList @(@(Get-WNBackups) | ForEach-Object {
            $count = @($_.Registry).Count + @($_.Services).Count + @($_.Dns).Count
            @{ Key = $_.File; Name = "$($_.Created)  $($_.Label)"; Description = "$(T 'gui.values' $count)  -  $($_.File)"; Item = $_ } })
        foreach ($r in $g.BackupList.Rows) { Set-WNGuiBadge $r ('{0:N0} KB' -f [Math]::Ceiling((Get-Item -LiteralPath $r.Key).Length / 1KB)) 'None' }
        Update-WNGuiFilter
    }
    foreach ($c in $g.RpActions, $g.RpTools) { $c.Visibility = if ($g.BackupMode -eq 'rp') { 'Visible' } else { 'Collapsed' } }
    foreach ($c in $g.BkActions, $g.BkTools) { $c.Visibility = if ($g.BackupMode -eq 'rp') { 'Collapsed' } else { 'Visible' } }
}

function Build-WNGuiBackups {
    param($p)
    $g = $script:WNGui
    $g.BackupList = New-WNGuiList
    $g.BackupMode = 'rp'
    $p.List = $g.BackupList
    $p.Body = $g.BackupList.List
    $rp = {
        $mode = $this.Tag
        if ($mode -eq 'rstrui') { Start-Process rstrui.exe; return }
        $msg, $danger = switch ($mode) {
            'create' { (T 'bkm.rpCreateHint'), $false }
            'oldest' { ((T 'bkm.rpOld') + '?'), $true }
            'all'    { "$(T 'bkm.allWarn1' $script:WNGui.BackupList.Rows.Count $env:SystemDrive)`n$(T 'bkm.allWarn2')", $true }
        }
        if (-not (Confirm-WNGui $msg -Danger:$danger)) { return }
        # Deleting every restore point asks twice, like typing DELETE in the terminal
        if ($mode -eq 'all' -and -not (Confirm-WNGui (T 'gui.reallyAll') -Danger)) { return }
        Start-WNGuiJob -Label (T 'bkm.secRp') -Arguments @($WN.DryRun, $mode) -Script {
            param($dry, $mode)
            $WN.DryRun = $dry
            if (-not (Test-WNCanChange)) { return }
            switch ($mode) { 'create' { [void](New-WNRestorePoint -Force) } 'oldest' { Remove-WNShadowCopies -Mode Oldest } 'all' { Remove-WNShadowCopies -Mode All } }
        }.ToString() -OnDone { Update-WNGuiBackups }
    }
    $bk = {
        $mode = $this.Tag
        $g = $script:WNGui
        if ($mode -eq 'folder') { Start-Process explorer.exe (Get-WNBackupDir); return }
        $sel = Get-WNGuiSelected $g.BackupList.Rows
        if (-not $sel.Count) { return }
        if ($mode -eq 'restore') {
            if ($sel.Count -ne 1) { Show-WNGuiInfo (T 'gui.selectOne'); return }
            if (-not (Confirm-WNGui (T 'bkm.restoreAsk' $sel[0].Item.Created))) { return }
        } elseif (-not (Confirm-WNGui "$(T 'bkm.delConfirmTitle' $sel.Count)`n`n$(T 'bkm.delWarn')" -Danger)) { return }
        Start-WNGuiJob -Label (T 'bkm.secBackups') -Arguments @($WN.DryRun, $mode, @($sel.Key)) -Script {
            param($dry, $mode, $files)
            $WN.DryRun = $dry
            if ($mode -eq 'restore') {
                $b = Get-WNBackups | Where-Object { $_.File -eq $files[0] } | Select-Object -First 1
                if ($b) { Restore-WNBackup -Backup $b }
            } else {
                foreach ($f in $files) { Remove-WNBackupFile $f }
            }
        }.ToString() -OnDone { Update-WNGuiBackups }
    }
    $g.RpTools = New-WNGuiPanel -Children @(
        (New-WNGuiButton (T 'gui.rpOpen') -Icon 'E777' -Tag 'rstrui' -Always -OnClick $rp),
        (New-WNGuiButton (T 'gui.rpDelOldest') -Tag 'oldest' -OnClick $rp),
        (New-WNGuiButton (T 'gui.rpDelAll') -Tag 'all' -OnClick $rp))
    $g.BkTools = New-WNGuiPanel -Children @(
        (New-WNGuiButton (T 'gui.folder') -Icon 'E8B7' -Tag 'folder' -Always -OnClick $bk),
        (New-WNGuiButton (T 'gui.delete') -Icon 'E74D' -Tag 'delete' -OnClick $bk))
    $g.RpActions = New-WNGuiButton (T 'gui.rpCreate') -Icon 'E710' -Accent -Tag 'create' -OnClick $rp
    $g.BkActions = New-WNGuiButton (T 'gui.restoreSel') -Icon 'E777' -Accent -Tag 'restore' -OnClick $bk
    Add-WNGuiTools $p @(
        (New-WNGuiSegments 'backups' @(@{ Text = (T 'bkm.secRp'); Value = 'rp' }, @{ Text = (T 'bkm.secBackups'); Value = 'bk' }) {
            $script:WNGui.BackupMode = $this.Tag
            if ($script:WNGui.Pages['backups'].Built) { Update-WNGuiBackups }
        }),
        (New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -OnClick { Update-WNGuiBackups }),
        $g.RpTools, $g.BkTools)
    Add-WNGuiActions $p @($g.RpActions, $g.BkActions)
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiBackups } }
}

# ---- DNS
function Update-WNGuiDns {
    Start-WNGuiJob -Label (T 'dns.show') -Script { @(Get-WNCurrentDns) }.ToString() -OnDone {
        param($out)
        $panel = $script:WNGui.DnsCurrent
        $panel.Children.Clear()
        foreach ($d in @($out)) {
            $text = "IPv4: $(if ($d.IPv4) { $d.IPv4 } else { T 'dns.none' })$(if ($d.IPv6) { "`nIPv6: $($d.IPv6)" })"
            [void]$panel.Children.Add((New-WNGuiPanel -Orientation Vertical -Children @((New-WNGuiText $d.Name -Bold -Margin '0,6,0,0'), (New-WNGuiText $text -Dim -Size 12.5 -Wrap))))
        }
        if (-not @($out).Count) { [void]$panel.Children.Add((New-WNGuiText (T 'dns.noAdapters') -Dim)) }
    }
}

function Build-WNGuiDns {
    param($p)
    $g = $script:WNGui
    $g.DnsCurrent = New-WNGuiPanel -Orientation Vertical
    $use = {
        $name = $this.Tag
        $label = if ($name -eq 'DHCP') { T 'dns.dhcp' } else { $name -replace '_', ' ' }
        if (-not (Confirm-WNGui (T 'gui.confirmDns' $label))) { return }
        Start-WNGuiJob -Label "DNS $label" -Arguments @($WN.DryRun, $name) -Script { param($dry, $name) $WN.DryRun = $dry; Set-WNDns -Provider $name }.ToString() -OnDone { Update-WNGuiDns }
    }
    $tiles = New-WNGuiPanel -Wrap
    foreach ($prov in $WN.Config.dns.PSObject.Properties) {
        [void]$tiles.Children.Add((New-WNGuiCard -Title ($prov.Name -replace '_', ' ') -Text "$($prov.Value.Primary), $($prov.Value.Secondary)" -Width 300 `
            -Buttons @(New-WNGuiButton (T 'gui.use') -Tag $prov.Name -OnClick $use)))
    }
    [void]$tiles.Children.Add((New-WNGuiCard -Title (T 'dns.dhcp') -Text (T 'dns.dhcpHint') -Width 300 -Buttons @(New-WNGuiButton (T 'gui.use') -Tag 'DHCP' -OnClick $use)))
    $p.Body = New-WNGuiScroll (New-WNGuiPanel -Orientation Vertical -Children @(
        (New-WNGuiCard -Title (T 'dns.show') -Text (T 'dns.showHint') -Icon 'E774' -Extra $g.DnsCurrent -Buttons @(New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -OnClick { Update-WNGuiDns })),
        (New-WNGuiText (T 'gui.providers') -Style Section),
        $tiles))
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiDns } }
}

# ---- Hosts
function Update-WNGuiHosts {
    $g = $script:WNGui
    foreach ($b in $g.HostsBlocks) {
        $on = Test-WNHostsBlock $b.Block
        $b.Badge.Text = if ($on) { T 'gui.active' } else { T 'gui.inactive' }
        $b.Button.Content = New-WNGuiText $(if ($on) { T 'gui.removeBlock' } else { T 'gui.addBlock' })
        $b.Button.Style = $g.Window.Resources[$(if ($on) { 'Btn' } else { 'AccentBtn' })]
    }
    $g.HostsText.Text = (@(Get-WNHostsLines | Where-Object { $_ -and $_.Trim() -notmatch '^#' }) -join "`r`n")
}

function Build-WNGuiHosts {
    param($p)
    $g = $script:WNGui
    $g.HostsBlocks = @()
    $toggle = {
        $key = $this.Tag
        $undo = (Get-WNTweakState (Get-WNTweak $key)) -eq 'Applied'
        if (-not (Confirm-WNGui (T $(if ($undo) { 'gui.confirmUnblock' } else { 'gui.confirmBlock' }) (Get-WNTweak $key).Name))) { return }
        Start-WNGuiJob -Label (T 'hosts.title') -Arguments @($WN.DryRun, $key, $undo) -Script {
            param($dry, $key, $undo)
            $WN.DryRun = $dry
            Invoke-WNTweakBatch -Tweaks @(Get-WNTweak $key) -Undo:$undo
        }.ToString() -OnDone { Update-WNGuiHosts }
    }
    $cards = foreach ($b in @(@{ Block = 'telemetry'; Key = 'TelemetryHosts'; Title = 'gui.hostsTele'; Hint = 'hosts.teleHint' }, @{ Block = 'adobe'; Key = 'AdobeHosts'; Title = 'gui.hostsAdobe'; Hint = 'hosts.adobeHint' })) {
        $btn = New-WNGuiButton '' -Tag $b.Key -OnClick $toggle
        $badge = New-WNGuiText '' -Bold -Accent -Margin '0,0,12,0'
        $g.HostsBlocks += @{ Block = $b.Block; Button = $btn; Badge = $badge }
        New-WNGuiCard -Title (T $b.Title) -Text (T $b.Hint) -Icon 'E72E' -Buttons @($badge, $btn)
    }
    $g.HostsText = New-Object Windows.Controls.TextBox
    $g.HostsText.IsReadOnly = $true
    $g.HostsText.FontFamily = 'Cascadia Mono, Consolas'
    $g.HostsText.FontSize = 12
    $g.HostsText.MinHeight = 140
    $g.HostsText.Background = 'Transparent'
    $g.HostsText.BorderThickness = 0
    $g.HostsText.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'Fg')
    $p.Body = New-WNGuiScroll (New-WNGuiPanel -Orientation Vertical -Children (@($cards) + @(
        (New-WNGuiText (T 'hosts.viewTitle') -Style Section),
        (New-WNGuiGlass $g.HostsText))))
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'hosts.backups') -Icon 'E8B7' -Always -OnClick { Start-Process explorer.exe (Get-WNBackupDir) }),
        (New-WNGuiButton (T 'hosts.edit') -Icon 'E70F' -OnClick {
            if ($WN.DryRun) { Show-WNGuiInfo (T 'hosts.dryEdit'); return }
            Start-WNGuiJob -Label (T 'hosts.edit') -Script { if (Start-WNChange -Label 'hosts edit') { Backup-WNHosts; Start-Process notepad.exe $script:HostsFile } }.ToString()
        })
    )
    $p.OnShow = { Update-WNGuiHosts }
}

# ---- System information
function Update-WNGuiSysInfo {
    # Shared by Home and System information; read once in the worker
    Start-WNGuiJob -Label (T 'sys.collecting') -Script { Get-WNSystemInfo }.ToString() -OnDone {
        param($out)
        $g = $script:WNGui
        $g.SysInfo = $out[0]
        foreach ($cb in @($g.SysInfoListeners)) { & $cb }
    }
}

function New-WNGuiInfoTile {
    param([string]$Label, [string]$Value, $Extra)
    New-WNGuiGlass (New-WNGuiPanel -Orientation Vertical -Children @((New-WNGuiText $Label -Dim -Size 12.5), (New-WNGuiText $Value -Bold -Wrap -Margin '0,4,0,0'), $Extra)) -Width 262
}

function New-WNGuiDiskTile {
    param($Disk)
    $bar = New-Object Windows.Controls.ProgressBar
    $bar.Height = 6
    $bar.Margin = '0,8,0,0'
    $bar.Value = $Disk.UsedPct
    $bar.BorderThickness = 0
    $bar.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, $(if ($Disk.UsedPct -ge 90) { 'AccentText' } else { 'AccentSolid' }))
    $bar.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'Hover')
    New-WNGuiInfoTile (T 'gui.disk' $Disk.Drive) (T 'gui.diskValue' $Disk.UsedPct $Disk.FreeGB $Disk.SizeGB) $bar
}

function Build-WNGuiSystem {
    param($p)
    $g = $script:WNGui
    $g.SysPanel = New-WNGuiPanel -Wrap
    $p.Body = New-WNGuiScroll $g.SysPanel
    $g.SysInfoListeners += {
        $g = $script:WNGui
        $g.SysPanel.Children.Clear()
        foreach ($k in $g.SysInfo.Rows.Keys) { [void]$g.SysPanel.Children.Add((New-WNGuiInfoTile $k "$($g.SysInfo.Rows[$k])")) }
        foreach ($d in $g.SysInfo.Disks) { [void]$g.SysPanel.Children.Add((New-WNGuiDiskTile $d)) }
    }
    Add-WNGuiActions $p @((New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -OnClick { Update-WNGuiSysInfo }))
    $p.OnShow = { param($p) if ($script:WNGui.SysInfo) { foreach ($cb in @($script:WNGui.SysInfoListeners)) { & $cb } } else { Update-WNGuiSysInfo } }
}

# ---- Logs
function Build-WNGuiLogs {
    param($p)
    $g = $script:WNGui
    $g.LogView = New-Object Windows.Controls.TextBox
    $g.LogView.IsReadOnly = $true
    $g.LogView.FontFamily = 'Cascadia Mono, Consolas'
    $g.LogView.FontSize = 12
    $g.LogView.TextWrapping = 'NoWrap'
    $g.LogView.VerticalScrollBarVisibility = 'Auto'
    $g.LogView.HorizontalScrollBarVisibility = 'Auto'
    $g.LogView.Background = 'Transparent'
    $g.LogView.BorderThickness = 0
    $g.LogView.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'Fg')
    $glass = New-WNGuiGlass $g.LogView
    $glass.Margin = '0'
    $p.Body = $glass
    $g.LogMode = 'tail'
    $g.LogShow = {
        $g = $script:WNGui
        $lines = if ($g.LogMode -eq 'errors') {
            @(Get-ChildItem (Split-Path $WN.LogFile) -Filter '*.log' | Sort-Object Name | Get-Content | Where-Object { $_ -match '\]\[(WARN|ERROR)\]' } | Select-Object -Last 200)
        } else { @(Get-Content $WN.LogFile -Tail 200 -ErrorAction SilentlyContinue) }
        $g.LogView.Text = $lines -join "`r`n"
        $g.LogView.ScrollToEnd()
    }
    Add-WNGuiTools $p @(
        (New-WNGuiSegments 'logs' @(@{ Text = (T 'gui.logRecent'); Value = 'tail' }, @{ Text = (T 'logs.errors'); Value = 'errors' }) { $script:WNGui.LogMode = $this.Tag; & $script:WNGui.LogShow }),
        (New-WNGuiButton (T 'gui.refresh') -Icon 'E72C' -Always -OnClick { & $script:WNGui.LogShow })
    )
    Add-WNGuiActions $p @(
        (New-WNGuiButton (T 'logs.folder') -Icon 'E8B7' -Always -OnClick { Start-Process explorer.exe (Split-Path $WN.LogFile) }),
        (New-WNGuiButton (T 'logs.notepad') -Icon 'E70F' -Always -OnClick { Start-Process notepad.exe $WN.LogFile })
    )
    $p.OnShow = { & $script:WNGui.LogShow }
}

# ---- Home: banner, start-here card, tool tiles, this PC
function New-WNGuiChip {
    param([string]$Text)
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = 12
    $b.Padding = '11,4'
    $b.Margin = '0,0,6,0'
    $b.Background = [Windows.Media.Brush](ConvertTo-WNBrush '#38FFFFFF')
    $b.Child = New-WNGuiText $Text -Size 12
    $b.Child.Foreground = 'White'
    return $b
}

function New-WNGuiTile {
    # Translucent card with an app-icon style square in the colour of the tool's group
    param($Page)
    $b = New-Object Windows.Controls.Button
    $b.Style = $script:WNGui.Window.Resources['Tile']
    $b.Tag = $Page.Id
    $squircle = New-Object Windows.Controls.Border
    $squircle.Width = 44; $squircle.Height = 44
    $squircle.CornerRadius = 12
    $squircle.HorizontalAlignment = 'Left'
    $squircle.Background = [Windows.Media.Brush](ConvertTo-WNBrush $script:WNGuiArt[$Page.Section] -Diagonal)
    $icon = New-WNGuiIcon $Page.Icon 21
    $icon.Foreground = 'White'
    $icon.HorizontalAlignment = 'Center'
    $squircle.Child = $icon
    $b.Content = New-WNGuiPanel -Orientation Vertical -Children @(
        $squircle,
        (New-WNGuiText $Page.Title -Bold -Size 13.5 -Wrap -Margin '0,10,0,0'),
        (New-WNGuiText (T $Page.Section) -Dim -Size 12))
    [Windows.Automation.AutomationProperties]::SetName($b, $Page.Title)
    $b.ToolTip = $Page.Hint
    $b.Add_Click({ Show-WNGuiPage $this.Tag })
    return $b
}

function Build-WNGuiHome {
    param($p)
    $g = $script:WNGui
    $p.NoHeader = $true
    $tweaks = @($WN.Config.tweaks | Where-Object Type -ne 'Toggle')
    $rec = @($tweaks | Where-Object Level -eq 'Recommended')

    # Banner: same colours in light and dark, white text
    $hero = New-Object Windows.Controls.Border
    $hero.CornerRadius = 22
    $hero.Height = 300
    $hero.Background = [Windows.Media.Brush](ConvertTo-WNBrush @('#FF0A84FF', '#FF5E5CE6', '#FFBF5AF2') -Diagonal)
    $heroGrid = New-Object Windows.Controls.Grid
    $mark = New-WNGuiImage 'Winnow_icon_512.png' 230 0.28
    if ($mark) { $mark.HorizontalAlignment = 'Right'; $mark.VerticalAlignment = 'Center'; $mark.Margin = '0,0,40,0'; [void]$heroGrid.Children.Add($mark) }
    $chips = New-WNGuiPanel -Children @('main.secOptimize', 'main.secApps', 'main.secMaintain', 'main.secNetwork' | ForEach-Object { New-WNGuiChip (T $_) })
    $chips.VerticalAlignment = 'Top'
    $chips.Margin = '28,24,0,0'
    $title = New-WNGuiText 'Winnow' -Size 56
    $title.FontFamily = 'Segoe UI Variable Display, Segoe UI'
    $title.FontWeight = 'Bold'
    $title.Foreground = 'White'
    $tag = New-WNGuiText (T 'tagline') -Size 16
    $tag.Foreground = 'White'
    $stats = New-WNGuiText (T 'gui.heroStats' $tweaks.Count @($WN.Config.apps).Count ($g.Pages.Count - 1)) -Size 12.5 -Margin '0,10,0,0'
    $stats.Foreground = 'White'
    $stats.Opacity = 0.85
    $heroText = New-WNGuiPanel -Orientation Vertical -Children @($title, $tag, $stats)
    $heroText.VerticalAlignment = 'Bottom'
    $heroText.Margin = '28,0,0,26'
    [void]$heroGrid.Children.Add($chips)
    [void]$heroGrid.Children.Add($heroText)
    $hero.Child = $heroGrid

    # Start-here card next to the banner
    $card = New-Object Windows.Controls.Border
    $card.CornerRadius = 22
    $card.Padding = '22,20'
    $card.Margin = '16,0,0,0'
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Card')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $card.BorderThickness = 1
    $go = New-WNGuiButton (T 'gui.recBtn') -Icon 'E73E' -Accent -Always -OnClick {
        Show-WNGuiPage 'tweaks'
        $script:WNGui.TweakSegs.Children[0].IsChecked = $true
        $keys = @($WN.Config.presets.Standard.Tweaks)
        foreach ($r in $script:WNGui.TweakList.Rows) { $r.Selected = $keys -contains $r.Key }
    }
    $go.Margin = '0'
    $go.HorizontalAlignment = 'Stretch'
    $cardBody = New-Object Windows.Controls.DockPanel
    [Windows.Controls.DockPanel]::SetDock($go, 'Bottom')
    [void]$cardBody.Children.Add($go)
    $note = New-WNGuiText (T 'gui.previewShort') -Dim -Size 11.5 -Wrap -Margin '0,0,0,12'
    [Windows.Controls.DockPanel]::SetDock($note, 'Bottom')
    [void]$cardBody.Children.Add($note)
    $info = New-WNGuiPanel -Orientation Vertical -Children @(
        (New-WNGuiText (T 'gui.recKicker') -Accent -Bold -Size 12),
        (New-WNGuiText (T 'gui.recTitle') -Bold -Size 21 -Margin '0,6,0,0'),
        (New-WNGuiText (T 'gui.recText') -Dim -Size 12.5 -Wrap -Margin '0,8,0,0'),
        (New-WNGuiText (T 'gui.recStat' $rec.Count) -Accent -Bold -Size 13 -Wrap -Margin '0,12,0,0'))
    $info.VerticalAlignment = 'Top'
    [void]$cardBody.Children.Add($info)
    $card.Child = $cardBody

    $top = New-Object Windows.Controls.Grid
    $top.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
    $c2 = New-Object Windows.Controls.ColumnDefinition
    $c2.Width = 316
    $top.ColumnDefinitions.Add($c2)
    [Windows.Controls.Grid]::SetColumn($card, 1)
    [void]$top.Children.Add($hero)
    [void]$top.Children.Add($card)

    $tiles = New-WNGuiPanel -Wrap
    foreach ($id in @($g.Pages.Keys | Where-Object { $_ -ne 'home' })) { [void]$tiles.Children.Add((New-WNGuiTile $g.Pages[$id])) }

    $g.HomeInfo = New-WNGuiPanel -Wrap
    $g.SysInfoListeners += {
        $g = $script:WNGui
        $g.HomeInfo.Children.Clear()
        $r = $g.SysInfo.Rows
        # Skips the computer name (row 0): the home page ends up in screenshots
        foreach ($k in @($r.Keys)[1..5]) { [void]$g.HomeInfo.Children.Add((New-WNGuiInfoTile $k "$($r[$k])")) }
        $sys = $g.SysInfo.Disks | Where-Object { $_.Drive -eq $env:SystemDrive } | Select-Object -First 1
        if ($sys) { [void]$g.HomeInfo.Children.Add((New-WNGuiDiskTile $sys)) }
    }
    $p.Body = New-WNGuiScroll (New-WNGuiPanel -Orientation Vertical -Children @(
        $top,
        (New-WNGuiText (T 'gui.allTools') -Style Section), $tiles,
        (New-WNGuiText (T 'gui.thisPc') -Style Section), $g.HomeInfo))
    $p.OnShow = { param($p) if ($p.Shown -eq 1) { Update-WNGuiSysInfo } }
}
#endregion

#region Theme and updates
function Set-WNGuiTheme {
    # Light / Dark at any time: brushes, title bar and backdrop tint, every badge, and the switch icon
    param([ValidateSet('Light', 'Dark')][string]$Name, [switch]$Save)
    $g = $script:WNGui
    $t = $script:WNGuiThemes[$Name]
    $g.Theme = $t
    $g.ThemeName = $Name
    foreach ($k in $t.Keys) {
        if ($k -in 'Badges', 'GlassBg', 'Bg') { continue }
        $g.Window.Resources[$k] = [Windows.Media.Brush](ConvertTo-WNBrush $t[$k])
    }
    $g.Window.Resources['Bg'] = [Windows.Media.Brush](ConvertTo-WNBrush $(if ($g.Glass) { $t.GlassBg } else { $t.Bg }))
    if ($g.Hwnd) { try { [WNDwm]::SetDark($g.Hwnd, $Name -eq 'Dark') } catch { } }
    foreach ($l in $g.Lists) { foreach ($r in $l.Rows) { if ($r.Badge -and $r.Kind) { Set-WNGuiBadge $r $r.Badge $r.Kind } } }
    # The button shows the mode it switches to
    $g.Ctl.ThemeBtn.Content = [string][char]$(if ($Name -eq 'Dark') { 0xE706 } else { 0xE708 })
    $tip = T $(if ($Name -eq 'Dark') { 'gui.themeLight' } else { 'gui.themeDark' })
    $g.Ctl.ThemeBtn.ToolTip = $tip
    [Windows.Automation.AutomationProperties]::SetName($g.Ctl.ThemeBtn, $tip)
    if ($Save) { Save-WNSetting 'GuiTheme' $Name }
}

function Set-WNGuiUpdateState {
    # Update pill in the top bar: Idle, Checking, None, Offline or Available (then it opens the update)
    param([string]$State, $Update)
    $g = $script:WNGui
    $g.UpdateState = $State
    $g.Update = $Update
    $c = $g.Ctl
    $c.UpdateBtn.IsEnabled = $State -ne 'Checking'
    $c.UpdateIcon.Text = [string][char]$(switch ($State) { 'None' { 0xE73E } 'Available' { 0xE896 } 'Offline' { 0xE7BA } default { 0xE895 } })
    $c.UpdateText.Text = switch ($State) {
        'Checking'  { T 'gui.updChecking' }
        'None'      { T 'gui.updNone' }
        'Offline'   { T 'gui.updOffline' }
        'Available' { T 'gui.updAvailable' $Update.Version }
        default     { T 'gui.updCheck' }
    }
    if ($State -eq 'Available') {
        $c.UpdateBtn.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'Accent')
        $c.UpdateBtn.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'AccentFg')
    } else {
        $c.UpdateBtn.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'Card')
        $c.UpdateBtn.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, $(if ($State -eq 'None') { 'AccentText' } else { 'Fg' }))
    }
    [Windows.Automation.AutomationProperties]::SetName($c.UpdateBtn, $c.UpdateText.Text)
}

function Start-WNGuiUpdateCheck {
    # Runs in the worker so the window never waits on GitHub. -Startup: an update offers its dialog once,
    # unless that version was skipped; otherwise the pill just shows the result.
    param([switch]$Startup)
    Set-WNGuiUpdateState 'Checking'
    $script:WNGui.AutoOffer = [bool]$Startup
    Start-WNGuiJob -Label (T 'au.checking') -Script { Get-WNUpdateInfo }.ToString() -OnDone {
        param($out)
        $u = $out[0]
        if (-not $u) { Set-WNGuiUpdateState 'Offline'; return }
        if (-not $u.Newer) { Set-WNGuiUpdateState 'None'; return }
        Set-WNGuiUpdateState 'Available' $u
        if ($script:WNGui.AutoOffer -and (Get-WNSettings).SkipVersion -ne $u.Version) { Invoke-WNGuiUpdate }
    }
}

function Invoke-WNGuiUpdate {
    # Release notes in a dialog. Yes = update now, No = keep this version, Cancel = skip this version.
    $g = $script:WNGui
    $u = $g.Update
    $notes = @($u.Notes | Select-Object -First 22) -join "`n"
    $r = [Windows.MessageBox]::Show($g.Window, (T 'au.gui' $u.Version $WN.GuiVersion $notes), 'Winnow', 'YesNoCancel', 'Information')
    if ("$r" -eq 'Cancel') { Save-WNSetting 'SkipVersion' $u.Version; return }
    if ("$r" -ne 'Yes') { return }
    Start-WNGuiJob -Label (T 'au.downloading' $u.Version) -Arguments @($WN.DryRun, $u) -Script { param($dry, $u) $WN.DryRun = $dry; Install-WNUpdate $u }.ToString() -OnDone {
        param($o)
        if ($o[0]) { Restart-WNApp -Gui; $script:WNGui.Window.Close() } else { Show-WNGuiInfo (T 'au.failedGui') }
    }
}
#endregion

function Show-WNGui {
    param([switch]$NoUpdateCheck)
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    if (-not ('WNRow' -as [type])) { Add-Type -TypeDefinition $script:WNGuiTypes }

    # Localize the XAML: @@key@@ -> escaped string
    $xamlText = Get-Content (Join-Path $WN.Root 'gui\MainWindow.xaml') -Raw -Encoding UTF8
    $xamlText = [regex]::Replace($xamlText, '@@([\w.]+)@@', { param($m) [Security.SecurityElement]::Escape((T $m.Groups[1].Value)) })
    $window = [Windows.Markup.XamlReader]::Parse($xamlText)

    $ctl = @{}
    foreach ($n in 'UpdateBtn', 'UpdateIcon', 'UpdateText', 'ThemeBtn', 'LangEn', 'LangEs', 'ShortcutBtn', 'Logo', 'Avatar', 'VersionText', 'AdminText',
                   'SimToggle', 'SimBadge', 'ModeText', 'TerminalBtn', 'NavPanel', 'SearchBox', 'Header', 'ActionsHost', 'PageTitle', 'PageSub',
                   'ToolbarHost', 'BodyHost', 'LogToggle', 'Busy', 'StatusText', 'LogBox') { $ctl[$n] = $window.FindName($n) }

    $script:WNGui = @{
        Window = $window; Ctl = $ctl; Job = $null; Relaunch = $null
        Log = $ctl.LogBox; Status = $ctl.StatusText; Busy = $ctl.Busy; SimToggle = $ctl.SimToggle
        ActionButtons = New-Object 'System.Collections.Generic.List[object]'
        Lists = New-Object 'System.Collections.Generic.List[object]'
        Pages = [ordered]@{}; NavButtons = @{}; SysInfoListeners = @(); Queue = New-Object 'System.Collections.Generic.List[object]'
        Timer = New-Object Windows.Threading.DispatcherTimer
        StartupCheck = -not $NoUpdateCheck
    }
    $g = $script:WNGui
    $g.Timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $g.Timer.Add_Tick({ Receive-WNGuiJob })

    # ---- Theme: the saved choice, else the Windows apps setting
    $saved = (Get-WNSettings).GuiTheme
    $light = (Get-WNRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -ne 0
    $theme = if ($saved -in 'Light', 'Dark') { $saved } elseif ($light) { 'Light' } else { 'Dark' }
    Set-WNGuiTheme $theme

    # ---- Window chrome and identity
    $window.Title = "Winnow $($WN.GuiVersion) $($WN.GuiChannel)"
    $window.Height = [Math]::Min(860, [Windows.SystemParameters]::WorkArea.Height - 20)
    $window.Width = [Math]::Min(1320, [Windows.SystemParameters]::WorkArea.Width - 20)
    $icon = Join-Path $WN.Root 'LOGO\Winnow_icon_128.png'
    if (Test-Path $icon) {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage (New-Object Uri $icon)
        $window.Icon = $bmp
        $ctl.Logo.Source = $bmp
        $ctl.Avatar.Source = $bmp
    }
    $g.WantGlass = $WN.OSBuild -ge 22621
    $window.Add_SourceInitialized({
        $g = $script:WNGui
        $g.Hwnd = (New-Object Windows.Interop.WindowInteropHelper $this).Handle
        try {
            if ($g.WantGlass) {
                [Windows.Interop.HwndSource]::FromHwnd($g.Hwnd).CompositionTarget.BackgroundColor = [Windows.Media.Colors]::Transparent
                $g.Glass = [WNDwm]::Acrylic($g.Hwnd)
            }
        } catch { $g.Glass = $false }
        Set-WNGuiTheme $g.ThemeName
        Write-WNLog "GUI backdrop: acrylic=$([bool]$g.Glass) theme=$($g.ThemeName)" -Component 'Gui'
    })
    $ctl.VersionText.Text = "Winnow $($WN.GuiVersion)"
    $ctl.AdminText.Text = $WN.GuiChannel
    $ctl.ModeText.Text = if ($WN.IsAdmin) { T 'gui.modeAdmin' } else { T 'gui.modeUser' }
    $ctl.SimToggle.IsChecked = $WN.DryRun
    $ctl.SimToggle.IsEnabled = $WN.IsAdmin
    $ctl.SimBadge.Visibility = if ($WN.DryRun) { 'Visible' } else { 'Collapsed' }
    $ctl.SimToggle.Add_Click({
        $WN.DryRun = [bool]$script:WNGui.SimToggle.IsChecked
        $script:WNGui.Ctl.SimBadge.Visibility = if ($WN.DryRun) { 'Visible' } else { 'Collapsed' }
        Write-WNLog "GUI simulation mode: $($WN.DryRun)" -Component 'Gui'
    })
    $ctl.ThemeBtn.Add_Click({ Set-WNGuiTheme $(if ($script:WNGui.ThemeName -eq 'Dark') { 'Light' } else { 'Dark' }) -Save })
    $ctl.TerminalBtn.Add_Click({
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $WN.Root 'Winnow.ps1')`"", '-Lang', $WN.Lang)
        if ($WN.DryRun) { $a += '-DryRun' }
        Start-Process powershell.exe -ArgumentList $a
    })
    # EN | ES: the current language is filled; picking the other one reopens the window in it
    $ctl["Lang$(if ($WN.Lang -eq 'es') { 'Es' } else { 'En' })"].IsChecked = $true
    foreach ($b in $ctl.LangEn, $ctl.LangEs) {
        $b.Add_Checked({
            if ($this.Tag -eq $WN.Lang) { return }
            if ($script:WNGui.Job) { $script:WNGui.Ctl["Lang$(if ($WN.Lang -eq 'es') { 'Es' } else { 'En' })"].IsChecked = $true; return }
            $script:WNGui.Relaunch = $this.Tag
            $script:WNGui.Window.Close()
        })
    }
    $ctl.ShortcutBtn.Add_Click({
        if (New-WNShortcut) { Show-WNGuiInfo $(if ($WN.DryRun) { T 'sc.dryGui' } else { T 'sc.doneGui' }) } else { Show-WNGuiInfo (T 'sc.failedGui') }
    })
    Set-WNGuiUpdateState 'Idle'
    $ctl.UpdateBtn.Add_Click({ if ($script:WNGui.UpdateState -eq 'Available') { Invoke-WNGuiUpdate } else { Start-WNGuiUpdateCheck } })
    $ctl.LogToggle.Add_Click({ $script:WNGui.Log.Visibility = if ($script:WNGui.Ctl.LogToggle.IsChecked) { 'Visible' } else { 'Collapsed' } })
    $ctl.SearchBox.Add_TextChanged({ Update-WNGuiFilter })
    $ctl.SearchBox.Add_KeyDown({
        param($s, $e)
        $p = $script:WNGui.Pages[$script:WNGui.Current]
        if ($e.Key -eq 'Return' -and $p.OnSearch) { & $p.OnSearch }
        if ($e.Key -eq 'Escape') { $this.Text = '' }
    })

    # ---- Pages, grouped like the terminal main menu
    Register-WNGuiPage 'home' 'E80F' '' (T 'gui.navHome') (T 'tagline') ${function:Build-WNGuiHome}
    Register-WNGuiPage 'tweaks' 'E713' 'main.secOptimize' (T 'main.tweaks') (T 'gui.tweaksSub') ${function:Build-WNGuiTweaks} -Hint (T 'main.tweaksHint' @($WN.Config.tweaks | Where-Object Type -ne 'Toggle').Count)
    Register-WNGuiPage 'prefs' 'E771' 'main.secOptimize' (T 'pref.title') (T 'gui.prefsSub') ${function:Build-WNGuiPrefs} -Hint (T 'main.prefsHint')
    Register-WNGuiPage 'services' 'E912' 'main.secOptimize' (T 'main.services') (T 'gui.servicesSub') ${function:Build-WNGuiServices} -Hint (T 'main.servicesHint')
    Register-WNGuiPage 'startup' 'E7E8' 'main.secOptimize' (T 'main.startup') (T 'st.subtitle') ${function:Build-WNGuiStartup} -Hint (T 'main.startupHint')
    Register-WNGuiPage 'apps' 'E71D' 'main.secApps' (T 'main.apps') (T 'gui.appsSub') ${function:Build-WNGuiApps} -Hint (T 'main.appsHint' @($WN.Config.apps).Count)
    Register-WNGuiPage 'uninstall' 'E74D' 'main.secApps' (T 'main.uninstall') (T 'gui.uninstallSub') ${function:Build-WNGuiUninstall} -Hint (T 'main.uninstallHint')
    Register-WNGuiPage 'repair' 'E90F' 'main.secMaintain' (T 'main.repair') (T 'gui.repairSub') ${function:Build-WNGuiRepair} -Hint (T 'main.repairHint')
    Register-WNGuiPage 'updates' 'E895' 'main.secMaintain' (T 'main.updates') (T 'main.updatesHint') ${function:Build-WNGuiUpdates} -Hint (T 'main.updatesHint')
    Register-WNGuiPage 'backups' 'E81C' 'main.secMaintain' (T 'main.backups') (T 'bkm.subtitle') ${function:Build-WNGuiBackups} -Hint (T 'main.backupsHint')
    Register-WNGuiPage 'dns' 'E774' 'main.secNetwork' (T 'main.dns') (T 'dns.subtitle') ${function:Build-WNGuiDns} -Hint (T 'main.dnsHint')
    Register-WNGuiPage 'hosts' 'E72E' 'main.secNetwork' (T 'main.hosts') (T 'main.hostsHint') ${function:Build-WNGuiHosts} -Hint (T 'main.hostsHint')
    Register-WNGuiPage 'system' 'E7F4' 'main.secSystem' (T 'main.info') (T 'main.infoHint') ${function:Build-WNGuiSystem} -Hint (T 'main.infoHint')
    Register-WNGuiPage 'logs' 'E8A5' 'main.secSystem' (T 'main.logs') $WN.LogFile ${function:Build-WNGuiLogs} -Hint (T 'logs.errorsHint')

    $section = $null
    foreach ($pg in $g.Pages.Values) {
        if ($pg.Section -and $pg.Section -ne $section) {
            $section = $pg.Section
            [void]$ctl.NavPanel.Children.Add((New-WNGuiText (T $section).ToUpper() -Style NavHeader))
        }
        $r = New-Object Windows.Controls.RadioButton
        $r.Style = $window.Resources['Nav']
        $r.Tag = [string][char][Convert]::ToInt32($pg.Icon, 16)
        $r.Content = $pg.Title
        $r.Name = "Nav_$($pg.Id)"
        $r.Add_Checked({ $id = $this.Name.Substring(4); if ($script:WNGui.Current -ne $id) { Show-WNGuiPage $id } })
        $g.NavButtons[$pg.Id] = $r
        [void]$ctl.NavPanel.Children.Add($r)
    }

    # ---- Start: worker, home page, then the update check in the background
    $g.Runspace = New-WNGuiWorker
    $window.Add_ContentRendered({
        # Started from a minimized console (Launch-GUI.bat, restarts), Windows hands the window that state too
        if ($this.WindowState -eq 'Minimized') { $this.WindowState = 'Normal' }
        [void]$this.Activate()
        Show-WNGuiPage 'home'
        if ($script:WNGui.StartupCheck) { Start-WNGuiUpdateCheck -Startup }
    })
    $window.Add_Closing({
        param($s, $e)
        $g = $script:WNGui
        if ($g.Job -and [Windows.MessageBox]::Show($g.Window, (T 'gui.busyClose'), 'Winnow', 'YesNo', 'Warning') -ne 'Yes') {
            $e.Cancel = $true; $g.Relaunch = $null; return
        }
        if ($g.Job) { $g.Job.PS.Stop() }
    })

    Write-WNLog 'GUI opened' -Component 'Gui'
    [void]$window.ShowDialog()
    $g.Timer.Stop()
    $g.Runspace.Dispose()
    Write-WNLog 'GUI closed' -Component 'Gui'
    return $g.Relaunch
}
