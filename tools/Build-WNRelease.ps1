# Builds and verifies the assets expected by the GitHub Pages launcher.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$KeyFile = (Join-Path $env:APPDATA 'WinNow-signing\release-key.xml')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $Source).ProviderPath
$out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$entries = foreach ($name in 'Launch.bat', 'Winnow.ps1', 'Winnow_icon.png') {
    Get-Item -LiteralPath (Join-Path $root $name) -ErrorAction Stop
}
foreach ($name in 'core', 'modules', 'gui', 'config', 'LOGO') {
    $entries += Get-ChildItem -LiteralPath (Join-Path $root $name) -File -Recurse
}
$launcher = Get-Content -LiteralPath (Join-Path $root 'run.ps1') -Raw
$updater = Get-Content -LiteralPath (Join-Path $root 'core\Update.ps1') -Raw
$pin = [regex]::Match($launcher, '<RSAKeyValue>[^'']+</RSAKeyValue>').Value
$updatePin = [regex]::Match($updater, '<RSAKeyValue>[^'']+</RSAKeyValue>').Value
if (-not $pin -or $pin -cne $updatePin) { throw 'The launcher and updater must use the same release key.' }

$rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
$rsa.PersistKeyInCsp = $false
try {
    $rsa.FromXmlString((Get-Content -LiteralPath $KeyFile -Raw))
    if ($rsa.ToXmlString($false) -cne $pin) { throw 'The signing key does not match the public release key.' }
    [void][IO.Directory]::CreateDirectory($out)
    $zipFile = Join-Path $out 'Winnow.zip'
    $sigFile = "$zipFile.sig"
    $runFile = Join-Path $out 'run.ps1'
    foreach ($path in $zipFile, $sigFile, $runFile) {
        if (Test-Path -LiteralPath $path) { throw "Release asset already exists: $path" }
    }
    $archive = [IO.Compression.ZipFile]::Open($zipFile, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $entries | Sort-Object FullName) {
            $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $relative)
        }
    } finally { $archive.Dispose() }

    $bytes = [IO.File]::ReadAllBytes($zipFile)
    $signature = $rsa.SignData($bytes, 'SHA256')
    $rsa.FromXmlString($pin)
    if (-not $rsa.VerifyData($bytes, 'SHA256', $signature)) { throw 'Generated signature did not verify.' }
    [IO.File]::WriteAllText($sigFile, [Convert]::ToBase64String($signature))
    Copy-Item -LiteralPath (Join-Path $root 'run.ps1') -Destination $runFile
    Get-FileHash -LiteralPath $zipFile, $sigFile, $runFile -Algorithm SHA256
} finally { $rsa.Dispose() }
