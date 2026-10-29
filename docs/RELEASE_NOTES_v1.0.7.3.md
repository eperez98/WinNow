![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.7.3 — HotFix Update Fixer

Terminal and graphical interface: **1.0.7.3 HotFix Update Fixer**.

### Run it

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

Graphical interface:

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -GUI
```

Offline: download **Winnow.zip** below, extract it, and run `Launch.bat` as administrator, or double-click `Launch-GUI.bat` for the window.

### Changed

- **Update all apps** (winget) starts right away: it no longer creates a System Restore point first, in the terminal and in the graphical interface. The JSON backup with the list of installed apps is still saved. Tweaks, services, DNS and every other change still create the restore point.

### Notes

- Copies of 1.0.7.1 and 1.0.7.2 see this version in their update check.
- Full history in the [CHANGELOG](https://github.com/eperez98/Winnow/blob/main/CHANGELOG.md).
