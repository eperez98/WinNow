<div align="center">

**English** · [Español](README.es.md)

<img src="docs/readme-hero-en.png" alt="WinNow: debloat and maintain Windows 10 and 11" width="100%" />

<br />

[![Run WinNow](https://img.shields.io/badge/Run%20WinNow-1.5%20QL%20Update%20Mid%20November-0F766E?style=for-the-badge&logo=windows&logoColor=white)](#run-it)

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

<div align="center">
<img src="screenshots/en/home.png" alt="WinNow home" width="100%" />
<sub><b>Home</b> — every tool grouped like the terminal menu, with a <b>Start here</b> card for the recommended tweaks.</sub>
</div>

<br />

| | |
|:---:|:---:|
| <img src="screenshots/en/tweaks.png" alt="Tweaks" /><br /><sub><b>Tweaks</b> — live status, apply and real undo, presets</sub> | <img src="screenshots/en/tweaks-advanced.png" alt="Advanced tweaks" /><br /><sub><b>Advanced tweaks</b> — with a caution note before you apply them</sub> |
| <img src="screenshots/en/preferences.png" alt="Preferences" /><br /><sub><b>Preferences</b> — 18 ON / OFF switches</sub> | <img src="screenshots/en/services.png" alt="Services" /><br /><sub><b>Services</b> — current vs. recommended vs. Windows default</sub> |
| <img src="screenshots/en/repair.png" alt="Repair" /><br /><sub><b>Repair & maintenance</b> — SFC, DISM, cleanup, resets</sub> | <img src="screenshots/en/updates.png" alt="Windows Update" /><br /><sub><b>Windows Update</b> — recommended policy, defaults, pause, resume</sub> |
| <img src="screenshots/en/about.png" alt="About" /><br /><sub><b>About WinNow</b> — the core, every release and what comes next</sub> | <img src="screenshots/en/theme-picker.png" alt="Theme picker" /><br /><sub><b>Themes</b> — Light, Dark and Mes patrio, picked in the window</sub> |

<details>
<summary><b>🎨 Light and Mes patrio themes</b></summary>
<br />

| | |
|:---:|:---:|
| <img src="screenshots/en/home-light.png" alt="Light theme" /><br /><sub>Light theme</sub> | <img src="screenshots/en/tweaks-light.png" alt="Tweaks, light" /><br /><sub>Tweaks in the light theme</sub> |
| <img src="screenshots/en/home-patria.png" alt="Mes patrio" /><br /><sub><b>Mes patrio</b>: November is Panama's patriotic month</sub> | <img src="screenshots/en/about-patria.png" alt="About, mes patrio" /><br /><sub>About in the mes patrio theme</sub> |

</details>

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

- **Two editions, one engine**: every start asks for the language and then **Terminal** or **Graphical interface**. `G` in the terminal opens the window; the window has a button for the terminal.
- **The window**: translucent Windows 11 style (acrylic on 22H2 or later), sidebar, a search bar for every page, step-by-step progress bar, **EN | ES** switch, and three themes — **Light**, **Dark** and **Mes patrio** (the default in November).
- **The terminal**: arrow-key menus, `Space` to tick, `/` to search, `U` to undo, `Esc` to go back.
- **Desktop shortcut**: asked on exit. **Yes** keeps WinNow with a shortcut; **No** removes WinNow's own files like an uninstall (logs and backups stay).
- **Updates**: every start asks GitHub for the latest release and shows its changelog: update now, keep this version, or skip it.
</details>

## Run it

Open **PowerShell** or Windows Terminal and run:

```powershell
irm eperez98.github.io/WinNow | iex
```

1. It downloads the latest release to `%TEMP%\Winnow-app` and asks for administrator rights. Nothing is installed.
2. Pick **English** or **Español**, then **Terminal** or **Graphical interface**.
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
.\Winnow.ps1 -NoUpdateCheck -NoRestorePoint
```

The exit code is `1` if any step failed.
</details>

## Security

WinNow runs as administrator, so it treats what it reads back as untrusted until it knows who wrote it.

| Area | What WinNow does |
|---|---|
| **Changes** | Simulation mode, a JSON backup before every change, an optional System Restore point, and undo that only touches what WinNow applied. High-risk items are flagged before you confirm. |
| **Data folder** | `%ProgramData%\Winnow` (logs and backups) belongs to Administrators; Users can only read it. A folder another account created first is taken back, and planted links are removed. |
| **Backups** | Restored only when an administrator, SYSTEM or you wrote them. |
| **Updates** | Only from this repository's releases over HTTPS. Every file gets a SHA256 when it is downloaded, checked again right before the swap, and the swap is all or nothing. |
| **Removal** | Answering **No** on exit deletes only WinNow's own copies, never a folder you extracted yourself. |

## Roadmap

<img src="docs/road-to-2.0.png" alt="Road to 2.0" width="100%" />

| Version | Name | Goals |
|---|---|---|
| **1.6** | GUI Rethinked | Launcher window with a boot animation, flat and minimal icons, update check at start |
| **1.7** | Profiles & Schedules | Save a PC as a profile and apply it on another; scheduled maintenance |
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
| Window | WPF (in Windows), XAML parsed at runtime, a background worker so it never freezes |
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
gui/                Gui.ps1 (every page) and MainWindow.xaml
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

## License

**GPL-3.0** © ErickP ([eperez98](https://github.com/eperez98)).

<div align="center"><br /><sub>WinNow · Proudly made in Panama PTY507 🇵🇦</sub></div>
