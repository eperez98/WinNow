param([Parameter(Mandatory)][string]$OutDir)
# WinNow "Linux World" icon (1.6 and later): a terminal-dark tile, the W in terminal green and a penguin (drawn here
# from simple shapes) sitting where the grains are. Writes Winnow_128_linux.png, Winnow_512_linux.png and
# Winnow_linux.ico (16, 24, 32, 48, 64, 256).
# Run with: powershell -STA -File docs\make-linux-icon.ps1 -OutDir <folder>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Penguin in a 100 x 124 box: body, head, belly, eyes, beak, feet
$penguin = @'
<Ellipse Canvas.Left='0' Canvas.Top='14' Width='100' Height='104' Fill='#FF0D0D0D' Stroke='#FF5A5A5A' StrokeThickness='3'/>
<Ellipse Canvas.Left='18' Canvas.Top='0' Width='64' Height='60' Fill='#FF0D0D0D'/>
<Ellipse Canvas.Left='20' Canvas.Top='40' Width='60' Height='76' Fill='#FFF4F4F4'/>
<Ellipse Canvas.Left='31' Canvas.Top='15' Width='15' Height='19' Fill='#FFF4F4F4'/>
<Ellipse Canvas.Left='54' Canvas.Top='15' Width='15' Height='19' Fill='#FFF4F4F4'/>
<Ellipse Canvas.Left='37' Canvas.Top='21' Width='7' Height='9' Fill='#FF0D0D0D'/>
<Ellipse Canvas.Left='56' Canvas.Top='21' Width='7' Height='9' Fill='#FF0D0D0D'/>
<Polygon Points='38,34 62,34 50,48' Fill='#FFF5A623'/>
<Ellipse Canvas.Left='16' Canvas.Top='112' Width='30' Height='12' Fill='#FFF5A623'/>
<Ellipse Canvas.Left='54' Canvas.Top='112' Width='30' Height='12' Fill='#FFF5A623'/>
'@

$xaml = @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='512' Height='512'>
  <Border CornerRadius='112' BorderBrush='#33FFFFFF' BorderThickness='4'>
    <Border.Background>
      <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>
        <GradientStop Color='#FF3A3A3A' Offset='0'/><GradientStop Color='#FF161616' Offset='1'/>
      </LinearGradientBrush>
    </Border.Background>
  </Border>
  <Canvas>
    <Polyline Points='112,104 192,290 256,140 320,290 400,104' StrokeThickness='50' StrokeLineJoin='Round'
              StrokeStartLineCap='Round' StrokeEndLineCap='Round' Stroke='#FF8AE234'/>
    <Canvas Canvas.Left='203' Canvas.Top='318'>
      <Canvas.RenderTransform><ScaleTransform ScaleX='1.06' ScaleY='1.06'/></Canvas.RenderTransform>
      $penguin
    </Canvas>
  </Canvas>
</Grid>
"@

function Save-Icon([int]$Size, [string]$Path) {
    $root = [Windows.Markup.XamlReader]::Parse($xaml)
    $root.Measure([Windows.Size]::new(512, 512)); $root.Arrange([Windows.Rect]::new(0, 0, 512, 512)); $root.UpdateLayout()
    $scale = $Size / 512
    $bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, (96 * $scale), (96 * $scale), ([Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($root)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $fs = [IO.File]::Create($Path); $enc.Save($fs); $fs.Close()
}

$OutDir = [IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory $OutDir -Force | Out-Null
Save-Icon 128 (Join-Path $OutDir 'Winnow_128_linux.png')
Save-Icon 512 (Join-Path $OutDir 'Winnow_512_linux.png')
$sizes = 16, 24, 32, 48, 64, 256
$frames = foreach ($s in $sizes) { $p = Join-Path $env:TEMP "wn-ico-$s.png"; Save-Icon $s $p; ,[IO.File]::ReadAllBytes($p); Remove-Item $p }
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $len = $frames[$i].Length
    $bw.Write([byte]($s % 256)); $bw.Write([byte]($s % 256)); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$len); $bw.Write([uint32]$offset)
    $offset += $len
}
foreach ($f in $frames) { $bw.Write($f) }
$bw.Flush()
[IO.File]::WriteAllBytes((Join-Path $OutDir 'Winnow_linux.ico'), $ms.ToArray())
"icons written to $OutDir"
