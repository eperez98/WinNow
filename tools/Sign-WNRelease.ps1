# tools/Sign-WNRelease.ps1
# Signs Winnow.zip for a release: writes Winnow.zip.sig (RSA SHA-256, base64), which WinNow checks before it
# installs an update. The private key never leaves this PC; the public key is $script:WNReleaseKey in core\Update.ps1.
#
#   -NewKey      create the key pair once and print the public key to paste into core\Update.ps1
#   -Zip <path>  sign that zip (upload <path>.sig next to it in the GitHub release)
param([switch]$NewKey, [string]$Zip, [string]$KeyFile = (Join-Path $env:APPDATA 'WinNow-signing\release-key.xml'))
$ErrorActionPreference = 'Stop'

if ($NewKey) {
    if (Test-Path -LiteralPath $KeyFile) { throw "A key already exists at $KeyFile. Keep it: releases signed with another key are refused." }
    New-Item -ItemType Directory (Split-Path $KeyFile) -Force | Out-Null
    $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider 3072
    $rsa.PersistKeyInCsp = $false
    Set-Content -LiteralPath $KeyFile -Value $rsa.ToXmlString($true) -Encoding ASCII
    # Only this user can read the private key
    & icacls.exe $KeyFile /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null
    "Private key: $KeyFile (back it up somewhere safe; without it no new release can be signed)"
    "Public key for core\Update.ps1:"
    $rsa.ToXmlString($false)
    return
}

if (-not $Zip) { throw 'Use -NewKey or -Zip <path to Winnow.zip>' }
$rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
$rsa.PersistKeyInCsp = $false
$rsa.FromXmlString((Get-Content -LiteralPath $KeyFile -Raw))
$sig = $rsa.SignData([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Zip)), [Security.Cryptography.SHA256]::Create())
Set-Content -LiteralPath "$Zip.sig" -Value ([Convert]::ToBase64String($sig)) -Encoding ASCII
"Signed: $Zip.sig"
