@echo off
:: Winnow launcher - by Eperez98
:: Double-click to start Winnow in the terminal as Administrator.
:: Add  -DryRun  after the .ps1 path below to start in simulation mode.
title Winnow

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo  Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

set "SCRIPT=%~dp0Winnow.ps1"
if not exist "%SCRIPT%" (
    echo  [ERROR] Winnow.ps1 not found next to Launch.bat
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
if %errorLevel% neq 0 pause
