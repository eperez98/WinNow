@echo off
setlocal
set "SCRIPT=%~dp0Winnow.ps1"
if not exist "%SCRIPT%" (
    echo Winnow.ps1 not found next to Launch.bat.
    exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
exit /b %errorlevel%
