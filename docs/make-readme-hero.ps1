param([ValidateSet('en', 'es')][string]$Lang = 'en', [string]$Out = (Join-Path $PSScriptRoot "readme-hero-$Lang.png"))
# README hero (1280x640): name and pitch on the left, the window (screenshots/<lang>/home.png) on the right.
#   powershell -STA -File docs/make-readme-hero.ps1 -Lang en   (and -Lang es)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$root = Split-Path $PSScriptRoot
$icon = ([Uri](Join-Path $root 'LOGO\Winnow_512.png')).AbsoluteUri
$shot = ([Uri](Join-Path $root "screenshots\$Lang\home.png")).AbsoluteUri
# Non-ASCII letters come from char codes: the script stays ASCII for Windows PowerShell 5.1
$d = [char]0xB7; $nn = [char]0xF1; $ee = [char]0xE9
$t = @{
    en = @{ L1 = 'Debloat and maintain'; L2 = 'Windows 10 and 11'; Sub = "Terminal or window $d English and Spanish $d Undo anything" }
    es = @{ L1 = "Limpia y mant$($ee)n"; L2 = 'Windows 10 y 11'; Sub = "Terminal o ventana $d Espa$($nn)ol e ingl$($ee)s $d Todo se deshace" }
}[$Lang]
$xaml = @"
<Canvas xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='1280' Height='640' ClipToBounds='True'
        TextOptions.TextFormattingMode='Display'>
  <Canvas.Background>
    <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>
      <GradientStop Color='#FF123A5C' Offset='0'/><GradientStop Color='#FF0B1626' Offset='0.55'/><GradientStop Color='#FF0A0F14' Offset='1'/>
    </LinearGradientBrush>
  </Canvas.Background>
  <Border Canvas.Left='600' Canvas.Top='76' Width='900' CornerRadius='14' Background='#FF202020' BorderBrush='#33FFFFFF' BorderThickness='1'>
    <Border.Effect><DropShadowEffect BlurRadius='40' ShadowDepth='0' Opacity='0.55'/></Border.Effect>
    <StackPanel>
      <StackPanel Orientation='Horizontal' Margin='16,12,0,10'>
        <Ellipse Width='11' Height='11' Fill='#55FFFFFF' Margin='0,0,8,0'/><Ellipse Width='11' Height='11' Fill='#55FFFFFF' Margin='0,0,8,0'/><Ellipse Width='11' Height='11' Fill='#55FFFFFF'/>
      </StackPanel>
      <Image Source='$shot' Width='900' Stretch='Uniform' RenderOptions.BitmapScalingMode='HighQuality'/>
    </StackPanel>
  </Border>
  <StackPanel Canvas.Left='72' Canvas.Top='0' Height='640' Width='520'>
    <StackPanel Orientation='Horizontal' Margin='0,208,0,0'>
      <Image Source='$icon' Width='64' Height='64' RenderOptions.BitmapScalingMode='HighQuality'/>
      <TextBlock Text='WinNow' Foreground='White' FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='54' FontWeight='Bold'
                 VerticalAlignment='Center' Margin='18,0,0,4'/>
    </StackPanel>
    <TextBlock Text='$($t.L1)' Foreground='White' FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='42' FontWeight='SemiBold' Margin='0,30,0,0'/>
    <TextBlock Text='$($t.L2)' Foreground='#FF2DD4BF' FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='42' FontWeight='SemiBold'/>
    <TextBlock Text='$($t.Sub)' Foreground='#FFB6C2CF' FontSize='19' TextWrapping='Wrap' Margin='0,18,0,0'/>
    <TextBlock Text='Proudly made in Panama PTY507' Foreground='#FF7D8894' FontSize='16' Margin='0,26,0,0'/>
  </StackPanel>
</Canvas>
"@
$el = [Windows.Markup.XamlReader]::Parse($xaml)
$el.Measure([Windows.Size]::new(1280, 640)); $el.Arrange([Windows.Rect]::new(0, 0, 1280, 640)); $el.UpdateLayout()
# Images load asynchronously; let the dispatcher finish before rendering
$f = New-Object Windows.Threading.DispatcherFrame
[void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action]{ $f.Continue = $false })
[Windows.Threading.Dispatcher]::PushFrame($f)
$el.UpdateLayout()
$bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 1280, 640, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
$bmp.Render($el)
$enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
$fs = [IO.File]::Create([IO.Path]::GetFullPath($Out)); $enc.Save($fs); $fs.Close()
"saved $Out"
