param([string]$OutDir = (Join-Path $PSScriptRoot '..\LOGO'))
# WinNow 1.5 "mes patrio" icon: the WinNow tile in the colours of the flag of Panama. White field, the W in
# Panama blue on the left half and Panama red on the right (split like the flag's quarters), and the flag's two
# five-point stars (blue and red) in place of the four grains.
# Writes Winnow_<size>.png, the _light copies, Winnow_icon_256.png and Winnow.ico (16, 24, 32, 48, 64, 256).
# Run with: powershell -STA -File docs\make-panama-icon.ps1
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$blue = '#FF005293'; $red = '#FFD21034'

function Get-StarPoints([double]$cx, [double]$cy, [double]$r) {
    # Five-point star, one point up; inner radius as on the flag (0.382 of the outer)
    $pts = for ($i = 0; $i -lt 10; $i++) {
        $rad = if ($i % 2) { $r * 0.382 } else { $r }
        $a = [Math]::PI * (-90 + 36 * $i) / 180
        '{0:0.##},{1:0.##}' -f ($cx + $rad * [Math]::Cos($a)), ($cy + $rad * [Math]::Sin($a))
    }
    $pts -join ' '
}

$xaml = @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='512' Height='512'>
  <Border CornerRadius='112' BorderBrush='#26000000' BorderThickness='4'>
    <Border.Background>
      <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>
        <GradientStop Color='#FFFFFFFF' Offset='0'/><GradientStop Color='#FFE9EEF5' Offset='1'/>
      </LinearGradientBrush>
    </Border.Background>
  </Border>
  <Canvas>
    <Polyline Points='112,122 192,322 256,168 320,322 400,122' StrokeThickness='54' StrokeLineJoin='Round'
              StrokeStartLineCap='Round' StrokeEndLineCap='Round'>
      <Polyline.Stroke>
        <LinearGradientBrush StartPoint='0,0' EndPoint='1,0'>
          <GradientStop Color='$blue' Offset='0'/><GradientStop Color='$blue' Offset='0.5'/><GradientStop Color='$red' Offset='0.5'/><GradientStop Color='$red' Offset='1'/>
        </LinearGradientBrush>
      </Polyline.Stroke>
    </Polyline>
    <Polygon Points='$(Get-StarPoints 190 414 46)' Fill='$blue'/>
    <Polygon Points='$(Get-StarPoints 322 414 46)' Fill='$red'/>
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
foreach ($n in 'Winnow_128', 'Winnow_128_light') { Save-Icon 128 (Join-Path $OutDir "$n.png") }
foreach ($n in 'Winnow_512', 'Winnow_512_light') { Save-Icon 512 (Join-Path $OutDir "$n.png") }
Save-Icon 256 (Join-Path $OutDir 'Winnow_icon_256.png')

# .ico with PNG frames (Windows Vista and later read them)
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
[IO.File]::WriteAllBytes((Join-Path $OutDir 'Winnow.ico'), $ms.ToArray())
"icons written to $OutDir"
