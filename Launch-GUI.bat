@echo off
:: Winnow graphical interface (preview) - by Eperez98
:: Double-click to open the window. Winnow.ps1 asks for administrator rights itself.
:: Add  -DryRun  at the end of the line below to start in simulation mode.
start "" /min powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0Winnow.ps1" -GUI %*
