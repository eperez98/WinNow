![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.7.1 — HotFix & Preview Update

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

> [!NOTE]
> Both editions now have the same modules. The **terminal edition is still the reference and the most tested one**; the graphical interface is a **preview** on the same engine.

### New in 1.0.7.1

**Every module in the graphical interface.** Tweaks, Preferences, Services, Startup apps, App Manager, Uninstall programs, Repair & maintenance, Windows Update, Backups & restore, DNS, Hosts file, System information and Logs. The sidebar groups them like the terminal main menu: Optimize, Apps, Maintain, Network and System.

**New design.** A dark window with an orange accent, a sidebar with every tool, a search bar on top that filters the current page (Enter on the App Manager searches all of winget), and a home page with a large banner, a **Start here** card that opens the recommended tweaks, and a poster card for every tool.

![Home](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/15-gui-home.png)

**Recommended and Advanced tweaks.** Every tweak now has a level. **Recommended** (18) are gentle changes that are safe for any PC: nothing is removed, services and network are untouched, and everything can be undone. **Advanced** (33) need care: they remove apps or change services, network, power plans and the interface. The terminal Tweaks menu shows both levels first; the GUI has Recommended / Advanced / All tabs with an explanation, and asks again when advanced tweaks are selected. The **Standard** preset is now exactly the recommended set.

![Recommended tweaks](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/16-gui-tweaks.png)
![Tweaks avanzados](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/23-gui-tweaks-advanced-es.png)
![Services](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/21-gui-services.png)
![Windows Update en español](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/20-gui-updates-es.png)

**Updates and desktop shortcut.** Every start checks GitHub for a newer release. When there is one, Winnow shows the version and what changed, and you choose: update now, keep using the current version, or skip that version. On the first start Winnow also offers a desktop shortcut with its logo that opens the local copy directly, with no download. Both are in the main menu too (`U`, `K`) and in the GUI top bar.

**Terminal main menu reorganized** into the same groups: Optimize (1-4), Apps (5-6), Maintain (7-9), Network (`D` DNS, `H` hosts), System (`Y` information, `L` logs) and Winnow (`G` graphical interface, `U` updates, `K` shortcut, `I` language, `M` simulation).

![Main menu](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/01-main-menu.png)

### Fixed

- Installing or uninstalling apps ended with "Collection was of a fixed size". The list of installed apps is now read again from winget after every install or uninstall, so the INSTALLED tags are up to date.

### Coming next

- The graphical interface leaves preview after more testing, with per-step progress bars.
- Shorter launch URL.

### Notes

- Requires Windows 10 (19041+) or 11 and PowerShell 5.1 or 7. Administrator rights are needed for real changes. The graphical interface uses WPF, which is part of Windows.
- Full history in the [CHANGELOG](https://github.com/eperez98/Winnow/blob/main/CHANGELOG.md).
