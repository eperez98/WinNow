![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.5 — Release Build

### Run it

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

Graphical interface (preview):

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -GUI
```

Simulation mode first (nothing is changed, no admin needed):

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -DryRun
```

Offline: download **Winnow.zip** below, extract it, and run `Launch.bat` as administrator, or double-click `Launch-GUI.bat` for the window.

### New in 1.0.5

**Graphical interface (preview).** This is the first version of the graphical edition: a window in the Windows 11 style that follows the light or dark theme set in Windows. It runs on the same engine as the terminal, so every change still gets a restore point, a backup, real undo and simulation mode.

- **Home**: Windows version, processor, memory, system drive and uptime, plus quick actions.
- **Tweaks**: grouped by category with the current state of each tweak on this PC. Filter by name, pick a preset (Minimal, Standard, Heavy), then apply or undo.
- **Apps**: type to filter the 376-app catalog, or press Enter to search all of winget, then install.
- **Coming next**: what the graphical edition adds next.
- Live log, simulation switch, English / Spanish switch, and a button that opens the terminal edition.

Open it with `-GUI`, `Launch-GUI.bat`, or `G` in the terminal main menu.

![Home](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/15-gui-home.png)
![Tweaks](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/16-gui-tweaks.png)
![Apps en español](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/17-gui-apps-es.png)
![Light theme](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/18-gui-home-light.png)

**Search winget by name.** The terminal App Manager has a new entry (`W`): type a name and install any winget package, not only the catalog apps.

### Fixed

- **Uninstall programs**: uninstallers that open a wizard returned exit code 1 and the program stayed installed. Uninstall commands with unquoted paths containing spaces are now split correctly, and the uninstaller window is shown so its wizard can be finished. Winnow then checks the registry and tells you if the program is still installed, for example when its wizard was cancelled.

### Coming next

- Every terminal module in the window: services, startup apps, uninstall, repair, Windows Update, DNS, hosts and backups.
- Per-step progress, Mica background and the Windows accent color.
- Shorter launch URL.

### Notes

- Requires Windows 10 (19041+) or 11 and PowerShell 5.1 or 7. Administrator rights are needed for real changes. The graphical interface uses WPF, which is part of Windows.
- Full history in the [CHANGELOG](https://github.com/eperez98/Winnow/blob/main/CHANGELOG.md).
