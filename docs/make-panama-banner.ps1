param([string]$Name = 'WinNow', [switch]$Dark, [string]$Icon = (Join-Path $PSScriptRoot '..\LOGO\Winnow_512.png'), [string]$Out)
# README banner for November (Panama's patriotic month): the mes patrio icon, the name in Panama blue and red,
# the tagline and "Proudly made in Panama PTY507". -Name 'Winnow' for the builds before 1.5. 1200x360 like the old one.
# Run with: powershell -STA -File docs\make-panama-banner.ps1 -Out LOGO\Winnow_logo_light.png [-Dark] [-Name Winnow]
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$iconUri = ([Uri][IO.Path]::GetFullPath($Icon)).AbsoluteUri
# Flag colours on white; lighter tints of the same hues on the dark card so they keep their contrast
$c = if ($Dark) { @{ Bg1 = '#FF161B22'; Bg2 = '#FF0D1117'; Line = '#FF30363D'; A = '#FF6EA8FF'; B = '#FFFF6B7D'; Text = '#FFC9D1D9'; Dim = '#FF8B949E' } }
     else { @{ Bg1 = '#FFFFFFFF'; Bg2 = '#FFEFF3F8'; Line = '#FFD8DEE6'; A = '#FF005293'; B = '#FFD21034'; Text = '#FF2B3036'; Dim = '#FF5C6570' } }
$first, $second = $Name.Substring(0, 3), $Name.Substring(3)
$xaml = @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='1200' Height='360' CornerRadius='24'
        BorderBrush='$($c.Line)' BorderThickness='2' Padding='64,0'>
  <Border.Background>
    <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'><GradientStop Color='$($c.Bg1)' Offset='0'/><GradientStop Color='$($c.Bg2)' Offset='1'/></LinearGradientBrush>
  </Border.Background>
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width='Auto'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>
    <Image Source='$iconUri' Width='236' Height='236' VerticalAlignment='Center' RenderOptions.BitmapScalingMode='HighQuality'/>
    <StackPanel Grid.Column='1' Margin='56,0,0,0' VerticalAlignment='Center'>
      <TextBlock FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='128' FontWeight='SemiBold' Margin='-6,-18,0,0'>
        <Run Text='$first' Foreground='$($c.A)'/><Run Text='$second' Foreground='$($c.B)'/>
      </TextBlock>
      <TextBlock Text='sift Windows down to what matters' Foreground='$($c.Text)' FontSize='38' Margin='2,0,0,0'/>
      <TextBlock Text='Proudly made in Panama PTY507' Foreground='$($c.Dim)' FontSize='24' Margin='2,14,0,0'/>
    </StackPanel>
  </Grid>
</Border>
"@
$root = [Windows.Markup.XamlReader]::Parse($xaml)
$root.Measure([Windows.Size]::new(1200, 360)); $root.Arrange([Windows.Rect]::new(0, 0, 1200, 360)); $root.UpdateLayout()
# The icon loads asynchronously; let the dispatcher finish before rendering
$f = New-Object Windows.Threading.DispatcherFrame
[void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action]{ $f.Continue = $false })
[Windows.Threading.Dispatcher]::PushFrame($f)
$bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 1200, 360, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
$bmp.Render($root)
$enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
$fs = [IO.File]::Create([IO.Path]::GetFullPath($Out)); $enc.Save($fs); $fs.Close()
"saved $Out"
