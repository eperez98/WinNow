# gui/Launcher.ps1
# Start window: a short boot animation with a soft chime, then straight into the saved mode (the graphical
# interface by default). The first start asks instead: language (EN | ES), Graphical interface or Terminal, and
# Light or Dark. While the animation runs it asks GitHub for a newer release; when there is one, the cards come up
# with a bar that offers Update now / Later.

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
  <Border x:Name="Shell" CornerRadius="22" Background="@@BG@@" BorderBrush="@@LINE@@" BorderThickness="1" ClipToBounds="True">
    <Grid>
      <!-- Glass glow: two soft lights in the accent colour drift behind everything -->
      <Canvas IsHitTestVisible="False" ClipToBounds="True">
        <Ellipse x:Name="Glow1" Width="430" Height="430" Canvas.Left="-170" Canvas.Top="-210" Opacity="0.55">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="@@ACCENT@@" Offset="0"/><GradientStop Color="#00000000" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
        </Ellipse>
        <Ellipse x:Name="Glow2" Width="380" Height="380" Canvas.Left="420" Canvas.Top="170" Opacity="0.35">
          <Ellipse.Fill><RadialGradientBrush><GradientStop Color="@@ACCENT@@" Offset="0"/><GradientStop Color="#00000000" Offset="1"/></RadialGradientBrush></Ellipse.Fill>
        </Ellipse>
      </Canvas>
      <StackPanel x:Name="Boot" VerticalAlignment="Center" HorizontalAlignment="Center">
        <Grid Width="150" Height="150" HorizontalAlignment="Center">
          <Ellipse x:Name="Ring" Width="146" Height="146" Stroke="@@ACCENT@@" StrokeThickness="3" StrokeDashArray="150 150"
                   StrokeDashOffset="150" StrokeDashCap="Round" RenderTransformOrigin="0.5,0.5">
            <Ellipse.RenderTransform><RotateTransform x:Name="RingSpin" Angle="-90"/></Ellipse.RenderTransform>
          </Ellipse>
          <Image x:Name="BootLogo" Width="100" Height="100" Opacity="0" RenderTransformOrigin="0.5,0.5"
                 RenderOptions.BitmapScalingMode="HighQuality">
            <Image.RenderTransform><ScaleTransform x:Name="BootScale" ScaleX="0.82" ScaleY="0.82"/></Image.RenderTransform>
            <Image.Effect><BlurEffect x:Name="BootBlur" Radius="18"/></Image.Effect>
          </Image>
        </Grid>
        <TextBlock x:Name="BootName" Text="WinNow" FontFamily="Segoe UI Variable Display, Segoe UI" FontSize="30"
                   FontWeight="Bold" HorizontalAlignment="Center" Margin="0,10,0,0" Opacity="0">
          <TextBlock.RenderTransform><TranslateTransform x:Name="NameShift" Y="12"/></TextBlock.RenderTransform>
        </TextBlock>
        <StackPanel x:Name="Dots" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,12,0,0" Visibility="Collapsed">
          <Ellipse x:Name="Dot1" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
          <Ellipse x:Name="Dot2" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
          <Ellipse x:Name="Dot3" Width="8" Height="8" Margin="4,0" Fill="@@ACCENT@@" Opacity="0.25"/>
        </StackPanel>
        <Border Width="150" Height="3" CornerRadius="2" Background="@@LINE@@" Margin="0,16,0,0" HorizontalAlignment="Center">
          <Border x:Name="BootBar" Width="0" HorizontalAlignment="Left" CornerRadius="2" Background="@@ACCENT@@"/>
        </Border>
        <TextBlock x:Name="BootText" Foreground="@@DIM@@" FontSize="12.5" HorizontalAlignment="Center" Margin="0,10,0,0" Opacity="0"/>
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
        <TextBlock x:Name="Keys" Grid.Row="2" Foreground="@@DIM@@" FontSize="12" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        <!-- First start only: Light or Dark for the window -->
        <StackPanel x:Name="Appear" Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center" Visibility="Collapsed">
          <TextBlock x:Name="AppearLabel" Foreground="@@DIM@@" FontSize="12.5" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <Button x:Name="AppLight" Style="{StaticResource Pill}" Tag="Light"/>
          <Button x:Name="AppDark" Style="{StaticResource Pill}" Tag="Dark"/>
        </StackPanel>
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
    Skeuo = @{ BG = '#FFEDE6D8'; CARD = '#FFFBF8F1'; LINE = '#FFC9BDA6'; FG = '#FF3A2E22'; DIM = '#FF6B5C4A'; ACCENT = '#FF2F6FB0'; TINT = '#1F2F6FB0' }
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
    $c.Heading.Text = if ($script:WNL.FirstRun) { T 'onb.title' } else { T 'mode.title' }
    $c.AppearLabel.Text = T 'onb.appearance'
    $c.AppLight.Content = T 'onb.light'
    $c.AppDark.Content = T 'onb.dark'
    foreach ($b in @($c.AppLight, $c.AppDark)) {
        $on = $b.Tag -eq $script:WNL.Appear
        $b.Foreground = if ($on) { 'White' } else { $script:WNL.Theme.DIM }
        $b.Background = if ($on) { $script:WNL.Theme.ACCENT } else { 'Transparent' }
    }
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
    # Boot animation done (or skipped). Returning users go straight into their mode (the window by default); the
    # first start, or a newer release found meanwhile, fades the cards in and focuses the last mode used.
    $l = $script:WNL
    if ($l.Chosen) { return }
    $l.Chosen = $true
    $l.Timer.Stop()
    $c = $l.Ctl
    if (-not $l.FirstRun -and -not $l.Update) {
        $mode = if ((Get-WNSettings).Mode -eq 'terminal') { 'terminal' } else { 'gui' }
        $l.Result = @{ Mode = $mode; Lang = $WN.Lang; Checked = $l.Checked; Update = $null }
        $out = New-Object Windows.Media.Animation.DoubleAnimation 0, ([Windows.Duration][TimeSpan]::FromMilliseconds(220))
        $out.Add_Completed({ $script:WNL.Window.Close() })
        $l.Window.BeginAnimation([Windows.UIElement]::OpacityProperty, $out)
        return
    }
    if ($l.FirstRun -and -not $l.Update) { $c.Appear.Visibility = 'Visible'; $c.Keys.HorizontalAlignment = 'Right' }
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
    $themeName = if ($saved.GuiTheme -in 'Light', 'Dark', 'Skeuo', 'Patria', 'Navidad', 'Linux') { $saved.GuiTheme } elseif ((Get-Date).Month -eq 12) { 'Navidad' } elseif ((Get-Date).Month -eq 11) { 'Patria' } else {
        try { if ((Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' -ErrorAction Stop) -eq 1) { 'Light' } else { 'Dark' } } catch { 'Dark' }
    }
    $light = $themeName -in 'Light', 'Skeuo'
    $theme = $script:WNLauncherThemes[$themeName]
    $xaml = $script:WNLauncherXaml
    foreach ($k in $theme.Keys) { $xaml = $xaml.Replace("@@$k@@", $theme[$k]) }
    try { $window = [Windows.Markup.XamlReader]::Parse($xaml) } catch { Write-WNLog "Launcher failed: $($_.Exception.Message)" -Level WARN -Component 'Gui'; return $null }

    $ctl = @{}
    foreach ($n in 'Boot', 'BootLogo', 'BootScale', 'BootName', 'BootText', 'Dot1', 'Dot2', 'Dot3', 'Chooser', 'ChooserShift', 'SmallLogo',
                   'Heading', 'Version', 'GuiCard', 'TermCard', 'GuiLabel', 'GuiHint', 'TermLabel', 'TermHint', 'Keys', 'LangEn', 'LangEs', 'CloseBtn',
                   'UpdBar', 'UpdText', 'UpdNow', 'UpdLater', 'PreviewTag', 'Shell', 'Glow1', 'Glow2', 'Ring', 'RingSpin', 'BootBlur', 'NameShift',
                   'Dots', 'BootBar', 'Appear', 'AppearLabel', 'AppLight', 'AppDark') {
        $ctl[$n] = $window.FindName($n)
    }
    # First start on this PC (no settings yet): the cards ask for the mode and Light / Dark
    $first = -not @($saved.PSObject.Properties | Where-Object { $_.Name -in 'Lang', 'Mode', 'GuiTheme', 'TourSeen', 'ShortcutAsked' }).Count
    $script:WNL = @{ Window = $window; Ctl = $ctl; Theme = $theme; ThemeName = $themeName; Result = 'exit'; Chosen = $false; Timer = $null
                     Check = $null; Poll = $null; Checked = $false; Update = $null; FirstRun = $first; Appear = $(if ($light) { 'Light' } else { 'Dark' }) }

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
    $file = Join-Path $WN.Root $(switch ($themeName) { 'Light' { 'LOGO\Winnow_128_light.png' } 'Skeuo' { 'LOGO\Winnow_128_light.png' } 'Navidad' { 'LOGO\Winnow_128_navidad.png' } 'Patria' { 'LOGO\Winnow_128_patria.png' } 'Linux' { 'LOGO\Winnow_128_linux.png' } default { 'LOGO\Winnow_128.png' } })
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
        # A new user starts with the look picked here and has nothing "new" to be shown
        if ($l.FirstRun) { Save-WNSetting 'GuiTheme' $l.Appear; Save-WNSetting 'NewsSeen' $WN.Version }
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
    foreach ($b in @($ctl.AppLight, $ctl.AppDark)) { $b.Add_Click({ $script:WNL.Appear = $this.Tag; Update-WNLauncherText }) }
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

    # Boot animation: a ring draws itself around the logo, the logo comes into focus, the name rises, a thin line
    # fills while WinNow starts, and the glow behind drifts. A soft chime plays (Sound = false in settings mutes it).
    $window.Add_ContentRendered({
        $l = $script:WNL
        $c = $l.Ctl
        $ms = { param($v) [Windows.Duration][TimeSpan]::FromMilliseconds($v) }
        $out = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
        $draw = New-Object Windows.Media.Animation.DoubleAnimation 150, 0, (& $ms 900)
        $draw.EasingFunction = $out
        $c.Ring.BeginAnimation([Windows.Shapes.Shape]::StrokeDashOffsetProperty, $draw)
        $spin = New-Object Windows.Media.Animation.DoubleAnimation -90, 270, (& $ms 1500)
        $spin.EasingFunction = $out
        $c.RingSpin.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $spin)
        $in = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, (& $ms 520)
        $c.BootLogo.BeginAnimation([Windows.UIElement]::OpacityProperty, $in)
        $focus = New-Object Windows.Media.Animation.DoubleAnimation 18, 0, (& $ms 640)
        $focus.EasingFunction = $out
        $c.BootBlur.BeginAnimation([Windows.Media.Effects.BlurEffect]::RadiusProperty, $focus)
        $grow = New-Object Windows.Media.Animation.DoubleAnimation 0.82, 1, (& $ms 680)
        $grow.EasingFunction = New-Object Windows.Media.Animation.BackEase -Property @{ Amplitude = 0.35 }
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
        foreach ($t in @($c.BootName, $c.BootText)) {
            $f = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, (& $ms 420)
            $f.BeginTime = [TimeSpan]::FromMilliseconds(300)
            $t.BeginAnimation([Windows.UIElement]::OpacityProperty, $f)
        }
        $rise = New-Object Windows.Media.Animation.DoubleAnimation 12, 0, (& $ms 520)
        $rise.BeginTime = [TimeSpan]::FromMilliseconds(300); $rise.EasingFunction = $out
        $c.NameShift.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $rise)
        $bar = New-Object Windows.Media.Animation.DoubleAnimation 0, 150, (& $ms $l.Timer.Interval.TotalMilliseconds)
        $bar.EasingFunction = New-Object Windows.Media.Animation.SineEase -Property @{ EasingMode = 'EaseInOut' }
        $c.BootBar.BeginAnimation([Windows.FrameworkElement]::WidthProperty, $bar)
        foreach ($gl in @(@($c.Glow1, 60), @($c.Glow2, -50))) {
            $d = New-Object Windows.Media.Animation.DoubleAnimation ([Windows.Controls.Canvas]::GetLeft($gl[0])), ([Windows.Controls.Canvas]::GetLeft($gl[0]) + $gl[1]), (& $ms 2600)
            $d.AutoReverse = $true; $d.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
            $d.EasingFunction = New-Object Windows.Media.Animation.SineEase -Property @{ EasingMode = 'EaseInOut' }
            $gl[0].BeginAnimation([Windows.Controls.Canvas]::LeftProperty, $d)
        }
        if ($l.ThemeName -eq 'Navidad') {
            $c.Dots.Visibility = 'Visible'
            Start-WNLauncherXmas
        }
        if ((Get-WNSettings).Sound -ne $false) {
            $wav = Join-Path $WN.Root 'gui\start.wav'
            if (Test-Path -LiteralPath $wav) { try { $l.Sound = New-Object Media.SoundPlayer $wav; $l.Sound.Play() } catch { } }
        }
        $l.Timer.Start()
    })
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds($(if ($themeName -eq 'Navidad') { 2400 } else { 1900 }))
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
