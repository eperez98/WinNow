![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.1 — Release Build

### Run it

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

Simulation mode first (nothing is changed, no admin needed):

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -DryRun
```

Offline: download **Winnow.zip** below, extract it, and run `Launch.bat` as administrator.

### New in 1.0.1

**English / Español.** The first screen asks for the language before showing any option. Menus, prompts, messages and every tweak, service and preset are translated. The last choice is highlighted next time, `-Lang es` skips the screen, and the main menu can switch language at any time.

![Language selector](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/00-language.png)
![Menú principal](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/13-main-menu-es.png)

**Uninstall programs.** A new main-menu entry lists every installed desktop program (the same entries as Settings > Apps) and every Microsoft Store app, not only the catalog apps. MSI programs and programs with a quiet uninstaller are removed silently; the rest open their own uninstaller, marked as *wizard* in the list. A restore point and a backup are taken first, as for every change.

![Uninstall programs](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/12-uninstall.png)

**Release Build** label in the header, window title and release name.

### Fixed

- Check lists with a single item returned no selection on Windows PowerShell 5.1.

### Coming next

- **A more visual UI**: a graphical interface on top of the same engine, alongside the terminal edition.
- Shorter launch URL.

### Notes

- Requires Windows 10 (19041+) or 11 and PowerShell 5.1 or 7. Administrator rights are needed for real changes.
- Full history in the [CHANGELOG](https://github.com/eperez98/Winnow/blob/main/CHANGELOG.md).
