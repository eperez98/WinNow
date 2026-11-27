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
  <Border CornerRadius="26" BorderBrush="@@LINE@@" BorderThickness="1" ClipToBounds="True">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="@@CARD@@" Offset="0"/>
        <GradientStop Color="@@BG@@" Offset="0.62"/>
        <GradientStop Color="@@CARD@@" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Grid>
      <Border Margin="8" BorderThickness="1" BorderBrush="@@LINE@@" CornerRadius="20" IsHitTestVisible="False"/>
      <StackPanel x:Name="Boot" VerticalAlignment="Center" HorizontalAlignment="Center">
        <Grid x:Name="BootTile" Width="124" Height="124" HorizontalAlignment="Center"
              Opacity="0" RenderTransformOrigin="0.5,0.5">
          <Grid.RenderTransform><ScaleTransform x:Name="BootScale" ScaleX="0.94" ScaleY="0.94"/></Grid.RenderTransform>
          <Border CornerRadius="30" BorderThickness="1" BorderBrush="@@LINE@@">
            <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="@@TINT@@" Offset="0"/>
                <GradientStop Color="@@CARD@@" Offset="0.7"/>
                <GradientStop Color="@@BG@@" Offset="1"/>
              </LinearGradientBrush>
            </Border.Background>
          </Border>
          <Border CornerRadius="20" Margin="9" Background="@@BG@@" BorderBrush="@@LINE@@" BorderThickness="1" Opacity="0.62"/>
          <Image x:Name="BootLogo" Width="72" Height="72" RenderOptions.BitmapScalingMode="HighQuality"/>
          <Grid Width="94" Height="94" ClipToBounds="True" IsHitTestVisible="False">
            <Border x:Name="BootHighlight" Width="34" HorizontalAlignment="Left" Opacity="0">
              <Border.RenderTransform><TranslateTransform x:Name="HighlightShift" X="-36"/></Border.RenderTransform>
              <Border.Background>
                <LinearGradientBrush StartPoint="0,0.5" EndPoint="1,0.5">
                  <GradientStop Color="#00FFFFFF" Offset="0"/>
                  <GradientStop Color="#66FFFFFF" Offset="0.5"/>
                  <GradientStop Color="#00FFFFFF" Offset="1"/>
                </LinearGradientBrush>
              </Border.Background>
            </Border>
          </Grid>
        </Grid>
        <TextBlock x:Name="BootName" Text="WinNow" FontFamily="Segoe UI Variable Display, Segoe UI" FontSize="30"
                   FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,17,0,0" Opacity="0"/>
        <Border Width="132" Height="4" CornerRadius="2" Background="@@LINE@@" Margin="0,15,0,0" HorizontalAlignment="Center">
          <Border x:Name="BootBar" Width="0" HorizontalAlignment="Left" CornerRadius="2" Background="@@ACCENT@@"/>
        </Border>
        <TextBlock x:Name="BootText" Foreground="@@DIM@@" FontSize="12.5" HorizontalAlignment="Center" Margin="0,10,0,0" Opacity="0"/>
      </StackPanel>
      <Grid x:Name="Chooser" Margin="32,24,32,22" Opacity="0" Visibility="Collapsed">
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
    Dark  = @{ BG = '#FF111D2B'; CARD = '#FF263447'; LINE = '#FF445C78'; FG = '#FFF4F7FC'; DIM = '#FFBECCDF'; ACCENT = '#FF205DC0'; TINT = '#70456890' }
    Navidad = @{ BG = '#FF101F1C'; CARD = '#FF263B34'; LINE = '#FF806D4B'; FG = '#FFFCF8EF'; DIM = '#FFD7DDCD'; ACCENT = '#FFA62D46'; TINT = '#70705A39' }
    Light = @{ BG = '#FFF0F2F7'; CARD = '#FFFBFAF8'; LINE = '#FFCBD6E6'; FG = '#FF152137'; DIM = '#FF495970'; ACCENT = '#FF1556BF'; TINT = '#FFD8E6FA' }
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

function Start-WNLauncherBoot {
    $l = $script:WNL
    $c = $l.Ctl
    if ($l.Animate) {
        $ease = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
        $revealTime = [Windows.Duration][TimeSpan]::FromMilliseconds(370)
        $fade = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, $revealTime
        foreach ($part in $c.BootTile, $c.BootName, $c.BootText) {
            $part.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
        }
        $scale = New-Object Windows.Media.Animation.DoubleAnimation 0.94, 1, $revealTime
        $scale.EasingFunction = $ease
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty, $scale)
        $c.BootScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleYProperty, $scale)
        $c.BootHighlight.Opacity = 0.62
        $sweep = New-Object Windows.Media.Animation.DoubleAnimation -36, 96, ([Windows.Duration][TimeSpan]::FromMilliseconds(520))
        $sweep.BeginTime = [TimeSpan]::FromMilliseconds(220)
        $c.HighlightShift.BeginAnimation([Windows.Media.TranslateTransform]::XProperty, $sweep)
        $line = New-Object Windows.Media.Animation.DoubleAnimation 0, 132, ([Windows.Duration]$l.Timer.Interval)
        $c.BootBar.BeginAnimation([Windows.FrameworkElement]::WidthProperty, $line)
    } else {
        foreach ($part in $c.BootTile, $c.BootName, $c.BootText) { $part.Opacity = 1 }
        $c.BootScale.ScaleX = 1
        $c.BootScale.ScaleY = 1
        $c.BootBar.Width = 132
    }
    if ((Get-WNSettings).Sound -ne $false) {
        $wav = Join-Path $WN.Root 'gui\start.wav'
        if (Test-Path -LiteralPath $wav) { try { $l.Sound = New-Object Media.SoundPlayer $wav; $l.Sound.Play() } catch { } }
    }
    $l.Timer.Start()
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
        if (-not $l.Animate) { $l.Window.Close(); return }
        $out = New-Object Windows.Media.Animation.DoubleAnimation 0, ([Windows.Duration][TimeSpan]::FromMilliseconds(150))
        $out.Add_Completed({ $script:WNL.Window.Close() })
        $l.Window.BeginAnimation([Windows.UIElement]::OpacityProperty, $out)
        return
    }
    if ($l.FirstRun -and -not $l.Update) { $c.Appear.Visibility = 'Visible'; $c.Keys.HorizontalAlignment = 'Right' }
    $c.Boot.Visibility = 'Collapsed'
    $c.Chooser.Visibility = 'Visible'
    if ($l.Animate) {
        $fade = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds(200))
        $c.Chooser.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)
    } else {
        $c.Chooser.Opacity = 1
    }
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
    $themeName = Get-WNEffectiveTheme $saved.GuiTheme
    $light = $themeName -eq 'Light'
    $theme = $script:WNLauncherThemes[$themeName]
    $xaml = $script:WNLauncherXaml
    foreach ($k in $theme.Keys) { $xaml = $xaml.Replace("@@$k@@", $theme[$k]) }
    try { $window = [Windows.Markup.XamlReader]::Parse($xaml) } catch { Write-WNLog "Launcher failed: $($_.Exception.Message)" -Level WARN -Component 'Gui'; return $null }

    $ctl = @{}
    foreach ($n in 'Boot', 'BootTile', 'BootLogo', 'BootScale', 'BootName', 'BootText', 'BootHighlight', 'HighlightShift', 'Chooser', 'SmallLogo',
                   'Heading', 'Version', 'GuiCard', 'TermCard', 'GuiLabel', 'GuiHint', 'TermLabel', 'TermHint', 'Keys', 'LangEn', 'LangEs', 'CloseBtn',
                   'UpdBar', 'UpdText', 'UpdNow', 'UpdLater', 'PreviewTag', 'BootBar', 'Appear', 'AppearLabel', 'AppLight', 'AppDark') {
        $ctl[$n] = $window.FindName($n)
    }
    # First start on this PC (no settings yet): the cards ask for the mode and Light / Dark
    $first = -not @($saved.PSObject.Properties | Where-Object { $_.Name -in 'Lang', 'Mode', 'GuiTheme', 'TourSeen', 'ShortcutAsked' }).Count
    $script:WNL = @{ Window = $window; Ctl = $ctl; Theme = $theme; ThemeName = $themeName; Result = 'exit'; Chosen = $false; Timer = $null
                     Check = $null; Poll = $null; Checked = $false; Update = $null; FirstRun = $first; Appear = $(if ($light) { 'Light' } else { 'Dark' }) }

    $script:WNL.Animate = [Windows.SystemParameters]::ClientAreaAnimation

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
    $file = Join-Path $WN.Root $(switch ($themeName) { 'Light' { 'LOGO\Winnow_128_light.png' } 'Navidad' { 'LOGO\Winnow_128_navidad.png' } default { 'LOGO\Winnow_128.png' } })
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

    $window.Add_ContentRendered({ if (-not $script:WNL.Chosen) { Start-WNLauncherBoot } })
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
