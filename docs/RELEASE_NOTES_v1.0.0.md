![Winnow](https://raw.githubusercontent.com/eperez98/Winnow/main/LOGO/Winnow_logo.png)

## Winnow 1.0.0

First release of **Winnow**: a keyboard-driven terminal app that sifts Windows 10/11 down to what matters. It strips telemetry, ads and bloat and keeps what you use. Every tweak declares the value it applies **and** the value it restores, so Winnow can tell what is already applied, apply it, and undo it for real.

### Run it

Open PowerShell and run:

```powershell
irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex
```

To try it first in simulation mode (nothing is changed, no admin needed):

```powershell
& ([scriptblock]::Create((irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1))) -DryRun
```

Offline: download **Winnow.zip** below, extract it, and run `Launch.bat` as administrator.

![Main menu](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/01-main-menu.png)
![Tweaks](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/03-tweaks-essential.png)
![App Manager](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/08-apps-browsers.png)
![Backups](https://raw.githubusercontent.com/eperez98/Winnow/main/screenshots/10-backups.png)

### Features

- **Terminal UI** with the Winnow logo banner. Arrow-key menus, Space to select, `/` to search, `U` to undo, Esc to go back.
- **69 catalog entries**: 51 tweaks in 6 categories with live status (`APPLIED` / `PARTIAL` / `-`), plus 18 ON/OFF preference switches.
- **Real undo**, plus an "Undo applied tweaks" scan. Presets: **Minimal / Standard / Heavy**.
- **Backup before every change.** Before any tweak, app install or uninstall, service, startup, DNS, update or repair change, Winnow saves a JSON snapshot of the exact current values. You can restore it from **Backups & restore**, where you can also delete old backups and delete restore points (the oldest one, or all of them). A System Restore Point is also created once per session.
- **Simulation mode** (`-DryRun` or the `M` key): prints every registry, service, app and command step without running it.
- **App Manager**: 376 apps via winget (Chocolatey fallback), installed detection, upgrade all.
- **Startup Manager** uses the same switches as Task Manager, so nothing is deleted.
- **Windows Update**: recommended (deferred) settings, defaults, pause (1–35 days) and resume.
- **DNS**: Cloudflare, Google, Quad9, OpenDNS and AdGuard providers, or back to DHCP.
- **Hosts**: tagged telemetry and Adobe blocks that can be removed exactly, with automatic backups.
- **Scripting**: `-Preset`, `-Apply`, `-Undo`, `-Install`, `-List`, `-Status`, `-Yes`.
- Logs are kept in `%ProgramData%\Winnow\logs`.

### Coming next

- **A more visual UI**: the next version adds a graphical interface on top of the same engine, alongside the terminal edition.
- Shorter launch URL.
- Spanish / English language option.

### Notes

- Requires Windows 10 (19041+) or 11 and PowerShell 5.1 or 7. Administrator rights are needed for real changes.
- Windows Defender may flag the hosts telemetry block as `HostsFileHijack`. This is expected for that tweak.
