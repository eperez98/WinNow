# gui/Gui.ps1
# Graphical interface (preview). A WPF window in the Windows 11 style on top of the same engine:
# every change runs in a background runspace that loads core/ and modules/ like the terminal does,
# so restore points, backups, undo and simulation mode behave exactly the same.

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
    public object Item { get; set; }
    public bool Selected { get { return selected; } set { selected = value; Notify("Selected"); } }
    public string Badge { get { return badge; } set { badge = value; Notify("Badge"); Notify("BadgeVisibility"); } }
    public object BadgeBg { get { return badgeBg; } set { badgeBg = value; Notify("BadgeBg"); } }
    public object BadgeFg { get { return badgeFg; } set { badgeFg = value; Notify("BadgeFg"); } }
    public string BadgeVisibility { get { return String.IsNullOrEmpty(badge) ? "Collapsed" : "Visible"; } }
}

public static class WNDwm {
    [DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    // 20 = DWMWA_USE_IMMERSIVE_DARK_MODE: dark title bar to match the dark theme
    public static void DarkTitle(IntPtr hwnd, bool dark) { int v = dark ? 1 : 0; DwmSetWindowAttribute(hwnd, 20, ref v, 4); }
}
'@

$script:WNGuiThemes = @{
    Dark  = @{ Bg = '#202020'; Pane = '#1C1C1C'; Card = '#2B2B2B'; CardBorder = '#3A3A3A'; Fg = '#FFFFFF'; FgDim = '#A8A8A8'
               Hover = '#323232'; Selected = '#383838'; Accent = '#34D399'; AccentFg = '#062B1F'; AccentText = '#34D399'
               Badges = @{ Applied = '#064E3B|#A7F3D0'; Partial = '#78350F|#FDE68A'; Action = '#1E3A8A|#BFDBFE'; None = '#383838|#C8C8C8' } }
    Light = @{ Bg = '#F3F3F3'; Pane = '#EBEBEB'; Card = '#FFFFFF'; CardBorder = '#E0E0E0'; Fg = '#1B1B1B'; FgDim = '#5C5C5C'
               Hover = '#F5F5F5'; Selected = '#E0E0E0'; Accent = '#047857'; AccentFg = '#FFFFFF'; AccentText = '#047857'
               Badges = @{ Applied = '#D1FAE5|#065F46'; Partial = '#FEF3C7|#92400E'; Action = '#DBEAFE|#1E40AF'; None = '#EBEBEB|#4A4A4A' } }
}

function ConvertTo-WNBrush { param([string]$Hex) (New-Object Windows.Media.BrushConverter).ConvertFromString($Hex) }

function Set-WNGuiBadge {
    param([Parameter(Mandatory)]$Row, [string]$Text, [string]$Kind)
    $bg, $fg = $script:WNGui.Theme.Badges[$Kind] -split '\|'
    $Row.Badge = $Text
    $Row.BadgeBg = ConvertTo-WNBrush $bg
    $Row.BadgeFg = ConvertTo-WNBrush $fg
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
    # Runs $Script in the worker runspace. Write-Host output streams into the log; $OnDone gets the result.
    param([Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][string]$Script, [object[]]$Arguments = @(), [scriptblock]$OnDone)
    $g = $script:WNGui
    if ($g.Job) { return }
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
    }.ToString()).AddArgument($WN.Root).AddArgument($WN.DryRun).AddArgument($WN.Lang).AddArgument($WN.NoRestorePoint)
    [void]$ps.Invoke()
    foreach ($e in $ps.Streams.Error) { Write-WNLog "GUI worker init: $e" -Level ERROR -Component 'Gui' }
    $ps.Dispose()
    return $rs
}

function Confirm-WNGui {
    param([string]$Message)
    $note = if ($WN.DryRun) { T 'gui.noteSim' } else { T 'gui.noteReal' }
    $r = [Windows.MessageBox]::Show($script:WNGui.Window, "$Message`n`n$note", 'Winnow', 'YesNo', 'Question')
    return ($r -eq 'Yes')
}

function Get-WNGuiSelected { param($Rows) @($Rows | Where-Object Selected) }

function Update-WNGuiTweakStates {
    $g = $script:WNGui
    Start-WNGuiJob -Label (T 'gui.loading') -Script {
        $s = @{}
        foreach ($t in $WN.Config.tweaks) { $s[$t.Key] = Get-WNTweakState $t }
        $s
    }.ToString() -OnDone {
        param($out)
        $states = $out[0]
        foreach ($r in $script:WNGui.TweakRows) {
            $st = $states[$r.Key]
            $kind = switch ($st) { 'Applied' { 'Applied' } 'Partial' { 'Partial' } 'Action' { 'Action' } default { 'None' } }
            $key = switch ($st) { 'Applied' { 'gui.stApplied' } 'Partial' { 'gui.stPartial' } 'Action' { 'gui.stAction' } 'NotApplied' { 'gui.stNot' } default { 'gui.stUnknown' } }
            Set-WNGuiBadge $r (T $key) $kind
        }
    }
}

function Invoke-WNGuiTweaks {
    param([switch]$Undo)
    $g = $script:WNGui
    $sel = Get-WNGuiSelected $g.TweakRows
    if (-not $sel.Count) { [void][Windows.MessageBox]::Show($g.Window, (T 'gui.noneSelected'), 'Winnow'); return }
    if (-not (Confirm-WNGui (T $(if ($Undo) { 'gui.confirmUndo' } else { 'gui.confirmApply' }) $sel.Count))) { return }
    $label = if ($Undo) { T 'gui.undo' } else { T 'gui.apply' }
    Start-WNGuiJob -Label $label -Arguments @($WN.DryRun, @($sel.Key), [bool]$Undo) -Script {
        param($dry, $keys, $undo)
        $WN.DryRun = $dry
        Invoke-WNTweakBatch -Tweaks @($keys | ForEach-Object { Get-WNTweak $_ }) -Undo:$undo
    }.ToString() -OnDone {
        foreach ($r in $script:WNGui.TweakRows) { $r.Selected = $false }
        Update-WNGuiTweakStates
    }
}

function Set-WNGuiApps {
    # Fills the apps list with catalog apps or winget search results (same object shape)
    param([object[]]$Apps)
    $g = $script:WNGui
    $rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    foreach ($a in $Apps) {
        $r = New-Object WNRow -Property @{ Key = $a.Winget; Name = $a.Name; Item = $a
            # Catalog apps have a category and a text description; winget results only a version
            Description = $(if ($a.Category) { "$($a.Description)  -  $($a.Winget)" } else { "$($a.Winget)  $($a.Description)" }) }
        if ($a.Foss) { Set-WNGuiBadge $r 'FOSS' 'Applied' } elseif ($a.Category) { Set-WNGuiBadge $r $a.Category 'None' }
        $rows.Add($r)
    }
    $g.AppRows = $rows
    $g.AppList.ItemsSource = $rows
    $g.AppView = [Windows.Data.CollectionViewSource]::GetDefaultView($rows)
    $g.AppCount.Text = T 'gui.results' $rows.Count
}

function Show-WNGuiPage {
    param([string]$Name)
    $g = $script:WNGui
    foreach ($p in 'Home', 'Tweaks', 'Apps', 'Next') { $g.Ctl["Page$p"].Visibility = if ($p -eq $Name) { 'Visible' } else { 'Collapsed' } }
    $g.Ctl["Nav$Name"].IsChecked = $true
}

function Show-WNGui {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    if (-not ('WNRow' -as [type])) { Add-Type -TypeDefinition $script:WNGuiTypes }

    $light = (Get-WNRegistryValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -ne 0
    $theme = $script:WNGuiThemes[$(if ($light) { 'Light' } else { 'Dark' })]

    # Localize the XAML: @@key@@ -> escaped string
    $xamlText = Get-Content (Join-Path $WN.Root 'gui\MainWindow.xaml') -Raw -Encoding UTF8
    $xamlText = [regex]::Replace($xamlText, '@@([\w.]+)@@', { param($m) [Security.SecurityElement]::Escape((T $m.Groups[1].Value)) })
    $window = [Windows.Markup.XamlReader]::Parse($xamlText)

    foreach ($k in $theme.Keys) { if ($k -ne 'Badges') { $window.Resources[$k] = ConvertTo-WNBrush $theme[$k] } }
    $ctl = @{}
    foreach ($n in 'Logo', 'VersionText', 'SimToggle', 'ModeText', 'LangBtn', 'TerminalBtn', 'NavHome', 'NavTweaks', 'NavApps', 'NavNext',
                   'PageHome', 'PageTweaks', 'PageApps', 'PageNext', 'InfoPanel', 'QuickTweaks', 'QuickApps', 'QuickAppsHint', 'QuickTerminal',
                   'UndoBtn', 'ApplyBtn', 'TweakFilter', 'PresetMinimal', 'PresetStandard', 'PresetHeavy', 'PresetClear', 'TweakList',
                   'InstallBtn', 'AppQuery', 'SearchBtn', 'CatalogBtn', 'AppCount', 'AppList', 'NextList', 'RepoBtn',
                   'LogToggle', 'Busy', 'StatusText', 'LogBox') {
        $ctl[$n] = $window.FindName($n)
    }

    $script:WNGui = @{
        Window = $window; Ctl = $ctl; Theme = $theme; Job = $null; Relaunch = $null
        Log = $ctl.LogBox; Status = $ctl.StatusText; Busy = $ctl.Busy; SimToggle = $ctl.SimToggle; AppList = $ctl.AppList; AppCount = $ctl.AppCount
        ActionButtons = @($ctl.ApplyBtn, $ctl.UndoBtn, $ctl.InstallBtn, $ctl.SearchBtn, $ctl.PresetMinimal, $ctl.PresetStandard, $ctl.PresetHeavy, $ctl.LangBtn)
        Timer = New-Object Windows.Threading.DispatcherTimer
    }
    $g = $script:WNGui
    $g.Timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $g.Timer.Add_Tick({ Receive-WNGuiJob })

    # ---- Window chrome
    $window.Title = "Winnow $($WN.Version)"
    $icon = Join-Path $WN.Root 'LOGO\Winnow_icon_128.png'
    if (Test-Path $icon) {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage (New-Object Uri $icon)
        $window.Icon = $bmp
        $ctl.Logo.Source = $bmp
    }
    $g.Dark = -not $light
    $window.Add_SourceInitialized({
        try { [WNDwm]::DarkTitle((New-Object Windows.Interop.WindowInteropHelper $this).Handle, $script:WNGui.Dark) } catch { }
    })
    $ctl.VersionText.Text = "$($WN.Version) $($WN.Channel) - $(T 'gui.preview')"
    $ctl.ModeText.Text = if ($WN.IsAdmin) { T 'gui.modeAdmin' } else { T 'gui.modeUser' }
    $ctl.SimToggle.IsChecked = $WN.DryRun
    $ctl.SimToggle.IsEnabled = $WN.IsAdmin
    $ctl.SimToggle.Add_Click({ $WN.DryRun = [bool]$script:WNGui.SimToggle.IsChecked; Write-WNLog "GUI simulation mode: $($WN.DryRun)" -Component 'Gui' })
    $ctl.QuickAppsHint.Text = T 'gui.qAppsHint' @($WN.Config.apps).Count

    # ---- Navigation
    $ctl.NavHome.Add_Checked({ Show-WNGuiPage 'Home' })
    $ctl.NavTweaks.Add_Checked({ Show-WNGuiPage 'Tweaks' })
    $ctl.NavApps.Add_Checked({ Show-WNGuiPage 'Apps' })
    $ctl.NavNext.Add_Checked({ Show-WNGuiPage 'Next' })
    $ctl.QuickTweaks.Add_Click({
        foreach ($r in $script:WNGui.TweakRows) { $r.Selected = @($WN.Config.presets.Standard.Tweaks) -contains $r.Key }
        Show-WNGuiPage 'Tweaks'
    })
    $ctl.QuickApps.Add_Click({ Show-WNGuiPage 'Apps'; [void]$script:WNGui.Ctl.AppQuery.Focus() })
    $openTerminal = {
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $WN.Root 'Winnow.ps1')`"", '-Lang', $WN.Lang)
        if ($WN.DryRun) { $a += '-DryRun' }
        Start-Process powershell.exe -ArgumentList $a
    }
    $ctl.TerminalBtn.Add_Click($openTerminal)
    $ctl.QuickTerminal.Add_Click($openTerminal)
    $ctl.RepoBtn.Add_Click({ Start-Process $WN.Repo })
    $ctl.LangBtn.Add_Click({
        $script:WNGui.Relaunch = if ($WN.Lang -eq 'es') { 'en' } else { 'es' }
        $script:WNGui.Window.Close()
    })
    $ctl.LogToggle.Add_Click({ $script:WNGui.Log.Visibility = if ($script:WNGui.Ctl.LogToggle.IsChecked) { 'Visible' } else { 'Collapsed' } })

    # ---- Home: system summary (read in the worker so the window opens at once)
    $ctl.NextList.ItemsSource = @(1..5 | ForEach-Object { T "gui.next$_" })

    # ---- Tweaks
    $rows = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    $order = 'Essential', 'Privacy', 'Performance', 'Interface', 'Bloatware', 'Advanced', 'Preferences'
    foreach ($t in ($WN.Config.tweaks | Sort-Object { [array]::IndexOf($order, $_.Category) }, Name)) {
        $rows.Add((New-Object WNRow -Property @{ Key = $t.Key; Name = $t.Name; Description = $t.Description; Group = (T "cat.$($t.Category)"); Item = $t }))
    }
    $g.TweakRows = $rows
    $view = [Windows.Data.CollectionViewSource]::GetDefaultView($rows)
    $view.GroupDescriptions.Add((New-Object Windows.Data.PropertyGroupDescription 'Group'))
    $g.TweakView = $view
    $ctl.TweakList.ItemsSource = $view
    $ctl.TweakFilter.Add_TextChanged({
        $q = $script:WNGui.Ctl.TweakFilter.Text.Trim()
        $script:WNGui.TweakView.Filter = if ($q) { [Predicate[object]] { param($r) $r.Name -like "*$q*" -or $r.Description -like "*$q*" }.GetNewClosure() } else { $null }
    })
    # Event handlers run in this script's scope (no GetNewClosure, which would hide its functions),
    # so the preset name travels in the button's Tag
    foreach ($p in 'Minimal', 'Standard', 'Heavy') {
        $ctl["Preset$p"].Tag = $p
        $ctl["Preset$p"].Add_Click({
            $keys = @($WN.Config.presets.($this.Tag).Tweaks)
            foreach ($r in $script:WNGui.TweakRows) { $r.Selected = $keys -contains $r.Key }
        })
    }
    $ctl.PresetClear.Add_Click({ foreach ($r in $script:WNGui.TweakRows) { $r.Selected = $false } })
    $ctl.ApplyBtn.Add_Click({ Invoke-WNGuiTweaks })
    $ctl.UndoBtn.Add_Click({ Invoke-WNGuiTweaks -Undo })

    # ---- Apps: typing filters the catalog, Enter or the button searches all of winget
    Set-WNGuiApps @($WN.Config.apps | Sort-Object Name)
    $g.Catalog = $true
    $ctl.AppQuery.Add_TextChanged({
        $g = $script:WNGui
        if (-not $g.Catalog) { return }
        $q = $g.Ctl.AppQuery.Text.Trim()
        $g.AppView.Filter = if ($q) { [Predicate[object]] { param($r) $r.Name -like "*$q*" -or $r.Description -like "*$q*" }.GetNewClosure() } else { $null }
        $g.AppCount.Text = T 'gui.results' @($g.AppView).Count
    })
    $g.Search = {
        $q = $script:WNGui.Ctl.AppQuery.Text.Trim()
        if (-not $q) { return }
        Start-WNGuiJob -Label (T 'gui.searchWinget') -Arguments @(, $q) -Script { param($q) @(Search-WNWinget $q) }.ToString() -OnDone {
            param($out)
            $script:WNGui.Catalog = $false
            Set-WNGuiApps @($out)
        }
    }
    $ctl.SearchBtn.Add_Click($g.Search)
    $ctl.AppQuery.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { & $script:WNGui.Search } })
    $ctl.CatalogBtn.Add_Click({
        $script:WNGui.Catalog = $true
        Set-WNGuiApps @($WN.Config.apps | Sort-Object Name)
        $script:WNGui.Ctl.AppQuery.Text = ''
    })
    $ctl.InstallBtn.Add_Click({
        $g = $script:WNGui
        $sel = Get-WNGuiSelected $g.AppRows
        if (-not $sel.Count) { [void][Windows.MessageBox]::Show($g.Window, (T 'gui.noneSelected'), 'Winnow'); return }
        if (-not (Confirm-WNGui (T 'gui.confirmInstall' $sel.Count))) { return }
        Start-WNGuiJob -Label (T 'gui.install') -Arguments @($WN.DryRun, @($sel.Item)) -Script {
            param($dry, $apps)
            $WN.DryRun = $dry
            Install-WNApps -Apps @($apps)
        }.ToString() -OnDone { foreach ($r in $script:WNGui.AppRows) { $r.Selected = $false } }
    })

    # ---- Start: worker, then system info and tweak states
    $g.Runspace = New-WNGuiWorker
    $window.Add_ContentRendered({
        Start-WNGuiJob -Label (T 'gui.loading') -Script {
            $os = Get-CimInstance Win32_OperatingSystem
            $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
            $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
            $ver = Get-WNRegistryValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
            $up = (Get-Date) - $os.LastBootUpTime
            [ordered]@{
                (T 'gui.cardWindows') = "$($WN.OSLabel) $ver (build $($WN.OSBuild))"
                (T 'gui.cardCpu')     = $cpu.Name.Trim()
                (T 'gui.cardRam')     = T 'gui.ramValue' ($os.TotalVisibleMemorySize * 1KB / 1GB) ($os.FreePhysicalMemory * 1KB / 1GB)
                (T 'gui.cardDisk')    = T 'gui.diskValue' $env:SystemDrive (100 - [int](100 * $d.FreeSpace / $d.Size)) ($d.FreeSpace / 1GB)
                (T 'gui.cardUptime')  = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
            }
        }.ToString() -OnDone {
            param($out)
            $panel = $script:WNGui.Ctl.InfoPanel
            $info = $out[0]
            foreach ($k in $info.Keys) {
                $b = New-Object Windows.Controls.Border
                $b.Style = $script:WNGui.Window.Resources['Info']
                $sp = New-Object Windows.Controls.StackPanel
                $t1 = New-Object Windows.Controls.TextBlock -Property @{ Text = $k; FontSize = 12.5 }
                $t1.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'FgDim')
                $t2 = New-Object Windows.Controls.TextBlock -Property @{ Text = $info[$k]; FontWeight = 'SemiBold'; TextWrapping = 'Wrap'; Margin = '0,4,0,0' }
                [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2)
                $b.Child = $sp
                [void]$panel.Children.Add($b)
            }
            Update-WNGuiTweakStates
        }
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
