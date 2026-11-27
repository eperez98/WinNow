<#
    WinNow one-line launcher:

        irm eperez98.github.io/WinNow | iex

    That page (the gh-pages branch) runs this file from the latest release.

    Verifies the latest release ZIP, extracts it to a unique folder in %TEMP%, and starts Winnow.ps1 (elevated when
    needed), which asks for the language and the mode (terminal or graphical interface). Nothing is
    installed; on exit WinNow offers a desktop shortcut or deletes the download.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$WNArgs)

& {
    param([string[]]$PassArgs)
    $ErrorActionPreference = 'Stop'
    function Test-WNReleaseSignature {
        param([string]$File, [string]$SigFile, [string]$Key)
        $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider
        try {
            $rsa.PersistKeyInCsp = $false
            $rsa.FromXmlString($Key)
            $signature = [Convert]::FromBase64String((Get-Content -LiteralPath $SigFile -Raw -ErrorAction Stop).Trim())
            return $rsa.VerifyData([IO.File]::ReadAllBytes($File), 'SHA256', $signature)
        } catch {
            return $false
        } finally {
            $rsa.Dispose()
        }
    }

    $releaseKey = '<RSAKeyValue><Modulus>udlHLkTDN4uSXsc8Cl9WnIZKlUC1FnCqrrzKLn/2NU3islEa16Ap7SmL4KQiOoMIRYOQ6cqUpFzLtjtJTLzzEjQv0/6uomyH/Cb94KBUOkb5Q4yB8L5Un3Y0bjY32yaV+RTyGNwCpkXbdRaW/HKw+h7q8ur5lQEap/wYxBp0H59ncGdTgx4SWcMo73BQY2p+ngk0PSFv/Z0ZidcCyhFox1896oXdR8/SvFKItvfErAMpWf/tBp3XDpbiFfW60p0NDCUWgJkDXlnDgy9y7MgrQAk0W8tT5zxgLES/MirW3EwUz4+hNaPOzb0DCtrzEke+YOlnUZYY7VZsqGydD/gexVWw+fA6bE1upX/pZeNqrsNN9+vOZ4OQ5ak3AuifLTCvktOB+o6wZtup5AbWJiEQEhtZdO/77mEPosUB2XDoJcMtaVX0x0xL8mN+cj0yYwSyj+EusEADDVoPVFF3SeLnsSjG70byyxBR+sFtvITaQ5KTTBOJYXftmEiyp8bz4Bj1</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>'
    $repo = 'eperez98/WinNow'
    $url  = "https://github.com/$repo/releases/latest/download/Winnow.zip"
    $dir = Join-Path $env:TEMP ("Winnow-app-" + [guid]::NewGuid().ToString('N'))
    $zip = "$dir.zip"
    $sig = "$zip.sig"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Write-Host ''
    Write-Host '  WinNow - downloading latest release / descargando la ultima version...' -ForegroundColor Cyan
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 120
        Invoke-WebRequest -Uri "$url.sig" -OutFile $sig -UseBasicParsing -TimeoutSec 30
        if (-not (Test-WNReleaseSignature $zip $sig $releaseKey)) {
            throw 'Invalid WinNow release signature / Firma de WinNow no valida.'
        }
        Expand-Archive -LiteralPath $zip -DestinationPath $dir
        $script = Join-Path $dir 'Winnow.ps1'
        if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { throw 'Winnow.ps1 is missing from the release package.' }
        Get-ChildItem -LiteralPath $dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    } catch {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Host "WinNow launch failed / Error al iniciar: $($_.Exception.Message)" -ForegroundColor Red
        return
    } finally {
        Remove-Item -LiteralPath $zip, $sig -Force -ErrorAction SilentlyContinue
    }

    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $script @PassArgs
} @($WNArgs | Where-Object { $_ })
