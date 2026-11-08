# gui/Gui.ps1
# Graphical interface with every module of the terminal edition: a translucent,
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
        Warn = '#FFFFB340'; WarnBg = '#33FF9F0A'; IconBg = '#1AFFFFFF'; IconFg = '#FFFFFFFF'
        Badges = @{ Applied = '#3330D158|#FF7EE2A0'; Partial = '#33FF9F0A|#FFFFD285'; Action = '#330A84FF|#FF9CCBFF'; None = '#26FFFFFF|#FFE5E5EA'; Danger = '#33FF453A|#FFFF9F98' }
    }
    Light = @{
        Bg = '#FFF2F2F7'; GlassBg = '#99F2F2F7'; Pane = '#59FFFFFF'; Card = '#B3FFFFFF'; CardBorder = '#1A000000'; Hover = '#E6FFFFFF'
        Selected = '#1F007AFF'; Fg = '#FF1C1C1E'; FgDim = '#FF5C5C61'; Accent = '#FF0071E3'; AccentSolid = '#FF0071E3'; AccentFg = '#FFFFFFFF'; AccentText = '#FF0060C7'
        Warn = '#FF8F5300'; WarnBg = '#26FF9500'; IconBg = '#0D000000'; IconFg = '#FF1C1C1E'
        Badges = @{ Applied = '#2634C759|#FF1B7A36'; Partial = '#26FF9500|#FF8F5300'; Action = '#1F007AFF|#FF0058B8'; None = '#14000000|#FF3A3A3C'; Danger = '#26FF3B30|#FFB3261E' }
    }
    # Mes patrio (November, Panama): the acrylic tinted Panama navy, fading to deep red at the bottom
    Patria = @{
        Bg = @('#FF0B2A52@0', '#FF0B2A52@0.6', '#FF4A1222@1'); GlassBg = @('#A60B2A52@0', '#A60B2A52@0.55', '#A64A1222@1')
        Pane = '#33000000'; Card = '#1FFFFFFF'; CardBorder = '#26FFFFFF'; Hover = '#30FFFFFF'
        Selected = '#40D21034'; Fg = '#FFFFFFFF'; FgDim = '#FFD3DAE6'; Accent = '#FFD21034'; AccentSolid = '#FFD21034'; AccentFg = '#FFFFFFFF'; AccentText = '#FFFF8C99'
        Warn = '#FFFFB340'; WarnBg = '#33FF9F0A'; IconBg = '#FFFFFFFF'; IconFg = '#FF005293'
        Badges = @{ Applied = '#3330D158|#FF7EE2A0'; Partial = '#33FF9F0A|#FFFFD285'; Action = '#330A84FF|#FF9CCBFF'; None = '#26FFFFFF|#FFE5E5EA'; Danger = '#33FF453A|#FFFF9F98' }
    }
}
$script:WNGuiThemeNames = @('Light', 'Dark', 'Patria')
# Tool icon colours per sidebar group (diagonal gradients, like app icons)
$script:WNGuiArt = @{
    'main.secOptimize' = @('#FFFF9F0A', '#FFFF6B00')
    'main.secApps'     = @('#FFBF5AF2', '#FF7D3CE0')
    'main.secMaintain' = @('#FF30D158', '#FF14A34A')
    'main.secNetwork'  = @('#FF40A9FF', '#FF0A6CFF')
    'main.secSystem'   = @('#FF98989D', '#FF636366')
    'main.secTool'     = @('#FF0A84FF', '#FF5E5CE6')
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
    if ($Line.Trim()) { $g.Status.Text = "$($g.StepPrefix)$($Line.Trim())" }
}

function Set-WNGuiProgress {
    # Batch jobs print "[i/N] name" before each step: the status-bar bar and text follow them
    param([int]$Step, [int]$Total, [string]$Name)
    $g = $script:WNGui
    $g.Busy.IsIndeterminate = $false
    $g.Busy.Maximum = $Total
    $g.Busy.Value = $Step - 1
    $g.StepPrefix = "($Step/$Total)  "
    $g.Status.Text = T 'gui.step' $Step $Total $Name
}

function Set-WNGuiBusy {
    param([bool]$On, [string]$Label)
    $g = $script:WNGui
    $g.Busy.Visibility = if ($On) { 'Visible' } else { 'Collapsed' }
    $g.Busy.IsIndeterminate = $true
    $g.StepPrefix = ''
    foreach ($b in $g.ActionButtons) { $b.IsEnabled = -not $On }
    $g.SimToggle.IsEnabled = (-not $On) -and $WN.IsAdmin
    $g.Status.Text = if ($On) { T 'gui.busy' $Label } else { T 'gui.ready' }
}

function Start-WNGuiJob {
    # Runs $Script in the worker runspace. Write-Host output streams into the log; $OnDone gets the output.
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Script, [object[]]$Arguments = @(), [scriptblock]$OnDone, $NoRp)
    $g = $script:WNGui
    # "No restore point" from the confirmation belongs to the job that confirmation started
    if ($null -eq $NoRp) { $NoRp = [bool]$g.SkipRp; $g.SkipRp = $false }
    # Page loads can be requested while another job runs (action buttons are disabled meanwhile): queue them
    if ($g.Job) { $g.Queue.Add(@{ Label = $Label; Script = $Script; Arguments = $Arguments; OnDone = $OnDone; NoRp = $NoRp }); return }
    $g.Runspace.SessionStateProxy.GetVariable('WN').NoRestorePoint = [bool]($WN.NoRestorePoint -or $NoRp)
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
        if ($job.Line -match '^\s*\[(\d+)/(\d+)\]\s+(.+)$') { Set-WNGuiProgress ([int]$Matches[1]) ([int]$Matches[2]) $Matches[3].Trim() }
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
    # While a restore point is still due this session, real changes offer to skip it for this task:
    # Yes = with restore point, No = without it (the JSON backup is still taken), Cancel = nothing.
    # -Plain: actions that never take one (restore point and backup management).
    param([string]$Message, [switch]$Danger, [switch]$Plain)
    $g = $script:WNGui
    $icon = if ($Danger) { 'Warning' } else { 'Question' }
    $due = $false
    if (-not $Plain -and -not $WN.DryRun -and -not $WN.NoRestorePoint) {
        try { $due = -not $g.Runspace.SessionStateProxy.GetVariable('WN').RestorePointDone } catch { $due = $true }
    }
    if ($due) {
        $r = [Windows.MessageBox]::Show($g.Window, "$Message`n`n$(T 'gui.rpChoice')", 'Winnow', 'YesNoCancel', $icon, 'Cancel')
        $g.SkipRp = ("$r" -eq 'No')
        # A job started by this same click reads it first; if the click starts none, it must not reach a later job
        [void]$g.Window.Dispatcher.BeginInvoke([Action]{ $script:WNGui.SkipRp = $false }, [Windows.Threading.DispatcherPriority]::Background)
        return ("$r" -ne 'Cancel')
    }
    $note = if ($WN.DryRun) { T 'gui.noteSim' } elseif ($Plain) { T 'gui.noteReal' } else { T 'gui.noteBackup' }
    $r = [Windows.MessageBox]::Show($g.Window, "$Message`n`n$note", 'Winnow', 'YesNo', $icon, 'No')
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
            (-not $q -or $r.Item.Query -eq $q -or ("$($r.Name) $($r.Description)").IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0) }.GetNewClosure()
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

function Get-WNGuiBitmap {
    # Read into memory (OnLoad): a file kept open would block the updater from replacing it
    param([string]$File)
    $path = Join-Path $WN.Root "LOGO\$File"
    if (-not (Test-Path $path)) { return $null }
    $b = New-Object Windows.Media.Imaging.BitmapImage
    $b.BeginInit()
    $b.CacheOption = 'OnLoad'
    $b.UriSource = New-Object Uri $path
    $b.EndInit()
    $b.Freeze()
    return $b
}

function New-WNGuiImage {
    param([string]$File, [double]$Size, [double]$Opacity = 1)
    $src = Get-WNGuiBitmap $File
    if (-not $src) { return $null }
    $i = New-Object Windows.Controls.Image
    $i.Source = $src
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
        Start-WNGuiJob -Label (T 'st.title') -Arguments @($WN.DryRun, @($sel | ForEach-Object Item), $enable) -Script {
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
    # Searching all of winget runs in its own runspace, so it never waits behind the window's tasks (opening this page
    # reads the installed apps, which can take a while). Typing searches after a short pause; Enter and the button
    # always search. The list keeps the catalog apps that match and adds every winget result for that text.
    $p.OnSearch = {
        param([switch]$Auto)
        $g = $script:WNGui
        $q = $g.Ctl.SearchBox.Text.Trim()
        if ($q.Length -lt 2) {
            if (-not $Auto) { $g.Status.Text = T 'gui.searchTypeFirst'; [void]$g.Ctl.SearchBox.Focus() }
            return
        }
        if ($Auto -and $q -eq $g.AppSearched) { return }
        $g.AppSearched = $q
        $wg = Find-WNWinget
        if (-not $wg) { Show-WNGuiInfo (T 'apps.noWinget'); return }
        if ($g.WingetSearch) { try { $g.WingetSearch.PS.Stop(); $g.WingetSearch.PS.Dispose() } catch { } }
        $ps = [powershell]::Create()
        [void]$ps.AddScript({
            param($wg, $q)
            $enc = [Console]::OutputEncoding
            try { [Console]::OutputEncoding = [Text.Encoding]::UTF8; & $wg search --query $q --source winget --accept-source-agreements --disable-interactivity 2>$null }
            finally { [Console]::OutputEncoding = $enc }
        }.ToString()).AddArgument($wg).AddArgument($q)
        $g.WingetSearch = @{ PS = $ps; Handle = $ps.BeginInvoke(); Query = $q; Started = Get-Date }
        Add-WNGuiLog "---- $(T 'gui.searchingWinget' $q)"
        $g.Status.Text = T 'gui.searchingWinget' $q
        $g.WingetPoll.Start()
    }
    $g.WingetPoll = New-Object Windows.Threading.DispatcherTimer
    $g.WingetPoll.Interval = [TimeSpan]::FromMilliseconds(200)
    $g.WingetPoll.Add_Tick({
        param($t)
        $g = $script:WNGui
        $s = $g.WingetSearch
        if (-not $s) { $t.Stop(); return }
        if (-not $s.Handle.IsCompleted) {
            # winget can hang on a source update or a prompt; the window stays usable and says so
            if (((Get-Date) - $s.Started).TotalSeconds -gt 60) {
                $t.Stop(); try { $s.PS.Stop(); $s.PS.Dispose() } catch { }; $g.WingetSearch = $null
                $g.Status.Text = T 'gui.searchTimeout' $s.Query; Add-WNGuiLog (T 'gui.searchTimeout' $s.Query)
            }
            return
        }
        $t.Stop()
        $lines = @()
        try { $lines = @($s.PS.EndInvoke($s.Handle) | ForEach-Object { "$_" }) } catch { Add-WNGuiLog "ERROR: $($_.Exception.Message)" }
        $s.PS.Dispose()
        $g.WingetSearch = $null
        $found = @(ConvertFrom-WNWingetTable $lines | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Winget = $_.Id; Choco = 'na'; Description = "v$($_.Version)"; Category = $null; Foss = $false; Query = $s.Query } })
        # A newer search has started meanwhile, or the text changed: that one fills the list
        if ($g.Ctl.SearchBox.Text.Trim() -ne $s.Query) { return }
        $g.Pages['apps'].OnlyBadge = $null
        $catalog = @($WN.Config.apps | Sort-Object Name)
        $known = @{}; foreach ($a in $catalog) { $known[$a.Winget] = $true }
        # Results are already the answer to the query (some match by tag, not by name): they stay visible
        $new = @($found | Where-Object { -not $known[$_.Winget] })
        Set-WNGuiApps @($catalog + $new)
        $msg = if ($found.Count) { T 'gui.wingetFound' $new.Count $s.Query } else { T 'apps.searchNone' $s.Query }
        $g.Status.Text = $msg
        Add-WNGuiLog $msg
    })
    $g.AppSearchTimer = New-Object Windows.Threading.DispatcherTimer
    $g.AppSearchTimer.Interval = [TimeSpan]::FromMilliseconds(800)
    $g.AppSearchTimer.Add_Tick({ param($s) $s.Stop(); if ($script:WNGui.Current -eq 'apps') { & $script:WNGui.Pages['apps'].OnSearch -Auto } })
    $g.Ctl.SearchBox.Add_TextChanged({ $t = $script:WNGui.AppSearchTimer; if ($t -and $script:WNGui.Current -eq 'apps') { $t.Stop(); $t.Start() } })
    Add-WNGuiTools $p @(
        (New-WNGuiSegments 'appsView' @(@{ Text = (T 'gui.catalog'); Value = 'all' }, @{ Text = (T 'gui.installedOnly'); Value = 'installed' }) {
            $g = $script:WNGui
            $g.Pages['apps'].OnlyBadge = if ($this.Tag -eq 'installed') { T 'gui.installed' } else { $null }
            $g.AppSearched = $null
            if ($this.Tag -eq 'all') { Set-WNGuiApps @($WN.Config.apps | Sort-Object Name) } else { Update-WNGuiFilter }
        }),
        (New-WNGuiButton (T 'gui.searchWinget') -Icon 'E721' -OnClick { & $script:WNGui.Pages['apps'].OnSearch }),
        (New-WNGuiButton (T 'apps.listUpgrades') -Icon 'E8FD' -OnClick {
            # Read-only, so it also runs in simulation mode; the list goes to the log panel
            $script:WNGui.Ctl.LogToggle.IsChecked = $true
            $script:WNGui.Log.Visibility = 'Visible'
            Start-WNGuiJob -Label (T 'apps.upgradesTitle') -Script {
                $d = $WN.DryRun; $WN.DryRun = $false
                try { [void](Invoke-WNWinget @('upgrade', '--include-unknown')) } finally { $WN.DryRun = $d }
            }.ToString()
        }),
        $g.AppCount
    )
    $run = {
        $mode = $this.Tag
        $g = $script:WNGui
        if ($mode -eq 'upgrade') {
            Start-WNGuiJob -Label (T 'apps.upgradeTitle') -Arguments @(, $WN.DryRun) -Script {
                param($dry)
                $WN.DryRun = $dry
                if (Start-WNChange -Label 'upgrade all apps' -Apps -SkipRestorePoint) { [void](Invoke-WNWinget @('upgrade', '--all', '--include-unknown', '--accept-package-agreements', '--silent')) }
            }.ToString() -OnDone { Update-WNGuiInstalled }
            return
        }
        $sel = Get-WNGuiSelected $g.AppList.Rows
        if (-not $sel.Count) { return }
        $key = if ($mode -eq 'install') { 'gui.confirmInstall' } else { 'gui.confirmUninstallApps' }
        if (-not (Confirm-WNGui (T $key $sel.Count))) { return }
        Start-WNGuiJob -Label (T $(if ($mode -eq 'install') { 'gui.install' } else { 'gui.uninstallApps' })) -Arguments @($WN.DryRun, @($sel | ForEach-Object Item), $mode) -Script {
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
            Start-WNGuiJob -Label (T 'un.title') -Arguments @($WN.DryRun, @($sel | ForEach-Object Item), $store) -Script {
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
        if (-not (Confirm-WNGui $msg -Danger:$danger -Plain)) { return }
        # Deleting every restore point asks twice, like typing DELETE in the terminal
        if ($mode -eq 'all' -and -not (Confirm-WNGui (T 'gui.reallyAll') -Danger -Plain)) { return }
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
            if (-not (Confirm-WNGui (T 'bkm.restoreAsk' $sel[0].Item.Created) -Plain)) { return }
        } elseif (-not (Confirm-WNGui "$(T 'bkm.delConfirmTitle' $sel.Count)`n`n$(T 'bkm.delWarn')" -Danger -Plain)) { return }
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

# ---- About
function New-WNGuiAboutLines {
    # One text line per entry of a multi-line string; "version - text" lines get the version in bold
    param([string]$Key)
    $rows = foreach ($line in (T $Key) -split "`n") {
        $t = New-WNGuiText '' -Wrap -Size 12.5 -Margin '0,4,0,0'
        $head, $rest = $line -split ' - ', 2
        if ($rest) {
            $b = New-Object Windows.Documents.Run $head
            $b.FontWeight = 'SemiBold'
            $t.Inlines.Add($b)
            $t.Inlines.Add((New-Object Windows.Documents.Run "  $rest"))
        } else { $t.Text = $line }
        $t
    }
    return (New-WNGuiPanel -Orientation Vertical -Children @($rows))
}

function Build-WNGuiAbout {
    param($p)
    $logo = New-WNGuiImage (Get-WNGuiLogoFile) 64
    $script:WNGui.AboutLogo = $logo
    if ($logo) { $logo.Margin = '0,0,18,0' }
    $info = New-WNGuiPanel -Orientation Vertical -Children @(
        (New-WNGuiText $WN.Name -Bold -Size 24),
        (New-WNGuiText (T 'about.byline' $WN.Version $WN.Channel $WN.Author) -Dim -Wrap),
        (New-WNGuiText (T 'tagline') -Dim -Wrap -Margin '0,2,0,0'),
        (New-WNGuiText (T 'brand.madeIn') -Dim -Size 12 -Margin '0,2,0,0'))
    $info.VerticalAlignment = 'Center'
    $repo = New-WNGuiButton (T 'about.repo') -Icon 'E71B' -Always -OnClick { Start-Process $WN.Repo }
    $repo.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($repo, 'Right')
    $head = New-Object Windows.Controls.DockPanel
    [void]$head.Children.Add($repo)
    # Support development: PayPal donation page
    $donate = New-WNGuiButton (T 'about.donate') -Icon 'EB51' -Always -OnClick { Start-Process $WN.Donate }
    $donate.ToolTip = T 'about.donateTip'
    $donate.VerticalAlignment = 'Center'
    $donate.Margin = '0,0,8,0'
    [Windows.Controls.DockPanel]::SetDock($donate, 'Right')
    [void]$head.Children.Add($donate)
    # A DockPanel (not a horizontal StackPanel) gives the text a width, so a long byline wraps instead of running under the buttons
    $id = New-Object Windows.Controls.DockPanel
    if ($logo) { [Windows.Controls.DockPanel]::SetDock($logo, 'Left'); [void]$id.Children.Add($logo) }
    [void]$id.Children.Add($info)
    [void]$head.Children.Add($id)
    $stack = New-WNGuiPanel -Orientation Vertical -Children @(
        (New-WNGuiGlass $head),
        (New-WNGuiCard -Title (T 'about.whatTitle') -Text (T 'about.what') -Icon 'E946'),
        (New-WNGuiCard -Title (T 'about.coreTitle') -Icon 'E950' -Extra (New-WNGuiAboutLines 'about.core')),
        (New-WNGuiCard -Title (T 'about.releasesTitle') -Icon 'E81C' -Extra (New-WNGuiAboutLines 'about.releases')),
        (New-WNGuiCard -Title (T 'about.futureTitle') -Text (T 'about.futureNote') -Icon 'E82F' -Extra (New-WNGuiAboutLines 'about.future'))
    )
    $p.Body = New-WNGuiScroll $stack
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
    # Minimal line icon on a quiet tile, in the theme's icon colours (Panama blue on white for mes patrio)
    $squircle.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'IconBg')
    $icon = New-WNGuiIcon $Page.Icon 21
    $icon.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'IconFg')
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

function New-WNGuiPanamaFlag {
    # The flag of Panama for the Home banner in November (mes patrio): white, red, blue and white quarters,
    # a blue star and a red star
    $star = {
        param([double]$cx, [double]$cy, [double]$r)
        (0..9 | ForEach-Object {
            $rad = if ($_ % 2) { $r * 0.382 } else { $r }
            $a = [Math]::PI * (-90 + 36 * $_) / 180
            '{0:0.#},{1:0.#}' -f ($cx + $rad * [Math]::Cos($a)), ($cy + $rad * [Math]::Sin($a))
        }) -join ' '
    }
    [Windows.Markup.XamlReader]::Parse(@"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='246' Height='164' CornerRadius='12'
        BorderBrush='#66FFFFFF' BorderThickness='3'>
  <Grid>
    <Grid.Clip><RectangleGeometry Rect='0,0,240,158' RadiusX='9' RadiusY='9'/></Grid.Clip>
    <Grid.RowDefinitions><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
    <Canvas Background='White'><Polygon Points='$(& $star 60 39.5 25)' Fill='#FF005293'/></Canvas>
    <Border Grid.Column='1' Background='#FFD21034'/>
    <Border Grid.Row='1' Background='#FF005293'/>
    <Canvas Grid.Row='1' Grid.Column='1' Background='White'><Polygon Points='$(& $star 60 39.5 25)' Fill='#FFD21034'/></Canvas>
  </Grid>
</Border>
"@)
}

function Update-WNGuiHero {
    # Home banner per theme: the blue gradient with the faded mark, or Panama blue with the flag (mes patrio)
    $h = $script:WNGui.Hero
    if (-not $h) { return }
    $patria = $script:WNGui.ThemeName -eq 'Patria'
    $h.Box.Background = [Windows.Media.Brush]$(if ($patria) { ConvertTo-WNBrush '#FF003A70' } else { ConvertTo-WNBrush @('#FF0A84FF', '#FF5E5CE6', '#FFBF5AF2') -Diagonal })
    if ($h.Mark) { $h.Mark.Visibility = if ($patria) { 'Collapsed' } else { 'Visible' } }
    # On a narrow window the flag would sit under the name: it steps aside
    $h.Flag.Visibility = if ($patria -and $h.Box.ActualWidth -ge 640) { 'Visible' } else { 'Collapsed' }
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
    # Background and art follow the theme (Update-WNGuiHero): the faded mark, or the flag for mes patrio
    $heroGrid = New-Object Windows.Controls.Grid
    $mark = New-WNGuiImage 'Winnow_512.png' 230 0.28
    if ($mark) { $mark.HorizontalAlignment = 'Right'; $mark.VerticalAlignment = 'Center'; $mark.Margin = '0,0,40,0'; [void]$heroGrid.Children.Add($mark) }
    $flag = New-WNGuiPanamaFlag
    $flag.HorizontalAlignment = 'Right'
    $flag.VerticalAlignment = 'Center'
    $flag.Margin = '0,0,44,0'
    [void]$heroGrid.Children.Add($flag)
    $g.Hero = @{ Box = $hero; Mark = $mark; Flag = $flag }
    $hero.Add_SizeChanged({ Update-WNGuiHero })
    $chips = New-WNGuiPanel -Children @('main.secOptimize', 'main.secApps', 'main.secMaintain', 'main.secNetwork' | ForEach-Object { New-WNGuiChip (T $_) })
    $chips.VerticalAlignment = 'Top'
    $chips.Margin = '28,24,0,0'
    $title = New-WNGuiText 'Winnow' -Size 56
    $title.FontFamily = 'Segoe UI Variable Display, Segoe UI'
    $title.FontWeight = 'Bold'
    $title.Foreground = 'White'
    $tag = New-WNGuiText (T 'tagline') -Size 16
    $tag.Foreground = 'White'
    $stats = New-WNGuiText "$(T 'gui.heroStats' $tweaks.Count @($WN.Config.apps).Count ($g.Pages.Count - 1))  -  $(T 'brand.madeIn')" -Size 12.5 -Margin '0,10,0,0'
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
# Theme picker: each theme's two colours for its swatch
$script:WNGuiThemeSwatch = @{ Light = @('#FFF3F3F3', '#FF0071E3'); Dark = @('#FF1C1C1E', '#FF0A84FF'); Navidad = @('#FF10301F', '#FFC8102E'); Linux = @('#FF2B2B2B', '#FFE95420'); Patria = @('#FF0B2A52', '#FFD21034') }

function Show-WNGuiThemeFlyout {
    # Theme picker: a panel that unfolds from the theme button inside the window (no separate window); the options
    # slide in one after the other. A click outside it, Esc or a choice folds it back.
    $g = $script:WNGui
    $root = $g.Window.FindName('Root')
    if (-not $g.ThemeFly) {
        $layer = New-Object Windows.Controls.Grid
        $layer.Background = [Windows.Media.Brushes]::Transparent
        $layer.Visibility = 'Collapsed'
        [Windows.Controls.Grid]::SetColumnSpan($layer, 2)
        $panel = New-Object Windows.Controls.Border
        $panel.Width = 250
        $panel.HorizontalAlignment = 'Left'
        $panel.VerticalAlignment = 'Top'
        $panel.CornerRadius = 10
        $panel.BorderThickness = 1
        $panel.Padding = '6'
        $panel.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
        $panel.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 24; ShadowDepth = 6; Opacity = 0.3; Direction = 270 }
        $panel.RenderTransformOrigin = '1,0'
        $scale = New-Object Windows.Media.ScaleTransform 1, 1
        $panel.RenderTransform = $scale
        $stack = New-Object Windows.Controls.StackPanel
        $panel.Child = $stack
        [void]$layer.Children.Add($panel)
        $layer.Add_MouseLeftButtonDown({ param($s, $e) if ($e.OriginalSource -eq $s) { Hide-WNGuiThemeFlyout } })
        $layer.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { Hide-WNGuiThemeFlyout; $e.Handled = $true } })
        [void]$root.Children.Add($layer)
        $style = [Windows.Markup.XamlReader]::Parse(@'
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" TargetType="Button">
  <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
  <Setter Property="Cursor" Value="Hand"/>
  <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
  <Setter Property="Template">
    <Setter.Value>
      <ControlTemplate TargetType="Button">
        <Border x:Name="bd" CornerRadius="6" Background="Transparent" Padding="10,8"><ContentPresenter/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource Hover}"/></Trigger>
          <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="Background" Value="{DynamicResource Hover}"/></Trigger>
        </ControlTemplate.Triggers>
      </ControlTemplate>
    </Setter.Value>
  </Setter>
</Style>
'@)
        $g.ThemeFly = @{ Layer = $layer; Panel = $panel; Stack = $stack; Scale = $scale; Style = $style }
    }
    $f = $g.ThemeFly
    if ($f.Layer.Visibility -eq 'Visible') { Hide-WNGuiThemeFlyout; return }
    # Opaque in the current theme, its top-right corner under the button
    $f.Panel.Background = [Windows.Media.Brush](ConvertTo-WNBrush $(if ($g.ThemeName -eq 'Light') { '#FFF9F9FB' } else { '#FA26282C' }))
    $btn = $g.Ctl.ThemeBtn
    $pt = $btn.TranslatePoint((New-Object Windows.Point $btn.ActualWidth, ($btn.ActualHeight + 6)), $root)
    $f.Panel.Margin = "$([Math]::Max(8, $pt.X - 250)),$($pt.Y),0,0"
    $f.Stack.Children.Clear()
    $ease = New-Object Windows.Media.Animation.CubicEase
    $i = 0
    foreach ($n in $script:WNGuiThemeNames) {
        $b = New-Object Windows.Controls.Button
        $b.Style = $f.Style
        $b.Tag = $n
        $c = $script:WNGuiThemeSwatch[$n]
        $sw = New-Object Windows.Shapes.Ellipse
        $sw.Width = 18; $sw.Height = 18
        $sw.Margin = '0,0,12,0'
        $sw.Fill = [Windows.Media.Brush](ConvertTo-WNBrush @("$($c[0])@0", "$($c[0])@0.5", "$($c[1])@0.5", "$($c[1])@1") -Diagonal)
        $sw.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'CardBorder')
        $check = New-WNGuiIcon 'E73E' 12 -Accent
        $check.Visibility = if ($g.ThemeName -eq $n) { 'Visible' } else { 'Hidden' }
        $dock = New-Object Windows.Controls.DockPanel
        [Windows.Controls.DockPanel]::SetDock($check, 'Right')
        [void]$dock.Children.Add($check)
        [void]$dock.Children.Add($sw)
        [void]$dock.Children.Add((New-WNGuiText (T "gui.themeOpt$n") -Size 13.5))
        $b.Content = $dock
        [Windows.Automation.AutomationProperties]::SetName($b, (T "gui.themeOpt$n"))
        $b.Add_Click({ $n = $this.Tag; Hide-WNGuiThemeFlyout; Set-WNGuiTheme $n -Save })
        # Each option slides in a little after the one above it
        $b.Opacity = 0
        $shift = New-Object Windows.Media.TranslateTransform 16, 0
        $b.RenderTransform = $shift
        $d = [Windows.Duration][TimeSpan]::FromMilliseconds(280)
        $fa = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, $d
        $sa = New-Object Windows.Media.Animation.DoubleAnimation 16, 0, $d
        foreach ($a in $fa, $sa) { $a.BeginTime = [TimeSpan]::FromMilliseconds(80 + 50 * $i); $a.EasingFunction = $ease }
        $b.BeginAnimation([Windows.UIElement]::OpacityProperty, $fa)
        $shift.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $sa)
        [void]$f.Stack.Children.Add($b)
        $i++
    }
    $f.Layer.Visibility = 'Visible'
    # The panel unfolds from the button: it grows out of its top-right corner while it fades in
    $d = [Windows.Duration][TimeSpan]::FromMilliseconds(260)
    $fade = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds(180))
    $sx = New-Object Windows.Media.Animation.DoubleAnimation 0.7, 1, $d
    $sy = New-Object Windows.Media.Animation.DoubleAnimation 0.2, 1, $d
    $sx.EasingFunction = $ease; $sy.EasingFunction = $ease
    $f.Panel.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
    $f.Scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $sx)
    $f.Scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $sy)
    $current = @($f.Stack.Children | Where-Object { $_.Tag -eq $g.ThemeName }) + @($f.Stack.Children) | Select-Object -First 1
    [void]$current.Focus()
}

function Hide-WNGuiThemeFlyout {
    $f = $script:WNGui.ThemeFly
    if (-not $f -or $f.Layer.Visibility -ne 'Visible') { return }
    $d = [Windows.Duration][TimeSpan]::FromMilliseconds(140)
    $out = New-Object Windows.Media.Animation.DoubleAnimation 0, $d
    $out.Add_Completed({ $script:WNGui.ThemeFly.Layer.Visibility = 'Collapsed' })
    $f.Panel.BeginAnimation([Windows.UIElement]::OpacityProperty, $out)
    $s = New-Object Windows.Media.Animation.DoubleAnimation 0.92, $d
    $f.Scale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $s)
}

function Set-WNGuiTheme {
    # Light / Dark at any time: brushes, title bar and backdrop tint, every badge, and the switch icon
    param([ValidateSet('Light', 'Dark', 'Patria')][string]$Name, [switch]$Save)
    $g = $script:WNGui
    $t = $script:WNGuiThemes[$Name]
    $g.Theme = $t
    $g.ThemeName = $Name
    foreach ($k in $t.Keys) {
        if ($k -in 'Badges', 'GlassBg', 'Bg') { continue }
        $g.Window.Resources[$k] = [Windows.Media.Brush](ConvertTo-WNBrush $t[$k])
    }
    $g.Window.Resources['Bg'] = [Windows.Media.Brush](ConvertTo-WNBrush $(if ($g.Glass) { $t.GlassBg } else { $t.Bg }))
    if ($g.Hwnd) { try { [WNDwm]::SetDark($g.Hwnd, $Name -ne 'Light') } catch { } }
    foreach ($l in $g.Lists) { foreach ($r in $l.Rows) { if ($r.Badge -and $r.Kind) { Set-WNGuiBadge $r $r.Badge $r.Kind } } }
    # The button shows the current theme and opens the theme menu
    $g.Ctl.ThemeBtn.Content = [string][char]$(switch ($Name) { 'Light' { 0xE706 } 'Dark' { 0xE708 } default { 0xE7C1 } })
    $tip = T 'gui.themeTip' (T "gui.themeOpt$Name")
    $g.Ctl.ThemeBtn.ToolTip = $tip
    [Windows.Automation.AutomationProperties]::SetName($g.Ctl.ThemeBtn, $tip)
    # Logo for this theme (the Panama one for mes patrio), also as the window icon
    $file = Get-WNGuiLogoFile
    if (-not $g.LogoCache) { $g.LogoCache = @{} }
    if (-not $g.LogoCache[$file]) { $g.LogoCache[$file] = Get-WNGuiBitmap $file }
    $logo = $g.LogoCache[$file]
    foreach ($img in @($g.Ctl.Logo, $g.Ctl.Avatar, $g.AboutLogo)) { if ($img -and $logo) { $img.Source = $logo } }
    if ($logo) { $g.Window.Icon = $logo }
    Update-WNGuiHero
    if ($Save) { Save-WNSetting 'GuiTheme' $Name }
}

function Get-WNGuiLogoFile { switch ($script:WNGui.ThemeName) { 'Patria' { 'Winnow_128_patria.png' } 'Light' { 'Winnow_128.png' } default { 'Winnow_128.png' } } }

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
    # Runs in the worker so the window never waits on GitHub. -Show: the update panel follows the whole check
    # (button in the top bar). -Startup: quiet; an update opens the panel once, unless that version was skipped.
    param([switch]$Startup, [switch]$Show)
    $g = $script:WNGui
    Set-WNGuiUpdateState 'Checking'
    $g.AutoOffer = [bool]$Startup
    $g.UpdShow = [bool]$Show
    if ($Show) { Show-WNGuiUpdatePanel 'checking' }
    Start-WNGuiJob -Label (T 'au.checking') -Script { Get-WNUpdateInfo }.ToString() -OnDone {
        param($out)
        $g = $script:WNGui
        $u = $out[0]
        if (-not $u) { Set-WNGuiUpdateState 'Offline'; if ($g.UpdShow) { Show-WNGuiUpdatePanel 'offline' }; return }
        if (-not $u.Newer) { Set-WNGuiUpdateState 'None'; if ($g.UpdShow) { Show-WNGuiUpdatePanel 'none' }; return }
        Set-WNGuiUpdateState 'Available' $u
        if ($g.UpdShow -or ($g.AutoOffer -and (Get-WNSettings).SkipVersion -ne $u.Version)) { Show-WNGuiUpdatePanel 'available' }
    }
}

function New-WNGuiUpdatePanel {
    # A dimmed layer over the whole window with one centred card: animation, title, text, notes, buttons
    $g = $script:WNGui
    $layer = New-Object Windows.Controls.Grid
    $layer.Background = [Windows.Media.Brush](ConvertTo-WNBrush '#8C000000')
    $layer.Visibility = 'Collapsed'
    [Windows.Controls.Panel]::SetZIndex($layer, 100)
    [Windows.Controls.Grid]::SetRowSpan($layer, 99)
    [Windows.Controls.Grid]::SetColumnSpan($layer, 99)
    $card = New-Object Windows.Controls.Border
    $card.Width = 540
    $card.CornerRadius = 20
    $card.Padding = '36,30'
    $card.HorizontalAlignment = 'Center'
    $card.VerticalAlignment = 'Center'
    $card.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ BlurRadius = 40; ShadowDepth = 6; Opacity = 0.35 }

    # Art: a spinning ring (checking, installing) or one glyph; the download arrow bobs while downloading
    $art = New-Object Windows.Controls.Grid
    $art.Width = 96; $art.Height = 96; $art.Margin = '0,0,0,18'
    $ring = New-Object Windows.Shapes.Ellipse
    $ring.StrokeThickness = 7; $ring.Opacity = 0.18
    $ring.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'AccentText')
    $arc = New-Object Windows.Shapes.Path
    $arc.Data = [Windows.Media.Geometry]::Parse('M 48,3.5 A 44.5,44.5 0 0 1 92.5,48')
    $arc.StrokeThickness = 7; $arc.StrokeStartLineCap = 'Round'; $arc.StrokeEndLineCap = 'Round'
    $arc.SetResourceReference([Windows.Shapes.Shape]::StrokeProperty, 'AccentText')
    $spin = New-Object Windows.Media.RotateTransform 0, 48, 48
    $arc.RenderTransform = $spin
    $anim = New-Object Windows.Media.Animation.DoubleAnimation 0, 360, ([Windows.Duration][TimeSpan]::FromSeconds(0.9))
    $anim.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $spin.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $anim)
    $spinner = New-Object Windows.Controls.Grid
    [void]$spinner.Children.Add($ring); [void]$spinner.Children.Add($arc)
    $glyph = New-WNGuiIcon 'E896' 56
    $glyph.HorizontalAlignment = 'Center'
    $bob = New-Object Windows.Media.TranslateTransform
    $glyph.RenderTransform = $bob
    [void]$art.Children.Add($spinner); [void]$art.Children.Add($glyph)

    $title = New-WNGuiText '' -Bold -Size 28 -Wrap
    $title.TextAlignment = 'Center'
    $text = New-WNGuiText '' -Dim -Size 14 -Wrap -Margin '0,8,0,0'
    $text.TextAlignment = 'Center'
    $notesText = New-WNGuiText '' -Size 12.5 -Wrap
    $notes = New-Object Windows.Controls.ScrollViewer
    $notes.MaxHeight = 210; $notes.VerticalScrollBarVisibility = 'Auto'; $notes.Content = $notesText
    $notesBox = New-Object Windows.Controls.Border
    $notesBox.CornerRadius = 12; $notesBox.Padding = '14,10'; $notesBox.Margin = '0,18,0,0'
    $notesBox.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Card')
    $notesBox.Child = $notes
    $bar = New-Object Windows.Controls.ProgressBar
    $bar.IsIndeterminate = $true; $bar.Height = 6; $bar.Width = 320; $bar.Margin = '0,22,0,0'; $bar.BorderThickness = 0
    $bar.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'AccentSolid')
    $bar.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'Card')
    $buttons = New-WNGuiPanel
    $buttons.HorizontalAlignment = 'Center'; $buttons.Margin = '0,24,0,0'

    $stack = New-WNGuiPanel -Orientation Vertical -Children @($art, $title, $text, $notesBox, $bar, $buttons)
    $card.Child = $stack
    [void]$layer.Children.Add($card)
    [void]$g.Window.FindName('Root').Children.Add($layer)
    $g.Upd = @{ Layer = $layer; Card = $card; Spinner = $spinner; Glyph = $glyph; Bob = $bob; Title = $title; Text = $text
                Notes = $notesBox; NotesText = $notesText; Bar = $bar; Buttons = $buttons }
}

function Show-WNGuiUpdatePanel {
    # States: checking, none, offline, available, dry, downloading, ready, installing, failed
    param([string]$State)
    $g = $script:WNGui
    if (-not $g.Upd) { New-WNGuiUpdatePanel }
    $p = $g.Upd
    $u = $g.Update
    $p.Card.Background = [Windows.Media.Brush](ConvertTo-WNBrush $g.Theme.Bg)
    $p.Layer.Visibility = 'Visible'
    $busy = $State -in 'checking', 'installing'
    $p.Spinner.Visibility = if ($busy) { 'Visible' } else { 'Collapsed' }
    $p.Glyph.Visibility = if ($busy) { 'Collapsed' } else { 'Visible' }
    $p.Glyph.Text = [string][char]$(switch ($State) { 'none' { 0xE73E } 'ready' { 0xE72C } 'dry' { 0xE946 } { $_ -in 'offline', 'failed' } { 0xE7BA } default { 0xE896 } })
    $p.Glyph.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($State -in 'offline', 'failed') { 'Warn' } else { 'AccentText' }))
    $bobbing = New-Object Windows.Media.Animation.DoubleAnimation -6, 6, ([Windows.Duration][TimeSpan]::FromSeconds(0.55))
    $bobbing.AutoReverse = $true; $bobbing.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
    $p.Bob.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $(if ($State -eq 'downloading') { $bobbing } else { $null }))
    $ver = if ($u) { $u.Version } else { '' }
    $p.Title.Text = switch ($State) {
        'checking' { T 'upd2.checking' } 'none' { T 'upd2.none' } 'offline' { T 'upd2.offline' } 'available' { T 'upd2.available' }
        'dry' { T 'upd2.available' } 'downloading' { T 'upd2.downloading' $ver } 'ready' { T 'upd2.ready' }
        'installing' { T 'upd2.installing' } default { T 'upd2.failed' }
    }
    $p.Text.Text = switch ($State) {
        'checking' { T 'upd2.checkingSub' } 'none' { T 'au.upToDate' $WN.GuiVersion } 'offline' { T 'upd2.offlineSub' }
        'available' { T 'upd2.availableSub' $ver $WN.GuiVersion } 'dry' { T 'upd2.drySub' $ver }
        'downloading' { T 'upd2.downloadingSub' } 'ready' { T 'upd2.readySub' $ver $WN.GuiVersion }
        'installing' { T 'upd2.installingSub' $ver } default { T 'upd2.failedSub' $WN.GuiVersion }
    }
    $p.Notes.Visibility = if ($State -eq 'available' -and $u.Notes) { 'Visible' } else { 'Collapsed' }
    if ($State -eq 'available') { $p.NotesText.Text = (@($u.Notes | Select-Object -First 40) -join "`n").Trim() }
    $p.Bar.Visibility = if ($State -in 'downloading', 'installing') { 'Visible' } else { 'Collapsed' }
    $p.Buttons.Children.Clear()
    $btn = { param($key, $do, [switch]$Accent) $b = New-WNGuiButton (T $key) -Accent:$Accent -Always -OnClick $do; $b.Margin = '6,0'; [void]$p.Buttons.Children.Add($b) }
    switch ($State) {
        'available' {
            & $btn 'upd2.update' { Start-WNGuiUpdateDownload } -Accent
            & $btn 'upd2.notNow' { Hide-WNGuiUpdatePanel }
            & $btn 'upd2.skip' { Save-WNSetting 'SkipVersion' $script:WNGui.Update.Version; Hide-WNGuiUpdatePanel }
        }
        'ready' {
            & $btn 'upd2.restartNow' { Start-WNGuiUpdateInstall } -Accent
            & $btn 'upd2.later' {
                # Later: this version keeps running; the download is thrown away and offered again next time
                $g = $script:WNGui
                if ($g.UpdStaged) { Remove-Item -LiteralPath $g.UpdStaged.Path -Recurse -Force -ErrorAction SilentlyContinue; $g.UpdStaged = $null }
                Hide-WNGuiUpdatePanel
            }
        }
        { $_ -in 'none', 'offline', 'failed', 'dry' } { & $btn 'upd2.close' { Hide-WNGuiUpdatePanel } -Accent }
    }
}

function Hide-WNGuiUpdatePanel { if ($script:WNGui.Upd) { $script:WNGui.Upd.Layer.Visibility = 'Collapsed' } }

function Start-WNGuiUpdateDownload {
    # Step 1: download and unpack in the worker; this copy is not touched until "Restart now"
    $g = $script:WNGui
    $u = $g.Update
    if ($WN.DryRun) { Show-WNGuiUpdatePanel 'dry'; return }
    Show-WNGuiUpdatePanel 'downloading'
    Start-WNGuiJob -Label (T 'au.downloading' $u.Version) -Arguments @(, $u) -Script { param($u) Save-WNUpdate $u }.ToString() -OnDone {
        param($o)
        $st = @($o | Where-Object { $_.Path -and $_.Hashes }) | Select-Object -Last 1
        if ($st -and (Test-Path -LiteralPath $st.Path)) { $script:WNGui.UpdStaged = $st; Show-WNGuiUpdatePanel 'ready' } else { Show-WNGuiUpdatePanel 'failed' }
    }
}

function Start-WNGuiUpdateInstall {
    # Step 2 (Restart now): swap the files, then this window closes and the updated Winnow opens
    $g = $script:WNGui
    Show-WNGuiUpdatePanel 'installing'
    Start-WNGuiJob -Label (T 'upd2.installing') -Arguments @($WN.DryRun, $g.Update, $g.UpdStaged) -Script {
        param($dry, $u, $dir) $WN.DryRun = $dry; Install-WNUpdate -Update $u -Staged $dir
    }.ToString() -OnDone {
        param($o)
        $g = $script:WNGui
        $g.UpdStaged = $null
        if (@($o)[-1] -eq $true) { $WN.Handoff = $true; Restart-WNApp -Gui; $g.Window.Close() } else { Show-WNGuiUpdatePanel 'failed' }
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

    # ---- Theme: the saved choice; in November (Panama's patriotic month) mes patrio; else the Windows apps setting
    $saved = (Get-WNSettings).GuiTheme
    $light = (Get-WNRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -ne 0
    $theme = if ($saved -in 'Light', 'Dark', 'Patria') { $saved } elseif ((Get-Date).Month -eq 11) { 'Patria' } elseif ($light) { 'Light' } else { 'Dark' }
    Set-WNGuiTheme $theme

    # ---- Window chrome and identity
    $window.Title = "Winnow $($WN.GuiVersion) $($WN.GuiChannel)"
    $window.Height = [Math]::Min(860, [Windows.SystemParameters]::WorkArea.Height - 20)
    $window.Width = [Math]::Min(1320, [Windows.SystemParameters]::WorkArea.Width - 20)
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
    # Theme picker: unfolds from the button, inside the window
    $ctl.ThemeBtn.Add_Click({ Show-WNGuiThemeFlyout })
    # The name pill in the top bar opens About
    $window.FindName('IdentityPill').Add_MouseLeftButtonUp({ Show-WNGuiPage 'about' })
    $ctl.TerminalBtn.Add_Click({
        Start-Process powershell.exe -ArgumentList (Get-WNLaunchArgs Terminal -NoUpdateCheck)
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
    $ctl.UpdateBtn.Add_Click({ if ($script:WNGui.UpdateState -eq 'Available') { Show-WNGuiUpdatePanel 'available' } else { Start-WNGuiUpdateCheck -Show } })
    $ctl.LogToggle.Add_Click({ $script:WNGui.Log.Visibility = if ($script:WNGui.Ctl.LogToggle.IsChecked) { 'Visible' } else { 'Collapsed' } })
    $ctl.SearchBox.Add_TextChanged({ Update-WNGuiFilter })
    # A click in the search box selects what is there, so typing replaces it
    $ctl.SearchBox.Add_GotKeyboardFocus({ $this.SelectAll() })
    $ctl.SearchBox.Add_PreviewMouseLeftButtonDown({ param($s, $e) if (-not $s.IsKeyboardFocusWithin) { [void]$s.Focus(); $e.Handled = $true } })
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
    Register-WNGuiPage 'about' 'E946' 'main.secTool' (T 'about.title') (T 'about.subtitle') ${function:Build-WNGuiAbout} -Hint (T 'about.subtitle')

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
        # Started from a minimized console (mode choice, restarts), Windows hands the window that state too
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
        if ($g.UpdStaged) { Remove-Item -LiteralPath $g.UpdStaged.Path -Recurse -Force -ErrorAction SilentlyContinue; $g.UpdStaged = $null }
        # Not when the window only reopens (language) or hands over to the updated copy
        if (-not $g.Relaunch -and -not $WN.Handoff -and -not $g.ExitAsked) { $g.ExitAsked = $true; Show-WNExitPrompt -Gui -Owner $this }
    })

    Write-WNLog 'GUI opened' -Component 'Gui'
    [void]$window.ShowDialog()
    $g.Timer.Stop()
    $g.Runspace.Dispose()
    Write-WNLog 'GUI closed' -Component 'Gui'
    return $g.Relaunch
}
