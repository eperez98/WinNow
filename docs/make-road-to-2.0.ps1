param([string]$Out)
# Road to 2.0: a timeline of the next WinNow versions and their goals, rendered to PNG with WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$steps = @(
    @{ V = '1.5'; Name = 'QL Update Mid November'; State = 'now'; Goals = @('New name: WinNow', 'Mes patrio icon', 'Active startup apps first') }
    @{ V = '1.6'; Name = 'GUI Rethinked'; State = 'next'; Goals = @('Launcher with boot animation', 'Flat, minimal icons', 'Update check at start') }
    @{ V = '1.7'; Name = 'Profiles & Schedules'; State = 'next'; Goals = @('Export a PC as a profile', 'Apply it on another PC', 'Scheduled maintenance') }
    @{ V = '1.8'; Name = 'Trusted Updates'; State = 'next'; Tag = 'GUI RETHINKED'; Goals = @('Signed releases', 'Undo a whole session', 'Final, calmer GUI') }
    @{ V = '1.8.1'; Name = 'Polish'; State = 'next'; Goals = @('New closing dialog', 'Light and dark look', 'Shows what it did') }
    @{ V = '1.8.2'; Name = 'Starting Point'; State = 'next'; Goals = @('Starting point tour', 'Office Helper', 'Free Office alternatives') }
    @{ V = '1.8.3'; Name = 'GUI Terminal Update'; State = 'next'; Goals = @('Task window, live output', 'Progress per step', 'Closes when done') }
    @{ V = '2.0'; Name = 'Store Edition'; State = 'goal'; Goals = @('MSIX package', 'Microsoft Store listing', 'Native launcher') }
)
$accent = @{ now = '#FF30D158'; next = '#FF0A84FF'; plan = '#FF8E8E93'; goal = '#FFFF9F0A' }
$label = @{ now = 'RELEASED'; next = 'IN PROGRESS'; plan = 'PLANNED'; goal = 'GOAL' }

function Esc([string]$s) { [Security.SecurityElement]::Escape($s) }
$cols = ''
$i = 0
foreach ($s in $steps) {
    $c = $accent[$s.State]
    $goals = ($s.Goals | ForEach-Object { "<TextBlock Text='&#x2022;  $(Esc $_)' Foreground='#FFC9D1D9' FontSize='15' Margin='0,7,0,0' TextWrapping='Wrap'/>" }) -join ''
    $cols += @"
<StackPanel Grid.Column='$i' Margin='10,0'>
  <Grid Height='40'>
    <Ellipse Width='26' Height='26' Fill='$c' HorizontalAlignment='Center'/>
    <Ellipse Width='10' Height='10' Fill='#FF0D1117' HorizontalAlignment='Center'/>
  </Grid>
  <Border Margin='0,18,0,0' CornerRadius='16' Background='#FF161B22' BorderBrush='$c' BorderThickness='$(if ($s.State -eq 'goal') { 2 } else { 1 })' Padding='18,16' MinHeight='236'>
    <StackPanel>
      <StackPanel Orientation='Horizontal'>
      <Border HorizontalAlignment='Left' CornerRadius='8' Background='$($c -replace '^#FF', '#33')' Padding='8,2'>
        <TextBlock Text='$($label[$s.State])' Foreground='$c' FontSize='11.5' FontWeight='Bold'/>
      </Border>
      $(if ($s.Tag) { "<Border HorizontalAlignment='Left' CornerRadius='8' Background='#330A84FF' Padding='8,2' Margin='6,0,0,0'><TextBlock Text='$(Esc $s.Tag)' Foreground='#FF0A84FF' FontSize='11.5' FontWeight='Bold'/></Border>" })
      </StackPanel>
      <TextBlock Text='$(Esc $s.V)' Foreground='White' FontSize='34' FontWeight='Bold' Margin='0,10,0,0'/>
      <TextBlock Text='$(Esc $s.Name)' Foreground='$c' FontSize='16.5' FontWeight='SemiBold' TextWrapping='Wrap'/>
      $goals
    </StackPanel>
  </Border>
</StackPanel>
"@
    $i++
}
$xaml = @"
<Border xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' Width='2240' Height='560' Background='#FF0D1117' Padding='56,44'>
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height='Auto'/><RowDefinition Height='*'/><RowDefinition Height='Auto'/></Grid.RowDefinitions>
    <StackPanel>
      <TextBlock Text='Road to 2.0' Foreground='White' FontSize='44' FontWeight='Bold' FontFamily='Segoe UI Variable Display, Segoe UI'/>
      <TextBlock Text='WinNow: the goals of each version on the way to the Microsoft Store edition' Foreground='#FF8B949E' FontSize='18' Margin='0,4,0,0'/>
    </StackPanel>
    <Grid Grid.Row='1' Margin='0,34,0,0'>
      <Grid.ColumnDefinitions>$('<ColumnDefinition/>' * $steps.Count)</Grid.ColumnDefinitions>
      <Border Grid.ColumnSpan='$($steps.Count)' Height='4' VerticalAlignment='Top' Margin='140,18,140,0' CornerRadius='2'>
        <Border.Background>
          <LinearGradientBrush StartPoint='0,0' EndPoint='1,0'>
            <GradientStop Color='#FF30D158' Offset='0'/><GradientStop Color='#FF0A84FF' Offset='0.35'/>
            <GradientStop Color='#FF8E8E93' Offset='0.7'/><GradientStop Color='#FFFF9F0A' Offset='1'/>
          </LinearGradientBrush>
        </Border.Background>
      </Border>
      $cols
    </Grid>
    <TextBlock Grid.Row='2' Text='Ideas, not promises: more changes may be added and others removed.' Foreground='#FF8B949E' FontSize='14.5' Margin='10,20,0,0'/>
  </Grid>
</Border>
"@
$root = [Windows.Markup.XamlReader]::Parse($xaml)
$root.Measure([Windows.Size]::new(2240, 560))
$root.Arrange([Windows.Rect]::new(0, 0, 2240, 560))
$root.UpdateLayout()
$scale = 1.5
$bmp = New-Object Windows.Media.Imaging.RenderTargetBitmap ([int](2240 * $scale)), ([int](560 * $scale)), (96 * $scale), (96 * $scale), ([Windows.Media.PixelFormats]::Pbgra32)
$bmp.Render($root)
$enc = New-Object Windows.Media.Imaging.PngBitmapEncoder
$enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
$fs = [IO.File]::Create($Out); $enc.Save($fs); $fs.Close()
"saved $Out"
