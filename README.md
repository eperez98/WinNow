<p align="center">
  <img src="LOGO/Winnow_logo.png" width="560" alt="Winnow - sift Windows down to what matters"/>
</p>

<p align="center"><b>Debloat, harden and maintain Windows 10/11 from the terminal, or from the graphical interface (preview).</b></p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.7.1%20HotFix%20%26%20Preview%20Update-10B981?style=flat-square"/>
  <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?style=flat-square"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207-22D3EE?style=flat-square"/>
  <img src="https://img.shields.io/badge/language-English%20%7C%20Espa%C3%B1ol-6EE7B7?style=flat-square"/>
  <img src="https://img.shields.io/badge/license-GPL--3.0-FBBF24?style=flat-square"/>
</p>

---

**Winnow** separates the grain from the chaff: it strips telemetry, ads and bloat from Windows and keeps
what you use. It is a keyboard-driven terminal app built around a declarative tweak catalog. Every tweak
declares the value it applies **and** the value it restores, so Winnow can tell what is already applied,
apply it, and undo it. A backup is saved before every change. The whole interface is available in
**English and Spanish**. Tweaks come in two levels: **Recommended** (gentle changes that are safe for any PC)
and **Advanced** (changes that need care). Since 1.0.7.1 the **graphical interface** (preview) has every module of
the terminal, grouped the same way. See the [CHANGELOG](CHANGELOG.md).

> [!NOTE]
> Both editions now have the same modules: tweaks, preferences, services, startup apps, apps, uninstall
> programs, repair, Windows Update, backups and restore, DNS, hosts, system information and logs.
> The **terminal edition is still the reference and the most tested one**; the graphical interface is a
> **preview** running on the same engine. The window has a button that opens the terminal edition.

## Quick start

Open **PowerShell** (or Windows Terminal) and run:

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

It downloads the latest release to `%TEMP%\Winnow-app` and starts it (asking for administrator rights).
The first screen asks for the language (English / Español) before showing any option. Nothing is installed. To explore first without changing anything (simulation mode, no admin needed):

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -DryRun
```

To open the **graphical interface** (preview) instead of the terminal menus:

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -GUI
```

**Offline / manual:** download `Winnow.zip` from [Releases](https://github.com/eperez98/Winnow/releases/latest),
extract it, right-click `Launch.bat` -> *Run as administrator* (or double-click `Launch-GUI.bat` for the window).
Or from a terminal in that folder:

```powershell
.\Winnow.ps1            # interactive menu (asks for admin)
.\Winnow.ps1 -DryRun    # simulation: nothing is changed
.\Winnow.ps1 -Lang es   # skip the language screen and start in Spanish
.\Winnow.ps1 -GUI      # graphical interface (preview)
```

### Desktop shortcut and updates

- **Desktop shortcut:** on the first start Winnow offers a desktop shortcut with its logo that opens the local copy
  directly, with no download. A copy started with the one-line command lives in `%TEMP%`, so it is first copied to
  `%LOCALAPPDATA%\Programs\Winnow`. Create it later with `K` in the main menu or the link button in the GUI.
- **Updates:** every start asks GitHub for the latest release (a few seconds at most, silent when offline). When
  there is a newer one, Winnow shows which version it is and its changelog, and lets you choose: **update now**
  (download, replace this copy, restart), **keep using the current version** (asks again next time), or **skip
  this version**. A failed update leaves the current copy as it was. Check by hand with `U` in the main menu or the
  update button in the GUI; `-NoUpdateCheck` turns the startup check off.

## Graphical interface (preview)

A dark WPF window with an orange accent: a sidebar with every tool, a search bar on top, and a home page with
a large banner, a **Start here** card that opens the recommended tweaks, and a poster card for every tool. Open it
with `-GUI`, `Launch-GUI.bat`, or `G` in the terminal main menu.

The search bar works on every page: it filters the current list (tweaks, services, apps, programs, backups...).
On the App Manager, pressing Enter in it searches all of winget.

Every terminal module is in the window, grouped like the terminal main menu:

| Group | Pages |
|---|---|
| **Optimize** | Tweaks (Recommended / Advanced / All tabs, presets, select applied, apply / undo), Preferences (ON / OFF switches), Services, Startup apps |
| **Apps** | App Manager (catalog filter, search all of winget, install, uninstall, upgrade all, installed tags), Uninstall programs (desktop and Store) |
| **Maintain** | Repair & maintenance, Windows Update (status, recommended, defaults, pause, resume), Backups & restore |
| **Network** | DNS (current servers and every provider), Hosts file (telemetry / Adobe blocks, active entries) |
| **System** | System information, Logs |

It uses the same engine as the terminal, so every change still gets a restore point, a backup, real undo and
simulation mode. Long tasks run in the background and stream their output into the log at the bottom.

| | |
|---|---|
| ![GUI home](screenshots/15-gui-home.png) | ![GUI tweaks](screenshots/16-gui-tweaks.png) |
| Home: banner, Start here card and every tool | Recommended tweaks: gentle changes, live state of each one |
| ![GUI advanced tweaks](screenshots/23-gui-tweaks-advanced-es.png) | ![GUI home Spanish](screenshots/18-gui-home-es.png) |
| Advanced tweaks with their caution note (Spanish) | Home in Spanish |
| ![GUI services](screenshots/21-gui-services.png) | ![GUI uninstall](screenshots/22-gui-uninstall.png) |
| Services: current vs recommended | Uninstall programs (silent or wizard) |
| ![GUI repair](screenshots/19-gui-repair.png) | ![GUI updates](screenshots/20-gui-updates-es.png) |
| Repair & maintenance | Windows Update (Spanish) |
| ![GUI apps](screenshots/17-gui-apps-es.png) | |
| App Manager (Spanish) | |

## Screenshots

| | |
|---|---|
| ![Language](screenshots/00-language.png) | ![Main menu](screenshots/01-main-menu.png) |
| Language selector at startup | Main menu, grouped like the GUI sidebar |
| ![Menú principal](screenshots/13-main-menu-es.png) | ![Tweaks en español](screenshots/14-tweaks-es.png) |
| Main menu in Spanish | Tweaks in Spanish |
| ![Tweaks](screenshots/03-tweaks-essential.png) | ![Uninstall](screenshots/12-uninstall.png) |
| Tweaks with live status, multi-select | Uninstall any program or Store app |
| ![Confirm](screenshots/04-confirm.png) | ![Simulation](screenshots/05-apply-simulation.png) |
| Confirmation with risk levels | Simulation mode prints every step |
| ![Preferences](screenshots/06-preferences.png) | ![Apps](screenshots/08-apps-browsers.png) |
| Preferences as ON/OFF switches | App Manager (winget) with installed detection |
| ![Repair](screenshots/09-repair.png) | ![Backups](screenshots/10-backups.png) |
| Repair & maintenance | Backups and restore points |

## Tweak levels

| Level | What it means | Examples |
|---|---|---|
| **Recommended** (18) | Gentle changes, safe for any PC. Nothing is removed, services and network are untouched, everything can be undone | Telemetry off, activity history, Start menu ads, Store search results, End Task on the taskbar, Edge and Brave debloat, temp files and disk cleanup |
| **Advanced** (33) | Changes that need care: they remove apps, change services, network, power plans or the interface. Read each description first | Trim services, remove bloatware / Xbox / OneDrive / Edge, Copilot and Windows AI off, hosts blocks, IPv6 / Teredo, power plans, classic context menu |

In the terminal, **Tweaks** opens with **Recommended** (`R`) and **Advanced - CAUTION** (`A`) first, then the six
categories and the tools (presets, all tweaks, undo applied). In the GUI they are the first tabs of the Tweaks page.
The **Standard** preset is exactly the recommended set; **Heavy** adds a selection of advanced tweaks.

The main menu is grouped like the GUI sidebar: **Optimize** (1-4), **Apps** (5-6), **Maintain** (7-9),
**Network** (`D` DNS, `H` hosts), **System** (`Y` information, `L` logs) and **Winnow** (`G` graphical interface,
`U` check for updates, `K` desktop shortcut, `I` language, `M` simulation mode).

The full logo banner appears on the main menu when the terminal is at least 40 rows tall; smaller windows
show the compact `\/\/. winnow` mark in the header.

### Keys

| Key | Action |
|---|---|
| `Up` / `Down`, `PgUp` / `PgDn` | Move |
| `Enter` | Select / apply |
| `Space` | Tick an item in a list |
| `A` | Tick all / none (visible items) |
| `/` | Search inside a list |
| `U` | Undo the ticked tweaks |
| `1`-`9`, letters | Menu shortcuts |
| `Esc` | Back |

## Features

| Menu | What it does |
|---|---|
| **Tweaks** | 51 tweaks in two levels (18 **Recommended**, 33 **Advanced**) and 6 categories, live status (`APPLIED`, `PARTIAL`, `-`), apply + real undo, presets **Minimal / Standard / Heavy**, "Undo applied tweaks" scan |
| **Preferences** | 18 ON/OFF switches: dark mode, file extensions, hidden files, taskbar, Bing search, mouse acceleration, GPU scheduling, NumLock... |
| **App Manager** | 376-app catalog, install / uninstall via winget (Chocolatey fallback), installed detection, upgrade all, and **search all of winget by name** (`W`) |
| **Uninstall programs** | Every installed desktop program (same list as Settings > Apps) and Microsoft Store app. MSI and programs with a quiet uninstaller are removed silently; the rest open their own uninstaller |
| **Services** | 18 common services: current vs recommended vs Windows default |
| **Startup Manager** | Enable / disable startup apps using Task Manager's own flags (nothing is deleted) |
| **Repair** | SFC, DISM, chkdsk, temp + disk cleanup, DNS flush, network reset, Windows Update reset, Store reset |
| **Windows Update** | Recommended (defer features 120 days / security 7 days, no drivers), defaults, pause 1-35 days, resume |
| **DNS** | Cloudflare (standard, security, family), Google, Quad9, OpenDNS, AdGuard (standard, family) or back to DHCP |
| **Hosts** | Tagged telemetry / Adobe blocks that can be removed exactly, automatic backups |
| **Backups & restore** | Restore the backups taken before each change, delete old backups; create, list, roll back to or delete restore points (oldest or all) |
| **System info / Logs** | Hardware summary, disk usage, log viewer with errors-only filter |
| **Language** | English / Español, chosen at startup (the last choice is highlighted) and switchable from the main menu |
| **Updates** | Checks GitHub at every start; shows the new version and its changelog; update now, keep the current version, or skip that version |
| **Desktop shortcut** | Offered on the first start: Winnow logo on the desktop that opens the local copy directly |
| **Graphical interface** | Preview window with every module above, a page search bar and a home page with every tool (`G` in the main menu, or `-GUI`) |

### Safety

- **Simulation mode** (`-DryRun`, or `M` in the main menu) prints every registry, service, app and command step without running it.
- A **System Restore Point** is created automatically before the first change of each session.
- A **Winnow backup** (JSON with the exact current registry values, service startup types, DNS servers and installed-app list) is saved **before every change**: tweaks, apps, services, startup, DNS, updates, repairs. Restore any of them from **Backups & restore**.
- Undo only touches tweaks that are currently applied, and services are only restored if they are still where Winnow put them.
- High-risk items are flagged in lists and in the confirmation screen.
- Logs: `%ProgramData%\Winnow\logs`, backups: `%ProgramData%\Winnow\backup`.

## Scripted use

```powershell
.\Winnow.ps1 -List                                   # tweak keys and presets
.\Winnow.ps1 -Status                                 # detected state of every tweak
.\Winnow.ps1 -Preset Standard -Yes                   # unattended preset
.\Winnow.ps1 -Apply Telemetry,ClassicContextMenu -DryRun
.\Winnow.ps1 -Undo ClassicContextMenu
.\Winnow.ps1 -Install firefox,7zip,vscode -Yes
.\Winnow.ps1 -Status -Lang es                         # tweak names in Spanish
.\Winnow.ps1 -NoUpdateCheck                           # start without asking GitHub for updates
```

Exit code is `1` if any step failed.

## Project structure

```
Winnow.ps1               Entry point: parameters, elevation, main menu
Launch.bat               Double-click launcher (self-elevates)
Launch-GUI.bat           Double-click launcher for the graphical interface
run.ps1                  One-line launcher used by irm | iex (downloads the latest release)
CHANGELOG.md             Version history
docs/                    Release notes
screenshots/ LOGO/       Images (LOGO/Winnow.ico is the shortcut icon)
core/
  Common.ps1             Context, logging, helpers
  Engine.ps1             Registry / service / appx engine, tweak state, apply/undo batches, backups
  Tui.ps1                Logo banner, arrow-key menus, check lists with search, confirmations
  I18n.ps1               English / Spanish strings, language selector
  Update.ps1             Update check (GitHub releases + changelog), updater, desktop shortcut
modules/
  Tweaks.ps1             Tweaks, presets, preference switches
  TweakActions.ps1       Script parts of tweaks (Invoke / Undo / Check functions)
  Uninstall.ps1          Uninstall programs (desktop + Store apps)
  Apps.ps1 Services.ps1 Startup.ps1 Repair.ps1 Updates.ps1 Network.ps1 System.ps1
gui/
  Gui.ps1                Graphical interface (WPF): every page, background worker, search, theme
  MainWindow.xaml        Window shell (sidebar, search bar, page hosts) and styles
tests/                   Self-checks for the parsers (run with powershell -File)
config/
  tweaks.json            Declarative tweak catalog
  presets.json apps.json services.json dns.json
  i18n.json              Interface text in English and Spanish
  catalog.es.json        Spanish names and descriptions for tweaks, services and presets
```

### Adding a tweak

Add an entry to `config/tweaks.json`. Registry and service tweaks need no code:

```json
{
  "Key": "MyTweak", "Name": "My tweak", "Category": "Privacy", "Type": "Tweak", "Risk": "Low", "Level": "Recommended",
  "Description": "What it does.",
  "Registry": [ { "Path": "HKCU:\\Software\\...", "Name": "Value", "Type": "DWord", "Value": "0", "Original": "<unset>" } ],
  "Services": [ { "Name": "SomeSvc", "Startup": "Disabled", "Original": "Manual" } ]
}
```

`"<unset>"` means the value does not exist (undo deletes it). `Level` is `Recommended` (gentle, safe for any PC) or
`Advanced` (needs care); toggles have no level. `Type` is `Tweak` (undoable), `Toggle` (shown as
ON/OFF) or `Action` (one-shot). Optional: `Appx`, `Invoke`, `Undo`, `Check` (function names in
`TweakActions.ps1`), `Restart` (`Explorer` / `Reboot`), `Group` (mutually exclusive tweaks), `MinBuild`, and
`IfMissing` on a registry entry (state to assume when the value does not exist).

## Roadmap

- **Graphical interface:** leave preview after more testing, per-step progress bars, and a manual light / dark switch.
- Short launch URL (custom domain) for the one-liner.

## Requirements

- Windows 10 (19041+) or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7
- Administrator rights for real changes (not for `-DryRun`, `-List`, `-Status`)
- The graphical interface uses WPF, included in Windows (.NET Framework 4.x)
- winget for the App Manager (Chocolatey is offered as fallback)
- Internet access to github.com for the update check (optional: Winnow works offline)

## License

GPL-3.0 © ErickP (Eperez98) — [github.com/eperez98](https://github.com/eperez98)
