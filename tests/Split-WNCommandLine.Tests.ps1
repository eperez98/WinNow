# Self-check for Split-WNCommandLine with real uninstall strings. Run: powershell -File tests\Split-WNCommandLine.Tests.ps1
. "$PSScriptRoot\..\modules\Uninstall.ps1"
$sys = "$env:SystemRoot\System32\cmd.exe"   # an exe that exists on every PC, used for the unquoted-path cases
$cases = @(
    @("`"C:\Program Files (x86)\Steam\steam.exe`" steam://uninstall/123", 'C:\Program Files (x86)\Steam\steam.exe', 'steam://uninstall/123'),
    @("`"C:\X\OneDriveSetup.exe`"  /uninstall  /allusers ", 'C:\X\OneDriveSetup.exe', '/uninstall  /allusers'),
    @("$sys /S", $sys, '/S'),
    @($sys, $sys, ''),
    @('winget uninstall --product-code abc', 'winget', 'uninstall --product-code abc')
)
foreach ($c in $cases) {
    $exe, $args2 = Split-WNCommandLine $c[0]
    if ($exe -ne $c[1] -or $args2 -ne $c[2]) { throw "FAIL '$($c[0])' -> exe='$exe' args='$args2'" }
}
'Split-WNCommandLine: all cases pass'
