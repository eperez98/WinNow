param([Parameter(Mandatory)][string]$OutDir)
# WinNow logo "Glass W" (1.7 and later): a white W on a frosted glass pane over soft colour blobs, with a small
# mark under the W for "Now" (a gold grain; a star for Navidad and Mes patrio). Writes into $OutDir (a LOGO folder):
#   Winnow_128/512(.png), _light, _navidad, _patria, _linux; Winnow_icon_256.png; Winnow.ico, Winnow_navidad.ico,
#   Winnow_patria.ico, Winnow_linux.ico (16-256); Winnow_logo.png and Winnow_logo_light.png (1200x360 banners).
# Run with: powershell -STA -File tools\make-logo.ps1 -OutDir <build>\LOGO
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$variants = @{
    ''         = @{ Bg = '#FF0E1220'; Blobs = @('#FF3A6BFF', '#FFB04DF5', '#FF14C8B0'); Pane = @('#40FFFFFF', '#14FFFFFF'); Edge = @('#B3FFFFFF', '#26FFFFFF'); W = '#FFFFFFFF'; Glow = '#FF9DB8FF'; Mark = 'dot'; MarkFill = '#FFFFD166' }
    '_light'   = @{ Bg = '#FFEEF2FA'; Blobs = @('#FF8DB6FF', '#FFE2A8FF', '#FF7FE3CB'); Pane = @('#99FFFFFF', '#59FFFFFF'); Edge = @('#FFFFFFFF', '#66FFFFFF'); W = '#FF1B2550'; Glow = '#00000000'; Mark = 'dot'; MarkFill = '#FFF0A020' }
    '_navidad' = @{ Bg = '#FF0B2016'; Blobs = @('#FF2E9D5B', '#FFC8102E', '#FFF2C14E'); Pane = @('#40FFFFFF', '#14FFFFFF'); Edge = @('#B3FFFFFF', '#26FFFFFF'); W = '#FFFFFFFF'; Glow = '#FFFFE3A1'; Mark = 'star'; MarkFill = '#FFF2C14E' }
    '_patria'  = @{ Bg = '#FF0B2A52'; Blobs = @('#FF1A6FD1', '#FFD21034', '#FF3A7BFF'); Pane = @('#40FFFFFF', '#14FFFFFF'); Edge = @('#B3FFFFFF', '#26FFFFFF'); W = '#FFFFFFFF'; Glow = '#FFFFB3BF'; Mark = 'star'; MarkFill = '#FFFFFFFF' }
    '_linux'   = @{ Bg = '#FF1E1E1E'; Blobs = @('#FFE95420', '#FF77216F', '#FF4E9A06'); Pane = @('#40FFFFFF', '#14FFFFFF'); Edge = @('#B3FFFFFF', '#26FFFFFF'); W = '#FFFFFFFF'; Glow = '#FFFFC2A6'; Mark = 'dot'; MarkFill = '#FF8AE234' }
}

function Get-StarPoints([double]$cx, [double]$cy, [double]$r) {
    (0..9 | ForEach-Object {
        $rad = if ($_ % 2) { $r * 0.42 } else { $r }
        $a = [Math]::PI * (-90 + 36 * $_) / 180
        '{0:0.##},{1:0.##}' -f ($cx + $rad * [Math]::Cos($a)), ($cy + $rad * [Math]::Sin($a))
    }) -join ' '
}

function Get-TileXaml($v) {
    $blob = { param($x, $y, $d, $c) "<Ellipse Canvas.Left='$x' Canvas.Top='$y' Width='$d' Height='$d'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='$c' Offset='0'/><GradientStop Color='#00$($c.Substring(3))' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>" }
    $mark = if ($v.Mark -eq 'star') { "<Polygon Points='$(Get-StarPoints 256 404 26)' Fill='$($v.MarkFill)'/>" } else { "<Ellipse Canvas.Left='238' Canvas.Top='384' Width='36' Height='36' Fill='$($v.MarkFill)'/>" }
    @"
<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='512' Height='512'>
  <Border CornerRadius='118' Background='$($v.Bg)'/>
  <Canvas>
    $(& $blob -120 -140 460 $v.Blobs[0])
    $(& $blob 200 170 440 $v.Blobs[1])
    $(& $blob -110 250 380 $v.Blobs[2])
  </Canvas>
  <Border Margin='58' CornerRadius='76' BorderThickness='3'>
    <Border.Background><LinearGradientBrush StartPoint='0,0' EndPoint='0.6,1'><GradientStop Color='$($v.Pane[0])' Offset='0'/><GradientStop Color='$($v.Pane[1])' Offset='1'/></LinearGradientBrush></Border.Background>
    <Border.BorderBrush><LinearGradientBrush StartPoint='0,0' EndPoint='0,1'><GradientStop Color='$($v.Edge[0])' Offset='0'/><GradientStop Color='$($v.Edge[1])' Offset='1'/></LinearGradientBrush></Border.BorderBrush>
  </Border>
  <Canvas>
    <Polyline Points='112,150 186,356 256,214 326,356 400,150' StrokeThickness='50' StrokeLineJoin='Round' StrokeStartLineCap='Round' StrokeEndLineCap='Round' Stroke='$($v.W)'>
      <Polyline.Effect><DropShadowEffect Color='$($v.Glow)' BlurRadius='26' ShadowDepth='0' Opacity='0.7'/></Polyline.Effect>
    </Polyline>
    $mark
  </Canvas>
</Grid>
"@
}

function Get-Bitmap([string]$Xaml, [int]$W, [int]$H, [int]$Size) {
    # Renders a $W x $H design at $Size px wide; the tile is clipped to its rounded square
    $el = [Windows.Markup.XamlReader]::Parse($Xaml)
    if ($W -eq 512 -and $H -eq 512) { $el.Clip = New-Object Windows.Media.RectangleGeometry ([Windows.Rect]::new(0, 0, 512, 512)), 118, 118 }
    $box = New-Object Windows.Controls.Viewbox
    $ph = [int]($Size * $H / $W)
    $box.Width = $Size; $box.Height = $ph; $box.Child = $el
    $box.Measure([Windows.Size]::new($Size, $ph)); $box.Arrange([Windows.Rect]::new(0, 0, $Size, $ph)); $box.UpdateLayout()
    $bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $ph, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($box)
    return $bmp
}
function Get-Png($Bmp) {
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($Bmp))
    $ms = New-Object IO.MemoryStream; $enc.Save($ms); return , $ms.ToArray()
}
function Save-Ico([string]$Xaml, [string]$Path) {
    # .ico with PNG frames (Windows Vista and later read them)
    $sizes = 16, 24, 32, 48, 64, 256
    $frames = foreach ($s in $sizes) { , (Get-Png (Get-Bitmap $Xaml 512 512 $s)) }
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
    [IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

function Get-BannerXaml([string]$Suffix) {
    $light = $Suffix -eq '_light'
    $v = $variants[$Suffix]
    $tile = (Get-TileXaml $v) -replace "<Grid xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='512' Height='512'>", "<Grid Width='512' Height='512'><Grid.Clip><RectangleGeometry Rect='0,0,512,512' RadiusX='118' RadiusY='118'/></Grid.Clip>"
    $bg = if ($light) { '#FFF4F6FB' } else { '#FF0D111C' }
    $fg = if ($light) { '#FF141A2E' } else { '#FFFFFFFF' }
    $sub = if ($light) { '#FF4A5578' } else { '#FFB9C3E6' }
    @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='1200' Height='360' CornerRadius='36' Background='$bg' ClipToBounds='True'>
  <Grid>
    <Canvas>
      <Ellipse Canvas.Left='-160' Canvas.Top='-200' Width='620' Height='620' Opacity='$(if ($light) { 0.55 } else { 0.45 })'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='$($v.Blobs[0])' Offset='0'/><GradientStop Color='#00000000' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
      <Ellipse Canvas.Left='820' Canvas.Top='40' Width='560' Height='560' Opacity='$(if ($light) { 0.5 } else { 0.4 })'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='$($v.Blobs[1])' Offset='0'/><GradientStop Color='#00000000' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
    </Canvas>
    <StackPanel Orientation='Horizontal' VerticalAlignment='Center' Margin='64,0,0,0'>
      <Viewbox Width='236' Height='236'>$tile</Viewbox>
      <StackPanel VerticalAlignment='Center' Margin='52,0,0,8'>
        <TextBlock FontFamily='Segoe UI Variable Display, Segoe UI' FontSize='132' FontWeight='SemiBold' Foreground='$fg'>
          <Run Text='Win'/><Run Text='Now'><Run.Foreground><LinearGradientBrush StartPoint='0,0' EndPoint='1,0'><GradientStop Color='#FF3A6BFF' Offset='0'/><GradientStop Color='#FFB04DF5' Offset='1'/></LinearGradientBrush></Run.Foreground></Run>
        </TextBlock>
        <TextBlock Text='sift Windows down to what matters' FontSize='34' Foreground='$sub' Margin='6,0,0,0'/>
      </StackPanel>
    </StackPanel>
  </Grid>
</Border>
"@
}

$OutDir = [IO.Path]::GetFullPath($OutDir)
foreach ($k in $variants.Keys) {
    $x = Get-TileXaml $variants[$k]
    foreach ($s in 128, 512) { [IO.File]::WriteAllBytes((Join-Path $OutDir "Winnow_$s$k.png"), (Get-Png (Get-Bitmap $x 512 512 $s))) }
    if ($k -eq '') {
        [IO.File]::WriteAllBytes((Join-Path $OutDir 'Winnow_icon_256.png'), (Get-Png (Get-Bitmap $x 512 512 256)))
        Save-Ico $x (Join-Path $OutDir 'Winnow.ico')
    } elseif ($k -ne '_light') { Save-Ico $x (Join-Path $OutDir "Winnow$k.ico") }
}
foreach ($k in '', '_light') { [IO.File]::WriteAllBytes((Join-Path $OutDir "Winnow_logo$k.png"), (Get-Png (Get-Bitmap (Get-BannerXaml $k) 1200 360 1200))) }
"logo written to $OutDir"
