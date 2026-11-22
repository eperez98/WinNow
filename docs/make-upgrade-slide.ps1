param([Parameter(Mandatory)][string]$Root)
# Picture for the 1.7.2 'upgrade' slide: upgrade all, one app at a time (example apps, not this PC's list).
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$t = @{
    en = @{ Title = 'Upgrade all apps'; Ok = 'upgraded'; Fail = 'needs an install folder, skipped'; Sum = 'Upgraded 3, failed 1 of 4' }
    es = @{ Title = 'Actualizar todas las apps'; Ok = 'actualizada'; Fail = 'pide una carpeta, se salta'; Sum = 'Actualizadas 3, fallaron 1 de 4' }
}
foreach ($lang in 'en', 'es') {
    $s = $t[$lang]
    $line = {
        param($n, $name, $ok)
        $mark = if ($ok) { "<TextBlock Text='&#x2714;' Foreground='#FF34E0A1' FontSize='15' Width='24'/>" } else { "<TextBlock Text='&#x2716;' Foreground='#FFFF8A65' FontSize='15' Width='24'/>" }
        $note = if ($ok) { $s.Ok } else { $s.Fail }
        "<StackPanel Orientation='Horizontal' Margin='0,0,0,10'>$mark<TextBlock Text='[$n/4]  $name' Foreground='#FFE6EDF3' FontFamily='Cascadia Mono, Consolas' FontSize='15' Width='290'/><TextBlock Text='$note' Foreground='$(if ($ok) { '#FF9AA6C8' } else { '#FFFF8A65' })' FontSize='14'/></StackPanel>"
    }
    $xaml = @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='653' Height='379' Background='#FF0E1220' ClipToBounds='True'>
  <Grid>
    <Canvas>
      <Ellipse Canvas.Left='-140' Canvas.Top='-160' Width='420' Height='420'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='#99A24DF5' Offset='0'/><GradientStop Color='#00A24DF5' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
      <Ellipse Canvas.Left='400' Canvas.Top='170' Width='380' Height='380'><Ellipse.Fill><RadialGradientBrush><GradientStop Color='#883A6BFF' Offset='0'/><GradientStop Color='#003A6BFF' Offset='1'/></RadialGradientBrush></Ellipse.Fill></Ellipse>
    </Canvas>
    <Border Margin='36,34' Background='#E6111520' CornerRadius='12' Padding='22,18' BorderBrush='#33FFFFFF' BorderThickness='1'>
      <StackPanel>
        <TextBlock Text='$($s.Title)' Foreground='#FFFFFFFF' FontSize='18' FontWeight='SemiBold' Margin='0,0,0,14'/>
        <Border Height='6' CornerRadius='3' Background='#26FFFFFF' Margin='0,0,0,18'><Border Width='400' HorizontalAlignment='Left' CornerRadius='3' Background='#FF3A6BFF'/></Border>
        $(& $line 1 'Google Chrome' $true)
        $(& $line 2 'Battle.net' $false)
        $(& $line 3 '7-Zip' $true)
        $(& $line 4 'VLC media player' $true)
        <TextBlock Text='$($s.Sum)' Foreground='#FF64B5FF' FontSize='14.5' FontWeight='SemiBold' Margin='0,8,0,0'/>
      </StackPanel>
    </Border>
  </Grid>
</Border>
"@
    $el = [Windows.Markup.XamlReader]::Parse($xaml)
    $el.Measure([Windows.Size]::new(653, 379)); $el.Arrange([Windows.Rect]::new(0, 0, 653, 379)); $el.UpdateLayout()
    $bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap 653, 379, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($el)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $out = Join-Path $Root "gui\news\$lang\upgrade.png"
    $fs = [IO.File]::Create($out); $enc.Save($fs); $fs.Close()
    "saved $out"
}
