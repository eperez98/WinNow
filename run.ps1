<#
    Winnow one-line launcher.

        irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex

    With options (e.g. simulation mode):

        & ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -DryRun

    Downloads the latest release zip to %TEMP%\Winnow-app, then starts Winnow.ps1
    (elevated when needed). Nothing is installed.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$WNArgs)

& {
    param([string[]]$PassArgs)
    $ErrorActionPreference = 'Stop'
    $repo = 'eperez98/Winnow'
    $url  = "https://github.com/$repo/releases/latest/download/Winnow.zip"
    $dir  = Join-Path $env:TEMP 'Winnow-app'
    $zip  = Join-Path $env:TEMP 'Winnow-latest.zip'

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
    Write-Host ''
    Write-Host '  Winnow - downloading latest release / descargando la ultima version...' -ForegroundColor Cyan
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    } catch {
        Write-Host "  Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    # Files from the internet carry Mark-of-the-Web; unblock so dot-sourcing works under RemoteSigned
    Get-ChildItem $dir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

    $script = Join-Path $dir 'Winnow.ps1'
    if (-not (Test-Path $script)) { Write-Host '  Winnow.ps1 not found in the release package.' -ForegroundColor Red; return }

    $isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $noAdminNeeded = @($PassArgs | Where-Object { $_ -in '-DryRun', '-List', '-Status' }).Count -gt 0
    if ($isAdmin -or $noAdminNeeded) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script @PassArgs
    } else {
        Write-Host '  Requesting administrator rights (a new window will open)...' -ForegroundColor Yellow
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script`"") + @($PassArgs)
        Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    }
} @($WNArgs | Where-Object { $_ })
