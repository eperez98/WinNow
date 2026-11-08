<p align="center">
  <img src="LOGO/Winnow_logo.png" width="560" alt="Winnow - sift Windows down to what matters"/>
</p>

<p align="center"><b>Debloat, harden and maintain Windows 10/11 from the terminal or from the graphical interface.</b></p>
<p align="center"><sub>Proudly made in Panama PTY507</sub></p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.2.2%20Secure%20Update%20%C2%B7%20Security%20Compliance%20Hotfix-10B981?style=flat-square"/>
  <img src="https://img.shields.io/badge/platform-Windows%2010%2F11-0078D4?style=flat-square"/>
  <img src="https://img.shields.io/badge/PowerShell-5.1%20%7C%207-22D3EE?style=flat-square"/>
  <img src="https://img.shields.io/badge/language-English%20%7C%20Espa%C3%B1ol-6EE7B7?style=flat-square"/>
  <img src="https://img.shields.io/badge/license-GPL--3.0-FBBF24?style=flat-square"/>
</p>

<p align="center">
  <a href="#whats-new-in-122">What's new</a> &nbsp;&middot;&nbsp;
  <a href="#quick-start">Quick start</a> &nbsp;&middot;&nbsp;
  <a href="#graphical-interface">Graphical interface</a> &nbsp;&middot;&nbsp;
  <a href="#screenshots">Screenshots</a> &nbsp;&middot;&nbsp;
  <a href="#features">Features</a> &nbsp;&middot;&nbsp;
  <a href="#security-model">Security</a> &nbsp;&middot;&nbsp;
  <a href="#release-history">Release history</a> &nbsp;&middot;&nbsp;
  <a href="#roadmap">Roadmap</a> &nbsp;&middot;&nbsp;
  <a href="CHANGELOG.md">Changelog</a>
</p>

<p align="center"><code>irm eperez98.github.io/WinNow | iex</code></p>

---

**Winnow** separates the grain from the chaff: it strips telemetry, ads and bloat from Windows and keeps
what you use. It is a keyboard-driven terminal app built around a declarative tweak catalog. Every tweak
declares the value it applies **and** the value it restores, so Winnow can tell what is already applied,
apply it, and undo it. A backup is saved before every change. The whole interface is available in
**English and Spanish**. Tweaks come in two levels: **Recommended** (gentle changes that are safe for any PC)
and **Advanced** (changes that need care). The **graphical interface** has every module of the terminal, grouped the
same way. See the [CHANGELOG](CHANGELOG.md).

| Edition | Version | Status |
|---|---|---|
| Terminal | **1.2.2** | Secure Update · Security Compliance Hotfix |
| Graphical interface | **1.2.2** | Secure Update · Security Compliance Hotfix (full GUI release since **1.1**) |

> [!NOTE]
> Both editions now have the same modules: tweaks, preferences, services, startup apps, apps, uninstall
> programs, repair, Windows Update, backups and restore, DNS, hosts, system information and logs.
> The **terminal edition is the reference and the most tested one**; the graphical interface runs on the same
> engine. Both are at 1.2.2. The window has a button that opens the terminal.

## What's new in 1.2.2

1.2.2 **Secure Update · Security Compliance Hotfix** closes two ways another account or a damaged download could
change what Winnow runs as administrator, and makes updating a step you control. It also includes everything from
1.2 Exit & Launcher Update, which was not published on its own.

- **Admin-only data folder.** `C:\ProgramData\Winnow` (logs and backups) now belongs to Administrators: full
  control for SYSTEM and Administrators, read-only for Users. Before, a standard account could drop a backup file
  there, and restoring it as administrator would write its registry values. A folder someone else created first is
  taken back, links planted in place of its subfolders are removed, and a backup is only used when an
  administrator, SYSTEM or you wrote it.
- **Updates checked before they are installed.** The SHA256 of every unpacked file is recorded when the update is
  downloaded and compared again at **Restart now**. If one file changed, the update stops and this copy stays as it is.
- **No half-installed updates.** Every file and folder the update replaces is set aside first and put back if
  anything fails, so a failed update can no longer leave a new `Winnow.ps1` with old modules.
- **Update panel.** The update button opens a panel over the window: checking, **Update available** with the
  changelog (Update / Not now / Skip this version), downloading, and **Restart required** with **Restart now** or
  **Later**. Nothing is replaced until you choose Restart now.
- **From 1.2:** one launcher (`Launch.bat` asks for terminal or window; `Launch-GUI.bat` is gone), the desktop
  shortcut question on exit, and restarts that always keep your language, simulation and update settings.

## Quick start

Open **PowerShell** (or Windows Terminal) and run:

```powershell
irm eperez98.github.io/WinNow | iex
```

It downloads the latest release to `%TEMP%\Winnow-app` and starts it (asking for administrator rights).
The first screen asks for the language (English / Español), the second one whether to use the **Terminal** or the
**Graphical interface (GUI)**. Nothing is installed. To explore first without changing anything, turn on
simulation mode with `M` in the main menu (or the simulation switch in the window).

**Offline / manual:** download `Winnow.zip` from [Releases](https://github.com/eperez98/Winnow/releases/latest),
extract it and right-click `Launch.bat` -> *Run as administrator*. It is the only launcher: it asks for the mode
(terminal or graphical interface).
Or from a terminal in that folder:

```powershell
.\Winnow.ps1            # interactive menu (asks for admin)
.\Winnow.ps1 -DryRun    # simulation: nothing is changed
.\Winnow.ps1 -Lang es   # skip the language screen and start in Spanish
.\Winnow.ps1 -GUI      # graphical interface, without the Terminal / GUI screen
.\Winnow.ps1 -Terminal # terminal menus, without the Terminal / GUI screen
```

### Desktop shortcut and updates

- **Desktop shortcut:** when you close Winnow and there is no shortcut yet (always, for a copy started with the
  one-line command), it asks: **Yes** creates a desktop shortcut with its logo that opens Winnow directly with no
  download (a downloaded copy is first copied to `%LOCALAPPDATA%\Programs\Winnow`) and keeps the files; **No**
  deletes Winnow's files from this PC like an uninstall (the download, that copy and the shortcut). A folder you
  extracted yourself is never deleted. Logs and backups are always kept. Create a shortcut any time with `K` in
  the main menu or the link button in the GUI.
- **Updates:** every start asks GitHub for the latest release (a few seconds at most, silent when offline). When
  there is a newer one, Winnow shows which version it is and its changelog, and lets you choose: **update now**
  (download, replace this copy, restart), **keep using the current version** (asks again next time), or **skip
  this version**. A failed update leaves the current copy as it was. Check by hand with `U` in the main menu or the
  **Check for this tool updates** button in the GUI, which opens the update panel: checking, **Update available**
  with the changelog, downloading, and **Restart required** with **Restart now** or **Later** (keep using this
  version). The download is checked file by file before it is installed; `-NoUpdateCheck` turns the startup check off.

## Graphical interface

A modern, translucent and flat window in the Windows 11 / iOS style: on Windows 11 22H2 or later the background is
the blurred acrylic backdrop of Windows (a solid colour on older builds), with frosted cards, rounded corners and a
blue accent. It has three themes in the theme button: **Light**, **Dark** and **Mes patrio** (November is Panama's patriotic
month: the Panama icon, the flag on the home banner and an aero background in Panama navy and red). It starts in
mes patrio in November, otherwise in the Windows setting, and remembers your choice, and an **EN | ES** switch for the language. A sidebar lists every tool, a search
bar sits on top, and the home page has a banner, a **Start here** card that opens the recommended tweaks, and a tile
for every tool. Open it from the mode choice at start, with `-GUI`, or `G` in the terminal main menu.

The search bar works on every page: it filters the current list (tweaks, services, apps, programs, backups...).
A click selects its text, so typing replaces it. On the App Manager, typing a name (for example Steam) searches
all of winget after a short pause; Enter or **Search winget** search at once. The search runs on its own, so it
never waits behind other tasks, and it tells you when winget does not answer within 60 seconds.

Every terminal module is in the window, grouped like the terminal main menu:

| Group | Pages |
|---|---|
| **Optimize** | Tweaks (Recommended / Advanced / All tabs, presets, select applied, apply / undo), Preferences (ON / OFF switches), Services, Startup apps |
| **Apps** | App Manager (catalog filter, search all of winget, install, uninstall, upgrade all, installed tags), Uninstall programs (desktop and Store) |
| **Maintain** | Repair & maintenance, Windows Update (status, recommended, defaults, pause, resume), Backups & restore |
| **Network** | DNS (current servers and every provider), Hosts file (telemetry / Adobe blocks, active entries) |
| **System** | System information, Logs |
| **Winnow** | About Winnow (what it is, its core, every release, and 1.5 on the way) |

It uses the same engine as the terminal, so every change still gets a restore point, a backup, real undo and
simulation mode. Long tasks run in the background and stream their output into the log at the bottom.

| | |
|---|---|
| ![Home, mes patrio](screenshots/29-gui-home-patria-es.png) | ![About, mes patrio](screenshots/30-gui-about-patria.png) |
| Home in the mes patrio theme (Spanish) | About, mes patrio |
| ![GUI home](screenshots/15-gui-home.png) | ![GUI home light](screenshots/18-gui-home-es.png) |
| Home, dark | Home, light (Spanish) |
| ![GUI tweaks](screenshots/16-gui-tweaks.png) | ![GUI advanced tweaks](screenshots/23-gui-tweaks-advanced-es.png) |
| Recommended tweaks, dark | Advanced tweaks with their caution note, light (Spanish) |
| ![GUI services](screenshots/21-gui-services.png) | ![GUI repair](screenshots/19-gui-repair.png) |
| Services, light | Repair & maintenance, light |
| ![GUI updates](screenshots/20-gui-updates-es.png) | ![Theme picker](screenshots/31-gui-theme-picker-es.png) |
| Windows Update, dark (Spanish) | Theme picker, mes patrio (Spanish) |

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
`A` about Winnow, `U` check for updates, `K` desktop shortcut, `I` language, `M` simulation mode).

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
| **Desktop shortcut** | Asked on exit: Winnow logo on the desktop that opens the local copy directly, or remove the download |
| **Graphical interface** | Translucent light / dark window with every module above, EN / ES switch, page search bar, update status (`G` in the main menu, or `-GUI`) |

### Safety

- **Simulation mode** (`-DryRun`, or `M` in the main menu) prints every registry, service, app and command step without running it.
- A **System Restore Point** is offered before the first change of each session (you can skip it for that task; the JSON backup is always taken).
- A **Winnow backup** (JSON with the exact current registry values, service startup types, DNS servers and installed-app list) is saved **before every change**: tweaks, apps, services, startup, DNS, updates, repairs. Restore any of them from **Backups & restore**.
- Undo only touches tweaks that are currently applied, and services are only restored if they are still where Winnow put them.
- High-risk items are flagged in lists and in the confirmation screen.
- Logs: `%ProgramData%\Winnow\logs`, backups: `%ProgramData%\Winnow\backup`. The folder is admin-only (read-only for other users), and backups are only used when an administrator, SYSTEM or you wrote them.

### Security model

Winnow runs as administrator, so it treats everything it reads back as untrusted until it knows who wrote it.

| Area | What Winnow does |
|---|---|
| **Data folder** | `%ProgramData%\Winnow` is owned by Administrators; SYSTEM and Administrators have full control, Users can only read. The permissions are checked at every start and fixed when they are not right, and a folder created first by another account is taken back. |
| **Backups** | A backup is restored only when its owner is an administrator, SYSTEM or the current user. Links (junctions, symlinks) planted in place of `logs` or `backup` are removed. Backups imported from the old WinTooler folder go through the same check. |
| **Updates** | Only from the GitHub releases of this repository, over HTTPS. The zip is unpacked to a staging folder, every file gets a SHA256, and the hashes are compared again right before the swap. |
| **Install** | The swap is all or nothing: the old files are renamed aside first and restored if one step fails. |
| **Changes** | Simulation mode, a JSON backup before every change, an optional System Restore point, and undo that only touches what Winnow applied. |
| **Removal** | Answering **No** on exit deletes only Winnow's own copies (the `%TEMP%` download, `%LOCALAPPDATA%\Programs\Winnow`, the shortcut), never a folder you extracted yourself. Logs and backups stay. |

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
  Gui.ps1                Graphical interface (WPF): every page, background worker, search, light / dark theme
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

## Release history

| Version | Name | Highlights |
|---|---|---|
| **1.2.2** | Secure Update · Security Compliance Hotfix | Admin-only data folder, backups trusted only from admins/SYSTEM/you, SHA256-checked updates, all-or-nothing install, update panel with Restart now / Later |
| 1.2 | Exit & Launcher Update | Desktop shortcut or clean removal on exit, one launcher, settings kept on restart (shipped inside 1.2.2) |
| 1.1.5 | Restore Point Choice | System Restore point is optional; the JSON backup is always taken |
| 1.1 | Full GUI Release | The window leaves preview: same tools as the terminal, step-by-step progress bar, list of available upgrades, Light / Dark / Mes patrio themes, PayPal support link |
| 1.0.9 | Selection Fix | Multi-select in the window works again; `[i/N]` in uninstalls |
| 1.0.8 | Update Fixer | Updating from the window works again; Terminal or GUI at every start; `irm eperez98.github.io/WinNow \| iex`; About Winnow |
| 1.0.7.3 | HotFix Update Fixer | Upgrade all apps without a restore point or a question |
| 1.0.7.2 | GUI Release Candidate | Translucent window, light / dark switch, EN \| ES switch, update status button |
| 1.0.7.1 | HotFix & Preview Update | Every module in the window, Recommended / Advanced tweak levels, update check at start, desktop shortcut |
| 1.0.5 | Release Build | First graphical interface (preview), search all of winget, uninstall wizard fix |
| 1.0.1 | Release Build | Language selector, full Spanish translation, Uninstall programs |
| 1.0.0 | First release | Terminal UI, 51 tweaks with real undo, presets, backups, restore points, App Manager, services, DNS, hosts |

Details for each one are in the [CHANGELOG](CHANGELOG.md) and on the [Releases](https://github.com/eperez98/WinNow/releases) page.

## Roadmap

- **1.5 November Update**: the new name WinNow, a logo for light and dark mode, startup apps listed active first.
- Later builds on the road to **2.0 Store Edition**: a reworked window, profiles and scheduled maintenance, signed
  releases. More changes may be added and others removed.

## Requirements

- Windows 10 (19041+) or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7
- Administrator rights for real changes (not for `-DryRun`, `-List`, `-Status`)
- The graphical interface uses WPF, included in Windows (.NET Framework 4.x)
- winget for the App Manager (Chocolatey is offered as fallback)
- Internet access to github.com for the update check (optional: Winnow works offline)

## License

GPL-3.0 © ErickP (Eperez98) — [github.com/eperez98](https://github.com/eperez98)

---

<p align="center"><sub>Winnow by ErickP (Eperez98) &middot; Proudly made in Panama PTY507</sub></p>
