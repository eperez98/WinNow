<div align="center">

**English** · [Español](README.es.md)

<img src="docs/readme-hero-en.png" alt="WinNow: debloat and maintain Windows 10 and 11" width="100%" />

<br />

[![Run WinNow](https://img.shields.io/badge/Run%20WinNow-1.7.4%20Glassware%20Polish-0F766E?style=for-the-badge&logo=windows&logoColor=white)](#run-it)

![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-123A5C)
![PowerShell 5.1 | 7](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-123A5C)
![Nothing to install](https://img.shields.io/badge/nothing-to%20install-123A5C)
![English | Español](https://img.shields.io/badge/English%20%7C%20Espa%C3%B1ol-123A5C)
![GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-123A5C)

**Telemetry, ads and bloat out; what you use stays. From the terminal or from a window.**<br />
Every change is backed up first and can be undone.

```powershell
irm eperez98.github.io/WinNow | iex
```

[Features](#features) · [Screenshots](#screenshots) · [Run it](#run-it) · [Security](#security) · [Roadmap](#roadmap) · [Changelog](CHANGELOG.md)

</div>

---

## Why WinNow

<table>
<tr>
<td width="33%" valign="top">

### ↩️ Everything can be undone
Every tweak declares the value it sets **and** the value it restores. A JSON backup is saved before every change, a System Restore point is offered, and **simulation mode** shows each step without running it.

</td>
<td width="33%" valign="top">

### 🧭 Gentle by default
**18 Recommended** tweaks that are safe for any PC (nothing removed, services and network untouched) and **33 Advanced** ones that ask for care. Presets Minimal, Standard and Heavy.

</td>
<td width="33%" valign="top">

### 🔒 Nothing installed
One line in PowerShell runs it from GitHub. Logs and backups live in an admin-only folder, and updates are checked file by file before they are installed.

</td>
</tr>
</table>

## Screenshots

**1.7.4 Glassware Polish** adapts the adjustment workspace to narrow windows and keeps hidden selections visible in the summary. Remove any selected item directly from that panel. Launch.bat forwards PowerShell arguments including -DryRun.

The app opens on **Adjustments**. The docked sidebar can collapse. The table shows category and risk, and the right panel lists selected changes and offers **Simulate changes**. **Review changes** shows details and can offer a restore point.

![Glassware adjustments](screenshots/es/glassware-ajustes.png)

[Review dialog](screenshots/es/glassware-revision.png)


<div align="center">
<img src="screenshots/en/home.png" alt="WinNow home" width="100%" />
<sub><b>Home</b> — glass cards over soft colour, a hero with start cards, and the compact menu on the left.</sub>
</div>

<br />

| | |
|:---:|:---:|
| <img src="screenshots/en/news.png" alt="What's new" /><br /><sub><b>What's new</b> — slides with pictures, shown once after an update</sub> | <img src="screenshots/en/welcome.png" alt="Welcome" /><br /><sub><b>First start</b> — window or terminal, Light or Dark</sub> |
| <img src="screenshots/en/profiles.png" alt="Profiles & schedules" /><br /><sub><b>Profiles & schedules</b> — save a PC, apply it elsewhere, scheduled maintenance</sub> | <img src="screenshots/en/group-optimize.png" alt="Optimize group" /><br /><sub><b>Groups</b> — each menu item opens its tools as cards</sub> |
| <img src="screenshots/en/tweaks.png" alt="Tweaks" /><br /><sub><b>Tweaks</b> — live status, apply and real undo, presets</sub> | <img src="screenshots/en/tweaks-advanced.png" alt="Advanced tweaks" /><br /><sub><b>Advanced tweaks</b> — with a caution note before you apply them</sub> |
| <img src="screenshots/en/preferences.png" alt="Preferences" /><br /><sub><b>Preferences</b> — 18 ON / OFF switches</sub> | <img src="screenshots/en/services.png" alt="Services" /><br /><sub><b>Services</b> — current vs. recommended vs. Windows default</sub> |
| <img src="screenshots/en/repair.png" alt="Repair" /><br /><sub><b>Repair & maintenance</b> — SFC, DISM, cleanup, resets</sub> | <img src="screenshots/en/updates.png" alt="Windows Update" /><br /><sub><b>Windows Update</b> — recommended policy, defaults, pause, resume</sub> |
| <img src="screenshots/en/about.png" alt="About" /><br /><sub><b>About WinNow</b> — the core, every release and what comes next</sub> | |

<details>
<summary><b>⌨️ Terminal edition</b></summary>
<br />

| | |
|:---:|:---:|
| <img src="screenshots/terminal/mode-en.png" alt="Mode choice" /><br /><sub>Every start: terminal or window</sub> | <img src="screenshots/terminal/main-menu-en.png" alt="Main menu" /><br /><sub>Main menu, grouped like the window's sidebar</sub> |
| <img src="screenshots/terminal/tweaks-en.png" alt="Tweaks in the terminal" /><br /><sub>Tweaks with live status and multi-select</sub> | <img src="screenshots/terminal/preferences-en.png" alt="Preferences in the terminal" /><br /><sub>Preferences as ON / OFF switches</sub> |
| <img src="screenshots/terminal/repair-en.png" alt="Repair in the terminal" /><br /><sub>Repair & maintenance</sub> | <img src="screenshots/terminal/exit-en.png" alt="Exit question" /><br /><sub>On exit: desktop shortcut, or remove WinNow's files</sub> |

</details>

<sub>Screenshots are taken in simulation mode. Pages that would show your own programs, hosts file or hardware are left out.</sub>

## Features

<details open>
<summary><b>Optimize</b></summary>

- **Tweaks**: 51 tweaks in 6 categories with live status (`APPLIED`, `PARTIAL`, `-`), apply and real undo, presets **Minimal / Standard / Heavy**, and an "Undo applied tweaks" scan.
- **Levels**: **Recommended** (18) — telemetry off, activity history, Start menu ads, Store search results, End Task on the taskbar, Edge and Brave debloat, temp files and disk cleanup. **Advanced** (33) — trim services, remove bloatware / Xbox / OneDrive / Edge, Copilot and Windows AI off, hosts blocks, IPv6 / Teredo, power plans, classic context menu.
- **Preferences**: 18 ON / OFF switches — dark mode, file extensions, hidden files, taskbar, Bing search, mouse acceleration, GPU scheduling, NumLock…
- **Services**: 18 common services, current vs. recommended vs. Windows default.
- **Startup Manager**: enable or disable startup apps with Task Manager's own flags (nothing is deleted); active ones first.
</details>

<details>
<summary><b>Apps</b></summary>

- **App Manager**: a 376-app catalog plus **every winget package** — type a name such as Steam and WinNow searches all of winget. Install, uninstall, installed tags, **upgrade all** and **list available upgrades** first. Chocolatey as a fallback.
- **Uninstall programs**: every desktop program (the same list as Settings > Apps) and Microsoft Store app. MSI and quiet uninstallers run silently; the rest open their own wizard, and WinNow checks the result.
</details>

<details>
<summary><b>Maintain, network and system</b></summary>

- **Repair & maintenance**: SFC, DISM, chkdsk, temp and disk cleanup, DNS flush, network reset, Windows Update reset, Store reset.
- **Windows Update**: recommended policy (features deferred 120 days, security 7 days, no drivers), Windows defaults, pause 1–35 days, resume.
- **Backups & restore**: restore the backup taken before any change; create, list, roll back to or delete restore points.
- **DNS**: Cloudflare (standard, security, family), Google, Quad9, OpenDNS, AdGuard (standard, family) or back to DHCP.
- **Hosts file**: tagged telemetry and Adobe blocks that can be removed exactly.
- **System information and logs**: hardware summary, disk usage, log viewer with an errors-only filter.
</details>

<details>
<summary><b>Window and terminal</b></summary>

- **Starts in the window**: after a short start animation (the Glassware monogram appears on a glass tile with a soft chime) WinNow opens the graphical interface. **Terminal mode** in the menu switches to the console; the last What's new slide sets which one WinNow starts in.
- **First start**: a welcome asks for the language, window or terminal, and Light or Dark, once.
- **What's new**: after an update, a card with slides that move sideways shows what changed, with pictures; the design slide lets you try a theme on the spot.
- **Menu**: the docked sidebar includes Home, Adjustments, Applications and Repair. The menu button collapses it.
- **Glassware** offers **Light**, **Dark**, and **Christmas**, with a matching monogram and startup screen.
- **The terminal**: arrow-key menus, `Space` to tick, `/` to search, `U` to undo, `Esc` to go back.
- **Desktop shortcut**: asked on exit. **Yes** keeps WinNow with a shortcut; **No** removes WinNow's own files like an uninstall (logs and backups stay).
- **Updates**: every start asks GitHub for the latest release and shows its changelog: update now, keep this version, or skip it.
</details>

<details>
<summary><b>Profiles and scheduled maintenance</b></summary>

- **Profiles**: save this PC (applied tweaks and preferences, installed catalog apps) as a profile, export it to a `.json` file, import it on another PC and apply it in one step, with the usual backup and restore point.
- **Scheduled maintenance**: a Windows scheduled task, weekly or every four weeks, cleans temporary files and upgrades every app with winget. It runs from a permanent copy, never from the download in `%TEMP%`.
- `-Maintain Temp,Upgrade` runs the same maintenance without questions.
</details>

## Run it

Open **PowerShell** or Windows Terminal and run:

```powershell
irm eperez98.github.io/WinNow | iex
```

1. The launcher downloads the latest release and its signature, verifies the ZIP, then extracts it into a unique folder under `%TEMP%`. It asks for administrator rights when needed.
2. The first time, pick **EN** or **ES**, the window or the terminal, and Light or Dark. After that WinNow opens straight in your choice.
3. To look around first, turn on **simulation mode** (`M` in the terminal, the checkbox in the window).

**Offline:** download `Winnow.zip` from [Releases](https://github.com/eperez98/WinNow/releases/latest), extract it and run `Launch.bat` as administrator.

**Requirements:** Windows 10 (19041+) or 11, Windows PowerShell 5.1 or PowerShell 7, administrator rights for real changes. winget for the App Manager. Internet only for updates and app installs.

<details>
<summary><b>Command line</b></summary>

```powershell
.\Winnow.ps1 -DryRun                                  # simulation: nothing is changed
.\Winnow.ps1 -Lang es -GUI                            # Spanish, straight to the window
.\Winnow.ps1 -Terminal                                # straight to the terminal menus
.\Winnow.ps1 -List                                    # tweak keys and presets
.\Winnow.ps1 -Status                                  # detected state of every tweak
.\Winnow.ps1 -Preset Standard -Yes                    # unattended preset
.\Winnow.ps1 -Apply Telemetry,ClassicContextMenu -DryRun
.\Winnow.ps1 -Undo ClassicContextMenu
.\Winnow.ps1 -Install firefox,7zip,vscode -Yes
.\Winnow.ps1 -Maintain Temp,Upgrade                  # scheduled-style maintenance, no questions
.\Winnow.ps1 -NoUpdateCheck -NoRestorePoint
```

The exit code is `1` if any step failed.
</details>

## Preparing a release

[Build-WNRelease.ps1](tools/Build-WNRelease.ps1) builds and verifies the three release assets using the existing release key.

```powershell
.\tools\Build-WNRelease.ps1 -Source . -OutputDirectory ..\release-assets
```

Attach Winnow.zip, Winnow.zip.sig, and run.ps1 to the same GitHub release. The GitHub Pages command follows the release marked Latest.

## Security

WinNow runs as administrator, so it treats what it reads back as untrusted until it knows who wrote it.

| Area | What WinNow does |
|---|---|
| **Downloads** | The launcher and in-app updater require a valid RSA-SHA256 signature before extracting a ZIP. To publish a release, sign the final ZIP with the existing WinNow release key and upload it alongside Winnow.zip.sig. |
| **Changes** | Simulation mode, a JSON backup before every change, an optional System Restore point, and undo that only touches what WinNow applied. High-risk items are flagged before you confirm. |
| **Data folder** | `%ProgramData%\Winnow` (logs and backups) belongs to Administrators; Users can only read it. A folder another account created first is taken back, and planted links are removed. |
| **Backups** | Restored only when an administrator, SYSTEM or you wrote them. |
| **Updates** | Only from this repository's releases over HTTPS. Every file gets a SHA256 when it is downloaded, checked again right before the swap, and the swap is all or nothing. |
| **Removal** | Answering **No** on exit deletes only WinNow's own copies, never a folder you extracted yourself. |

## Roadmap

<img src="docs/road-to-2.0.png" alt="Road to 2.0" width="100%" />

| Version | Name | Goals |
|---|---|---|
| **1.8** | Trusted Updates | Signed releases, a history of every session with undo, the final GUI Rethinked |
| **1.8.1** | Polish | A closing dialog in the window's own look |
| **1.8.2** | Starting Point | A starting point tour; Office Helper with Thunderbird, LibreOffice and OpenOffice |
| **1.8.3** | GUI Terminal Update | A task window with live output and a progress bar |
| **2.0** | Store Edition | MSIX package in the Microsoft Store |

Ideas, not promises: more changes may be added and others removed. Every past release is in the [CHANGELOG](CHANGELOG.md).

## Under the hood

| Layer | Technology |
|---|---|
| Engine | PowerShell 5.1 / 7, no extra modules; registry, services, appx and winget |
| Catalog | Declarative JSON: `config/tweaks.json`, `apps.json`, `services.json`, `presets.json`, `dns.json` |
| Window | WPF (in Windows), XAML parsed at runtime, a background worker so it never freezes; `gui/Launcher.ps1` for the start window |
| Terminal | Own arrow-key menus, check lists with search, confirmations |
| i18n | `config/i18n.json` and `config/catalog.es.json`, English and Spanish |
| Updates | GitHub releases, staged download with SHA256 checks |

<details>
<summary><b>Project structure and adding a tweak</b></summary>

```
Winnow.ps1          Entry point: parameters, elevation, main menu
Launch.bat          Double-click launcher (self-elevates, asks for the mode)
run.ps1             One-line launcher used by irm | iex
core/               Common, Engine (registry / services / backups), Tui, I18n, Update
modules/            Tweaks, TweakActions, Apps, Uninstall, Services, Startup, Repair, Updates, Network, System
gui/                Gui.ps1 (every page), Experience.ps1 (menu, glass, What's new), MainWindow.xaml, Launcher.ps1
config/             Tweak, app, service, preset and DNS catalogs; interface text
docs/ screenshots/  Release notes, image generators, pictures
tests/              Self-checks for the parsers
```

Registry and service tweaks need no code, only an entry in `config/tweaks.json`:

```json
{
  "Key": "MyTweak", "Name": "My tweak", "Category": "Privacy", "Type": "Tweak", "Risk": "Low", "Level": "Recommended",
  "Description": "What it does.",
  "Registry": [ { "Path": "HKCU:\\Software\\...", "Name": "Value", "Type": "DWord", "Value": "0", "Original": "<unset>" } ],
  "Services": [ { "Name": "SomeSvc", "Startup": "Disabled", "Original": "Manual" } ]
}
```

`"<unset>"` means the value does not exist (undo deletes it). `Type` is `Tweak` (undoable), `Toggle` (ON / OFF) or `Action` (one-shot). Optional: `Appx`, `Invoke` / `Undo` / `Check` (functions in `TweakActions.ps1`), `Restart`, `Group`, `MinBuild`, and `IfMissing` on a registry entry.
</details>

## Support development

If WinNow helps you, you can support it with a donation through [PayPal](https://www.paypal.com/donate/?business=erapc%40outlook.com&currency_code=USD). It is also in the app: About > Support development.

## More from the author

**[Monto](https://github.com/eperez98/monto)** — personal and family finances for Panama: income, semi-monthly paydays, expenses, budgets,
savings and debts, in balboas and dollars, for you or your whole household. A Windows desktop app (Tauri + React)
that works offline, in English and Spanish. No cloud, no account: your data stays on your computer.

## License

**GPL-3.0** © ErickP ([eperez98](https://github.com/eperez98)).

<div align="center"><br /><sub>WinNow · Proudly made in Panama PTY507 🇵🇦</sub></div>
