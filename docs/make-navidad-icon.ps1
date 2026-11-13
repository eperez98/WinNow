param([Parameter(Mandatory)][string]$OutDir)
# WinNow Christmas icon (Navidad theme, 1.6 and later): pine-green tile, the W in white, the four grains as red and
# gold ornaments and a gold star on top like a tree topper. Writes Winnow_128_navidad.png, Winnow_512_navidad.png and
# Winnow_navidad.ico (16, 24, 32, 48, 64, 256).
# Run with: powershell -STA -File docs\make-navidad-icon.ps1 -OutDir <folder>
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$red = '#FFE53935'; $gold = '#FFF2C14E'

function Get-StarPoints([double]$cx, [double]$cy, [double]$r) {
    $pts = for ($i = 0; $i -lt 10; $i++) {
        $rad = if ($i % 2) { $r * 0.42 } else { $r }
        $a = [Math]::PI * (-90 + 36 * $i) / 180
        '{0:0.##},{1:0.##}' -f ($cx + $rad * [Math]::Cos($a)), ($cy + $rad * [Math]::Sin($a))
    }
    $pts -join ' '
}

function Get-Ornament([double]$cx, [double]$cy, [double]$r, [string]$fill) {
    # Ball, its cap and a soft highlight
    "<Ellipse Canvas.Left='$($cx - $r)' Canvas.Top='$($cy - $r)' Width='$(2 * $r)' Height='$(2 * $r)' Fill='$fill'/>" +
    "<Rectangle Canvas.Left='$($cx - $r * 0.32)' Canvas.Top='$($cy - $r - $r * 0.32)' Width='$($r * 0.64)' Height='$($r * 0.4)' RadiusX='2' RadiusY='2' Fill='#FFD9DDE3'/>" +
    "<Ellipse Canvas.Left='$($cx - $r * 0.55)' Canvas.Top='$($cy - $r * 0.6)' Width='$($r * 0.5)' Height='$($r * 0.36)' Fill='#59FFFFFF'/>"
}

$xaml = @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='512' Height='512'>
  <Border CornerRadius='112' BorderBrush='#33000000' BorderThickness='4'>
    <Border.Background>
      <LinearGradientBrush StartPoint='0,0' EndPoint='1,1'>
        <GradientStop Color='#FF247A4E' Offset='0'/><GradientStop Color='#FF0B3D26' Offset='1'/>
      </LinearGradientBrush>
    </Border.Background>
  </Border>
  <Canvas>
    <Polygon Points='$(Get-StarPoints 256 86 44)' Fill='$gold'/>
    <Polyline Points='112,150 192,330 256,190 320,330 400,150' StrokeThickness='54' StrokeLineJoin='Round'
              StrokeStartLineCap='Round' StrokeEndLineCap='Round' Stroke='White'/>
    $(Get-Ornament 176 414 22 $red)
    $(Get-Ornament 256 398 26 $gold)
    $(Get-Ornament 336 414 22 $red)
    $(Get-Ornament 256 460 14 $gold)
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
Save-Icon 128 (Join-Path $OutDir 'Winnow_128_navidad.png')
Save-Icon 512 (Join-Path $OutDir 'Winnow_512_navidad.png')
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
[IO.File]::WriteAllBytes((Join-Path $OutDir 'Winnow_navidad.ico'), $ms.ToArray())
"icons written to $OutDir"
