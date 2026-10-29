![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.7.2 — GUI Release Candidate

| Edition | Version | Status |
|---|---|---|
| Terminal | **1.0.7.1** | Stable Release (unchanged) |
| Graphical interface | **1.0.7.2** | Release Candidate |

### Run it

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

Graphical interface:

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -GUI
```

Offline: download **Winnow.zip** below, extract it, and run `Launch.bat` as administrator, or double-click `Launch-GUI.bat` for the window.

### New in the graphical interface

**Translucent, flat design** in the Windows 11 / iOS style: the acrylic backdrop of Windows behind the window (Windows 11 22H2 or later), frosted cards, rounded corners, a blue accent and app-icon style tiles.

**Light and dark mode.** A sun / moon button switches at any time; Winnow starts in your Windows setting and remembers what you pick.

![Home, dark](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/15-gui-home.png)
![Inicio, modo claro](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/18-gui-home-es.png)

**EN | ES switch** in the top bar instead of the globe button.

**Update status.** The button reads "Check for this tool updates"; after checking it says "No updates available" or "Update available", which opens the changelog with update / keep / skip.

![Tweaks](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/16-gui-tweaks.png)
![Tweaks avanzados, modo claro](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/23-gui-tweaks-advanced-es.png)

### Fixed

- The window opened minimized when started from a minimized console (`Launch-GUI.bat`, after an update or a language switch).

### Notes

- The terminal edition is unchanged and stays **1.0.7.1 Stable Release**; it is still the most tested one.
- Requires Windows 10 (19041+) or 11 and PowerShell 5.1 or 7. The translucent backdrop needs Windows 11 22H2 or later.
- Full history in the [CHANGELOG](https://github.com/eperez98/Winnow/blob/main/CHANGELOG.md).
