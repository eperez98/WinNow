# Self-check for the winget table parser. Run: powershell -File tests\ConvertFrom-WNWingetTable.Tests.ps1
. "$PSScriptRoot\..\modules\Apps.ps1"
$e = [char]0x2026
$lines = @(
    "   - `r   \ `rNombre                  Id                     Versión   Coincidencia",
    '-----------------------------------------------------------------------',
    'Mozilla Firefox (en-US)  Mozilla.Firefox        157.0.1   Moniker: firefox',
    "Some Very Long App Name   Vendor.SomeVeryLong$e  1.0",
    'Tor Browser              TorProject.TorBrowser  15.0'
)
$r = @(ConvertFrom-WNWingetTable $lines)
if ($r.Count -ne 2) { throw "FAIL expected 2 rows, got $($r.Count)" }
if ($r[0].Name -ne 'Mozilla Firefox (en-US)' -or $r[0].Id -ne 'Mozilla.Firefox' -or $r[0].Version -ne '157.0.1') { throw "FAIL row 0: $($r[0])" }
if ($r[1].Id -ne 'TorProject.TorBrowser' -or $r[1].Version -ne '15.0') { throw "FAIL row 1: $($r[1])" }
if (@(ConvertFrom-WNWingetTable @('No package found matching input criteria.')).Count) { throw 'FAIL no-results text parsed as rows' }
if (@(ConvertFrom-WNWingetTable @('Name  Id  Version', '----------------------')).Count) { throw 'FAIL header-only table' }
'ConvertFrom-WNWingetTable: all cases pass'
