param([string]$Icon = (Join-Path $PSScriptRoot '..\LOGO\Winnow_512.png'), [string]$Out = (Join-Path $PSScriptRoot 'social-preview.png'))
# GitHub social preview (1280x640): the card shown when the repo link is pasted in LinkedIn, X, Slack...
# Upload it in the repo's Settings > General > Social preview (GitHub has no API for it).
#   -Icon: the 512 px app icon to show (the 1.5 one wears the flag of Panama for November)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$iconUri = ([Uri][IO.Path]::GetFullPath($Icon)).AbsoluteUri
$xaml = @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='1280' Height='640' Background='#FF0D1117'
        Padding='88,0' TextOptions.TextFormattingMode='Display'>
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width='Auto'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions>
    <Image Source='$iconUri' Width='232' Height='232' VerticalAlignment='Center' RenderOptions.BitmapScalingMode='HighQuality'/>
    <StackPanel Grid.Column='1' Margin='64,0,0,0' VerticalAlignment='Center'>
      <TextBlock Text='WinNow' Foreground='White' FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='104' FontWeight='Bold'/>
      <TextBlock Text='Debloat, harden and maintain Windows 10/11' Foreground='#FFC9D1D9' FontSize='30' Margin='4,0,0,0'/>
      <TextBlock Text='from the terminal or a window, in English and Spanish' Foreground='#FF8B949E' FontSize='24' Margin='4,6,0,0'/>
      <Border HorizontalAlignment='Left' CornerRadius='8' Background='#FF161B22' BorderBrush='#FF30363D' BorderThickness='1'
              Padding='18,10' Margin='4,34,0,0'>
        <TextBlock Text='irm eperez98.github.io/WinNow | iex' Foreground='#FFE6EDF3' FontFamily='Cascadia Mono, Consolas' FontSize='24'/>
      </Border>
    </StackPanel>
    <TextBlock Grid.ColumnSpan='2' Text='Proudly made in Panama PTY507' Foreground='#FF8B949E' FontSize='20'
               HorizontalAlignment='Left' VerticalAlignment='Bottom' Margin='0,0,0,44'/>
    <TextBlock Grid.ColumnSpan='2' Text='github.com/eperez98/WinNow' Foreground='#FF8B949E' FontSize='20'
               HorizontalAlignment='Right' VerticalAlignment='Bottom' Margin='0,0,0,44'/>
  </Grid>
</Border>
"@
$root = [Windows.Markup.XamlReader]::Parse($xaml)
$root.Measure([Windows.Size]::new(1280, 640)); $root.Arrange([Windows.Rect]::new(0, 0, 1280, 640)); $root.UpdateLayout()
# Images load asynchronously; let the dispatcher finish before rendering
$f = New-Object Windows.Threading.DispatcherFrame
[void][Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::ApplicationIdle, [Action]{ $f.Continue = $false })
[Windows.Threading.Dispatcher]::PushFrame($f)
$bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 1280, 640, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
$bmp.Render($root)
$enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
$fs = [IO.File]::Create([IO.Path]::GetFullPath($Out)); $enc.Save($fs); $fs.Close()
"saved $Out"
