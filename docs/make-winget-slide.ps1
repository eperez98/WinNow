param([Parameter(Mandatory)][string]$Root)
# Picture for the 1.7.1 'winget' slide (no real app list): before / after timing of the installed-apps read.
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$t = @{
    en = @{ Before = 'Before'; After = '1.7.1'; Cmd1 = 'winget export  (winget + Microsoft Store)'; Cmd2 = 'winget export --source winget'; T1 = 'minutes'; T2 = 'seconds'; Note = 'The last list shows at once; a hang stops after 90 s' }
    es = @{ Before = 'Antes'; After = '1.7.1'; Cmd1 = 'winget export  (winget + Microsoft Store)'; Cmd2 = 'winget export --source winget'; T1 = 'minutos'; T2 = 'segundos'; Note = 'La ultima lista aparece al instante; un cuelgue se detiene a los 90 s' }
}
foreach ($lang in 'en', 'es') {
    $s = $t[$lang]
    if ($lang -eq 'es') { $s.Note = $s.Note.Replace('ultima', "$([char]0xFA)ltima") }
    $row = {
        param($label, $cmd, $time, $width, $color)
        @"
<StackPanel Margin='0,0,0,26'>
  <TextBlock Text='$label' Foreground='#FFB9C3E6' FontSize='15' FontWeight='SemiBold'/>
  <Border Background='#E6111520' CornerRadius='10' Padding='16,12' Margin='0,8,0,0' BorderBrush='#33FFFFFF' BorderThickness='1'>
    <StackPanel>
      <TextBlock Text='&gt; $cmd' Foreground='#FFE6EDF3' FontFamily='Cascadia Mono, Consolas' FontSize='15'/>
      <DockPanel Margin='0,12,0,0'>
        <TextBlock DockPanel.Dock='Right' Text='$time' Foreground='$color' FontSize='15' FontWeight='SemiBold' Margin='12,0,0,0' VerticalAlignment='Center'/>
        <Border Height='8' CornerRadius='4' Background='#26FFFFFF'><Border Width='$width' HorizontalAlignment='Left' CornerRadius='4' Background='$color'/></Border>
      </DockPanel>
    </StackPanel>
  </Border>
</StackPanel>
"@
    }
    $xaml = @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='653' Height='379' Background='#FF0E1220' ClipToBounds='True'>
  <Grid>
    <Canvas>
      <Ellipse Canvas.Left='-140' Canvas.Top='-160' Width='420' Height='420'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='#993A6BFF' Offset='0'/><GradientStop Color='#003A6BFF' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
      <Ellipse Canvas.Left='400' Canvas.Top='170' Width='380' Height='380'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='#8814B8A6' Offset='0'/><GradientStop Color='#0014B8A6' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
    </Canvas>
    <StackPanel Margin='40,34,40,0'>
      $(& $row $s.Before $s.Cmd1 $s.T1 470 '#FFFF8A65')
      $(& $row $s.After $s.Cmd2 $s.T2 34 '#FF34E0A1')
      <TextBlock Text='$($s.Note)' Foreground='#FF9AA6C8' FontSize='13.5'/>
    </StackPanel>
  </Grid>
</Border>
"@
    $el = [Windows.Markup.XamlReader]::Parse($xaml)
    $el.Measure([Windows.Size]::new(653, 379)); $el.Arrange([Windows.Rect]::new(0, 0, 653, 379)); $el.UpdateLayout()
    $bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 653, 379, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($el)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $out = Join-Path $Root "gui\news\$lang\winget.png"
    $fs = [IO.File]::Create($out); $enc.Save($fs); $fs.Close()
    "saved $out"
}
