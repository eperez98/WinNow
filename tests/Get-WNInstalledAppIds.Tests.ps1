# Self-check: the installed-app set must stay a HashSet so Install/Uninstall can Add/Remove ids.
# Run: powershell -File tests\Get-WNInstalledAppIds.Tests.ps1
. "$PSScriptRoot\..\modules\Apps.ps1"
$global:WN = @{ Cache = @{} }
function Find-WNWinget { $null }   # no winget: empty set, no external call
foreach ($pass in 'fresh', 'cached') {
    $set = Get-WNInstalledAppIds
    if ($set -isnot [System.Collections.Generic.HashSet[string]]) { throw "FAIL ($pass) returned $($set.GetType().FullName)" }
    [void]$set.Add('Mozilla.Firefox')
    if (-not $set.Contains('mozilla.firefox')) { throw "FAIL ($pass) lookup is not case-insensitive" }
    [void]$set.Remove('Mozilla.Firefox')
}
$sorted = @((Get-WNInstalledAppIds) | Sort-Object)
if ($sorted.Count -ne 0) { throw 'FAIL piping the set should enumerate its ids' }
'Get-WNInstalledAppIds: all cases pass'
