# gui/Launcher.ps1
# Start window: a short boot animation, then the language (EN | ES) and the mode as two flat cards,
# Graphical interface or Terminal. Replaces the console screens on every interactive start. While the animation
# runs it asks GitHub for a newer release; when there is one, a bar offers Update now / Later.

$script:WNLauncherXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WinNow" Width="640" Height="380" WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True"
        FontFamily="Segoe UI Variable Text, Segoe UI" Foreground="@@FG@@">
  <Window.Resources>
    <FontFamily x:Key="Icons">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>
    <Style x:Key="Card" TargetType="Button">
      <Setter Property="Background" Value="@@CARD@@"/>
      <Setter Property="BorderBrush" Value="@@LINE@@"/>
      <Setter Property="Foreground" Value="@@FG@@"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="8,0"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="16" Background="{TemplateBinding Background}"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="2" Padding="24,26">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="BorderBrush" Value="@@ACCENT@@"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="B" Property="BorderBrush" Value="@@ACCENT@@"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Pill" TargetType="Button">
      <Setter Property="Foreground" Value="@@DIM@@"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="12" Background="{TemplateBinding Background}" Padding="11,4" Margin="2,0">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="@@LINE@@"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border CornerRadius="22" Background="@@BG@@" BorderBrush="@@LINE@@" BorderThickness="1">
    <Grid>
      <StackPanel x:Name="Boot" VerticalAlignment="Center" HorizontalAlignment="Center">
        <Image x:Name="BootLogo" Width="104" Height="104" Opacity="0" RenderTransformOrigin="0.5,0.5"
               RenderOptions.BitmapScalingMode="HighQuality">
          <Image.RenderTransform><ScaleTransform x:Name="BootScale" ScaleX="0.82" ScaleY="0.82"/></Image.RenderTransform>
        </Image>
        <TextBlock x:Name="BootName" Text="WinNow" FontFamily="Segoe UI Variable Display, Segoe UI" FontSize="30"
                   FontWeight="Bold" HorizontalAlignment="Center" Margin="0,16,0,0" Opacity="0"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,18,0,0">
          <Ellipse x:Name="Dot1" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
          <Ellipse x:Name="Dot2" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
          <Ellipse x:Name="Dot3" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
        </StackPanel>
        <TextBlock x:Name="BootText" Foreground="@@DIM@@" FontSize="12.5" HorizontalAlignment="Center" Margin="0,14,0,0" Opacity="0"/>
      </StackPanel>
      <Grid x:Name="Chooser" Margin="32,24,32,22" Opacity="0" Visibility="Collapsed">
        <Grid.RenderTransform><TranslateTransform x:Name="ChooserShift" Y="14"/></Grid.RenderTransform>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <DockPanel>
          <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
            <Button x:Name="LangEn" Style="{StaticResource Pill}" Content="EN"/>
            <Button x:Name="LangEs" Style="{StaticResource Pill}" Content="ES"/>
            <Button x:Name="CloseBtn" Style="{StaticResource Pill}" Margin="8,0,0,0" FontFamily="{StaticResource Icons}" FontSize="11" Content="&#xE8BB;"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Image x:Name="SmallLogo" Width="30" Height="30" RenderOptions.BitmapScalingMode="HighQuality"/>
            <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="Heading" FontSize="17" FontWeight="SemiBold" VerticalAlignment="Center"/>
                <Border x:Name="PreviewTag" CornerRadius="8" Background="#33FF9F0A" Padding="7,1" Margin="10,1,0,0" VerticalAlignment="Center">
                  <TextBlock Text="GUI RETHINKED" FontSize="10.5" FontWeight="Bold" Foreground="#FFFF9F0A"/>
                </Border>
              </StackPanel>
              <TextBlock x:Name="Version" Foreground="@@DIM@@" FontSize="12"/>
            </StackPanel>
          </StackPanel>
        </DockPanel>
        <UniformGrid Grid.Row="1" Columns="2" Margin="-8,22,-8,18">
          <Button x:Name="GuiCard" Style="{StaticResource Card}" Tag="gui">
            <StackPanel>
              <Border Width="54" Height="54" CornerRadius="27" Background="@@TINT@@" HorizontalAlignment="Left">
                <TextBlock FontFamily="{StaticResource Icons}" Text="&#xE7F4;" FontSize="24" Foreground="@@ACCENT@@"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <TextBlock x:Name="GuiLabel" FontSize="17" FontWeight="SemiBold" Margin="0,16,0,0" TextWrapping="Wrap"/>
              <TextBlock x:Name="GuiHint" Foreground="@@DIM@@" FontSize="12.5" Margin="0,6,0,0" TextWrapping="Wrap"/>
            </StackPanel>
          </Button>
          <Button x:Name="TermCard" Style="{StaticResource Card}" Tag="terminal">
            <StackPanel>
              <Border Width="54" Height="54" CornerRadius="27" Background="@@TINT@@" HorizontalAlignment="Left">
                <TextBlock FontFamily="{StaticResource Icons}" Text="&#xE756;" FontSize="24" Foreground="@@ACCENT@@"
                           HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Border>
              <TextBlock x:Name="TermLabel" FontSize="17" FontWeight="SemiBold" Margin="0,16,0,0" TextWrapping="Wrap"/>
              <TextBlock x:Name="TermHint" Foreground="@@DIM@@" FontSize="12.5" Margin="0,6,0,0" TextWrapping="Wrap"/>
            </StackPanel>
          </Button>
        </UniformGrid>
        <TextBlock x:Name="Keys" Grid.Row="2" Foreground="@@DIM@@" FontSize="12" HorizontalAlignment="Center"/>
        <Border x:Name="UpdBar" Grid.Row="2" CornerRadius="12" Background="@@TINT@@" Padding="14,7" Visibility="Collapsed">
          <DockPanel>
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
              <Button x:Name="UpdNow" Style="{StaticResource Pill}" Foreground="White" Background="@@ACCENT@@"/>
              <Button x:Name="UpdLater" Style="{StaticResource Pill}"/>
            </StackPanel>
            <TextBlock FontFamily="{StaticResource Icons}" Text="&#xE896;" Foreground="@@ACCENT@@" FontSize="15"
                       VerticalAlignment="Center" Margin="0,0,10,0"/>
            <TextBlock x:Name="UpdText" FontSize="12.5" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          </DockPanel>
        </Border>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$script:WNLauncherThemes = @{
    Dark  = @{ BG = '#FF1C1C1E'; CARD = '#FF2C2C2E'; LINE = '#FF3A3A3C'; FG = '#FFF5F5F7'; DIM = '#FF98989D'; ACCENT = '#FF0A84FF'; TINT = '#260A84FF' }
    Navidad = @{ BG = '#FF10301F'; CARD = '#FF1A4330'; LINE = '#FF2A5A43'; FG = '#FFF5F5F7'; DIM = '#FFB8CBBF'; ACCENT = '#FFC8102E'; TINT = '#F2FFFFFF' }
    Patria = @{ BG = '#FF0B2A52'; CARD = '#FF143A6B'; LINE = '#FF24497A'; FG = '#FFF5F5F7'; DIM = '#FFC3CEDD'; ACCENT = '#FFD21034'; TINT = '#F2FFFFFF' }
    Linux = @{ BG = '#FF2B2B2B'; CARD = '#FF353535'; LINE = '#FF454545'; FG = '#FFF2F2F2'; DIM = '#FFBDBDBD'; ACCENT = '#FFE95420'; TINT = '#268AE234' }
    Light = @{ BG = '#FFF5F5F7'; CARD = '#FFFFFFFF'; LINE = '#FFE0E0E5'; FG = '#FF1C1C1E'; DIM = '#FF6E6E73'; ACCENT = '#FF007AFF'; TINT = '#1F007AFF' }
}

function Set-WNConsoleWindow {
    # Minimize (6) or restore (9) the console behind the launcher; no-op where the host has no window of its own
    param([int]$Show)
    try {
        if (-not ('WN.ConsoleWin' -as [type])) {
            Add-Type -Namespace WN -Name ConsoleWin -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
        }
        $h = [WN.ConsoleWin]::GetConsoleWindow()
        if ($h -ne [IntPtr]::Zero) { [void][WN.ConsoleWin]::ShowWindow($h, $Show) }
    } catch { }
}

function Update-WNLauncherText {
    $c = $script:WNL.Ctl
    $c.Heading.Text = T 'mode.title'
    $c.PreviewTag.ToolTip = T 'launch.previewTip'
    $c.GuiLabel.Text = T 'mode.gui'
    $c.GuiHint.Text = T 'mode.guiHint'
    $c.TermLabel.Text = T 'mode.terminal'
    $c.TermHint.Text = T 'mode.terminalHint'
    $c.Keys.Text = T 'launch.keys'
    $c.BootText.Text = if ($script:WNL.Check) { T 'launch.checking' } else { T 'launch.loading' }
    $u = $script:WNL.Update
    if ($u) {
        $c.UpdText.Text = T 'launch.updAvail' $u.Version $WN.Version
        $c.UpdNow.Content = T 'launch.updNow'
        $c.UpdLater.Content = T 'launch.updLater'
    }
    foreach ($b in @($c.LangEn, $c.LangEs)) {
        $on = $b.Content -eq $WN.Lang.ToUpper()
        $b.Foreground = if ($on) { 'White' } else { $script:WNL.Theme.DIM }
        $b.Background = if ($on) { $script:WNL.Theme.ACCENT } else { 'Transparent' }
    }
}

function Start-WNLauncherXmas {
    # Navidad boot: snow falls across the window, the logo drops in and swings once like an ornament, and the dots
    # turn red, green and gold. It all ends with the boot screen.
    $l = $script:WNL
    $c = $l.Ctl
    $grid = $c.Boot.Parent
    $snow = New-Object Windows.Controls.Canvas
    $snow.IsHitTestVisible = $false
    $snow.ClipToBounds = $true
    $grid.Children.Insert(0, $snow)
    $l.Snow = $snow
    $rnd = New-Object Random 2412
    for ($k = 0; $k -lt 34; $k++) {
        $f = New-Object Windows.Controls.TextBlock
        $f.Text = [string][char]0x2744
        $f.FontFamily = 'Segoe UI Symbol'
        $f.FontSize = $rnd.Next(9, 22)
        $f.Foreground = [Windows.Media.Brushes]::White
        $f.Opacity = 0.35 + $rnd.NextDouble() * 0.5
        $x = $rnd.Next(0, 630)
        [Windows.Controls.Canvas]::SetLeft($f, $x)
        [Windows.Controls.Canvas]::SetTop($f, -30)
        [void]$snow.Children.Add($f)
        $d = [Windows.Duration][TimeSpan]::FromMilliseconds($rnd.Next(1900, 3600))
        $start = [TimeSpan]::FromMilliseconds($rnd.Next(0, 900))
        $fall = New-Object Windows.Media.Animation.DoubleAnimation -30, 400, $d
        $drift = New-Object Windows.Media.Animation.DoubleAnimation $x, ($x + $rnd.Next(-46, 46)), $d
        $drift.EasingFunction = New-Object Windows.Media.Animation.SineEase -Property @{ EasingMode = 'EaseInOut' }
        $fall.BeginTime = $start; $drift.BeginTime = $start
        $f.BeginAnimation([Windows.Controls.Canvas]::TopProperty, $fall)
        $f.BeginAnimation([Windows.Controls.Canvas]::LeftProperty, $drift)
    }
    # The logo drops from above with a small bounce, then swings like an ornament on its string
    $c.BootLogo.RenderTransformOrigin = '0.5,0'
    $drop = New-Object Windows.Media.TranslateTransform 0, -70
    $swing = New-Object Windows.Media.RotateTransform 0
    $tg = New-Object Windows.Media.TransformGroup
    $c.BootLogo.RenderTransform = $null
    $tg.Children.Add($c.BootScale); $tg.Children.Add($swing); $tg.Children.Add($drop)
    $c.BootLogo.RenderTransform = $tg
    $fallIn = New-Object Windows.Media.Animation.DoubleAnimation -70, 0, ([Windows.Duration][TimeSpan]::FromMilliseconds(900))
    $fallIn.EasingFunction = New-Object Windows.Media.Animation.BounceEase -Property @{ Bounces = 2; Bounciness = 3; EasingMode = 'EaseOut' }
    $drop.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $fallIn)
    $sw = New-Object Windows.Media.Animation.DoubleAnimationUsingKeyFrames
    $sw.BeginTime = [TimeSpan]::FromMilliseconds(650)
    foreach ($kf in @(@(0, 0), @(260, -9), @(560, 7), @(820, -3), @(1080, 0))) {
        $k = New-Object Windows.Media.Animation.EasingDoubleKeyFrame $kf[1], ([Windows.Media.Animation.KeyTime][TimeSpan]::FromMilliseconds($kf[0]))
        $k.EasingFunction = New-Object Windows.Media.Animation.SineEase -Property @{ EasingMode = 'EaseInOut' }
        [void]$sw.KeyFrames.Add($k)
    }
    $swing.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $sw)
    $c.Dot1.Fill = [Windows.Media.Brush](New-Object Windows.Media.BrushConverter).ConvertFromString('#FFE53935')
    $c.Dot2.Fill = [Windows.Media.Brush](New-Object Windows.Media.BrushConverter).ConvertFromString('#FF2E9D5B')
    $c.Dot3.Fill = [Windows.Media.Brush](New-Object Windows.Media.BrushConverter).ConvertFromString('#FFF2C14E')
}

function Show-WNLauncherChooser {
    # Boot animation done (or skipped): fade the chooser in and focus the last mode used
    $l = $script:WNL
    if ($l.Chosen) { return }
    $l.Chosen = $true
    $l.Timer.Stop()
    $c = $l.Ctl
    $c.Boot.Visibility = 'Collapsed'
    if ($l.Snow) { $l.Snow.BeginAnimation([Windows.UIElement]::OpacityProperty, (New-Object Windows.Media.Animation.DoubleAnimation 0, ([Windows.Duration][TimeSpan]::FromMilliseconds(700)))) }
    $c.Chooser.Visibility = 'Visible'
    $d = [Windows.Duration][TimeSpan]::FromMilliseconds(320)
    $ease = New-Object Windows.Media.Animation.CubicEase
    $fade = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, $d
    $slide = New-Object Windows.Media.Animation.DoubleAnimation 14, 0, $d
    $slide.EasingFunction = $ease
    $c.Chooser.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
    $c.ChooserShift.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $slide)
    $card = if ((Get-WNSettings).Mode -eq 'terminal') { $c.TermCard } else { $c.GuiCard }
    [void]$card.Focus()
}

function Receive-WNLauncherUpdate {
    # The background check finished: a newer release (not skipped) shows the update bar
    $l = $script:WNL
    if (-not $l.Check -or -not $l.Check.Handle.IsCompleted) { return }
    $l.Poll.Stop()
    try { $u = @($l.Check.PS.EndInvoke($l.Check.Handle)) | Select-Object -Last 1 } catch { $u = $null }
    $l.Check.PS.Dispose()
    $l.Check = $null
    $l.Checked = [bool]$u
    if ($u -and $u.Newer -and (Get-WNSettings).SkipVersion -ne $u.Version) {
        $l.Update = $u
        $c = $l.Ctl
        $c.Keys.Visibility = 'Collapsed'
        $c.UpdBar.Visibility = 'Visible'
    }
    Update-WNLauncherText
}

function Show-WNLauncher {
    # Returns @{ Mode = 'gui' | 'terminal' | 'update'; Lang; Checked; Update }, 'exit' when the window is closed,
    # or $null when WPF is not available (MTA thread, no desktop): the caller then asks in the console.
    # Checked: GitHub answered, so the caller skips its own update check.
    param([string]$Lang, [switch]$NoUpdateCheck)
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { return $null }
    try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction Stop } catch { return $null }

    $saved = Get-WNSettings
    if (-not $Lang) { $Lang = if ($saved.Lang -in 'en', 'es') { $saved.Lang } else { 'en' } }
    Set-WNLanguage $Lang
    # The window's theme: the saved one, Navidad in December, Mes patrio in November, else the Windows apps setting
    $themeName = if ($saved.GuiTheme -in 'Light', 'Dark', 'Patria', 'Navidad', 'Linux') { $saved.GuiTheme } elseif ((Get-Date).Month -eq 12) { 'Navidad' } elseif ((Get-Date).Month -eq 11) { 'Patria' } else {
        try { if ((Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' -ErrorAction Stop) -eq 1) { 'Light' } else { 'Dark' } } catch { 'Dark' }
    }
    $light = $themeName -eq 'Light'
    $theme = $script:WNLauncherThemes[$themeName]
    $xaml = $script:WNLauncherXaml
    foreach ($k in $theme.Keys) { $xaml = $xaml.Replace("@@$k@@", $theme[$k]) }
    try { $window = [Windows.Markup.XamlReader]::Parse($xaml) } catch { Write-WNLog "Launcher failed: $($_.Exception.Message)" -Level WARN -Component 'Gui'; return $null }

    $ctl = @{}
    foreach ($n in 'Boot', 'BootLogo', 'BootScale', 'BootName', 'BootText', 'Dot1', 'Dot2', 'Dot3', 'Chooser', 'ChooserShift', 'SmallLogo',
                   'Heading', 'Version', 'GuiCard', 'TermCard', 'GuiLabel', 'GuiHint', 'TermLabel', 'TermHint', 'Keys', 'LangEn', 'LangEs', 'CloseBtn',
                   'UpdBar', 'UpdText', 'UpdNow', 'UpdLater', 'PreviewTag') {
        $ctl[$n] = $window.FindName($n)
    }
    $script:WNL = @{ Window = $window; Ctl = $ctl; Theme = $theme; ThemeName = $themeName; Result = 'exit'; Chosen = $false; Timer = $null
                     Check = $null; Poll = $null; Checked = $false; Update = $null }

    # Update check in its own runspace so the animation never waits on GitHub (5 s at most)
    if (-not $NoUpdateCheck) {
        $ps = [powershell]::Create()
        [void]$ps.AddScript({
            param($root, $ver, $gver)
            function Write-WNLog { }
            . (Join-Path $root 'core\Update.ps1')
            $global:WN = @{ Version = $ver; GuiVersion = $gver }
            Get-WNUpdateInfo
        }).AddArgument($WN.Root).AddArgument($WN.Version).AddArgument($WN.GuiVersion)
        $script:WNL.Check = @{ PS = $ps; Handle = $ps.BeginInvoke() }
        $poll = New-Object Windows.Threading.DispatcherTimer
        $poll.Interval = [TimeSpan]::FromMilliseconds(200)
        $poll.Add_Tick({ Receive-WNLauncherUpdate })
        $script:WNL.Poll = $poll
        $poll.Start()
    }

    # Logo made for this background, read into memory so the updater can always replace the file
    $file = Join-Path $WN.Root $(switch ($themeName) { 'Light' { 'LOGO\Winnow_128_light.png' } 'Navidad' { 'LOGO\Winnow_128_navidad.png' } 'Patria' { 'LOGO\Winnow_128_patria.png' } 'Linux' { 'LOGO\Winnow_128_linux.png' } default { 'LOGO\Winnow_128.png' } })
    if (Test-Path -LiteralPath $file) {
        $bmp = New-Object Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit(); $bmp.CacheOption = 'OnLoad'; $bmp.UriSource = New-Object Uri $file; $bmp.EndInit(); $bmp.Freeze()
        $ctl.BootLogo.Source = $bmp; $ctl.SmallLogo.Source = $bmp; $window.Icon = $bmp
    }
    $ctl.Version.Text = "$($WN.Version) $($WN.Channel)  -  $(T 'brand.madeIn')"
    Update-WNLauncherText

    $pick = {
        $l = $script:WNL
        $l.Result = @{ Mode = $this.Tag; Lang = $WN.Lang; Checked = $l.Checked; Update = $l.Update }
        Save-WNSetting 'Mode' $this.Tag
        $l.Window.Close()
    }
    $ctl.GuiCard.Add_Click($pick)
    $ctl.TermCard.Add_Click($pick)
    $ctl.UpdNow.Add_Click({
        $l = $script:WNL
        $l.Result = @{ Mode = 'update'; Lang = $WN.Lang; Checked = $true; Update = $l.Update }
        $l.Window.Close()
    })
    # Later: keep using this version; the next start asks again
    $ctl.UpdLater.Add_Click({ $c = $script:WNL.Ctl; $c.UpdBar.Visibility = 'Collapsed'; $c.Keys.Visibility = 'Visible' })
    $ctl.CloseBtn.Add_Click({ $script:WNL.Window.Close() })
    foreach ($b in @($ctl.LangEn, $ctl.LangEs)) {
        $b.Add_Click({ $l = $this.Content.ToString().ToLower(); Set-WNLanguage $l; Save-WNSetting 'Lang' $l; Update-WNLauncherText })
    }
    # The rounded window has no title bar: drag it from anywhere
    $window.Add_MouseLeftButtonDown({ try { $this.DragMove() } catch { } })
    $window.Add_KeyDown({
        param($s, $e)
        $l = $script:WNL
        if (-not $l.Chosen) { Show-WNLauncherChooser; $e.Handled = $true; return }
        switch ($e.Key) {
            'Escape' { $l.Window.Close() }
            { $_ -in 'D1', 'NumPad1' } { $l.Ctl.GuiCard.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent, $l.Ctl.GuiCard))) }
            { $_ -in 'D2', 'NumPad2' } { $l.Ctl.TermCard.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent, $l.Ctl.TermCard))) }
            { $_ -in 'Left', 'Right' } { if ($l.Ctl.GuiCard.IsKeyboardFocused) { [void]$l.Ctl.TermCard.Focus() } else { [void]$l.Ctl.GuiCard.Focus() }; $e.Handled = $true }
        }
    })

    # Boot animation: the logo grows in, the name follows, three dots pulse like the logo's grains
    $window.Add_ContentRendered({
        $c = $script:WNL.Ctl
        $ms = { param($v) [Windows.Duration][TimeSpan]::FromMilliseconds($v) }
        $in = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, (& $ms 520)
        $c.BootLogo.BeginAnimation([Windows.UIElement]::OpacityProperty, $in)
        $grow = New-Object Windows.Media.Animation.DoubleAnimation 0.82, 1, (& $ms 640)
        $grow.EasingFunction = New-Object Windows.Media.Animation.BackEase -Property @{ Amplitude = 0.35 }
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
        foreach ($t in @($c.BootName, $c.BootText)) {
            $f = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, (& $ms 420)
            $f.BeginTime = [TimeSpan]::FromMilliseconds(260)
            $t.BeginAnimation([Windows.UIElement]::OpacityProperty, $f)
        }
        $i = 0
        foreach ($d in @($c.Dot1, $c.Dot2, $c.Dot3)) {
            $p = New-Object Windows.Media.Animation.DoubleAnimation 0.25, 1, (& $ms 360)
            $p.AutoReverse = $true
            $p.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
            $p.BeginTime = [TimeSpan]::FromMilliseconds(180 * $i++)
            $d.BeginAnimation([Windows.UIElement]::OpacityProperty, $p)
        }
        if ($script:WNL.ThemeName -eq 'Navidad') { Start-WNLauncherXmas }
        $script:WNL.Timer.Start()
    })
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($(if ($themeName -eq 'Navidad') { 2400 } else { 1700 }))
    $timer.Add_Tick({ Show-WNLauncherChooser })
    $script:WNL.Timer = $timer
    $window.Add_PreviewMouseLeftButtonDown({ if (-not $script:WNL.Chosen) { Show-WNLauncherChooser } })

    Set-WNConsoleWindow 6
    try { [void]$window.ShowDialog() } catch { Write-WNLog "Launcher failed: $($_.Exception.Message)" -Level WARN -Component 'Gui'; Set-WNConsoleWindow 9; return $null }
    $timer.Stop()
    if ($script:WNL.Poll) { $script:WNL.Poll.Stop() }
    if ($script:WNL.Check) { $script:WNL.Check.PS.Dispose() }
    $r = $script:WNL.Result
    if ($r -is [hashtable] -and $r.Mode -eq 'gui') { return $r }
    Set-WNConsoleWindow 9
    return $r
}
