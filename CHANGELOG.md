# Changelog

All notable changes to Winnow are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- Graphical interface: every terminal module in the window, per-step progress, Mica background and accent color.
- Shorter launch URL for the one-line installer.

## [1.0.5] - 2026-10-25 - Release Build

### Added
- **Graphical interface (preview)**: a WPF window in the Windows 11 style that follows the system light or dark
  theme, with sidebar navigation and the Winnow logo. Pages: **Home** (Windows, CPU, memory, system drive, uptime
  and quick actions), **Tweaks** (grouped by category, live state badges, filter, presets, apply and undo),
  **Apps** (filter the catalog or search all of winget, install) and **Coming next**. Changes run in a background
  worker on the same engine, so the window stays responsive and every change still gets a restore point, a
  backup and simulation mode. A live log, the simulation switch and the English / Spanish switch are included.
  Open it with `-GUI`, `Launch-GUI.bat`, or `G` in the terminal main menu.
- **Search winget by name** in the App Manager (`W`): type a name and install any winget package, not only the
  376 catalog apps.
- Self-checks in `tests/` for the uninstall command-line parser and the winget table parser.

### Fixed
- Uninstall programs: uninstallers that open a wizard returned exit code 1 and were not removed. Uninstall
  commands with unquoted paths containing spaces are now split correctly, the uninstaller window is shown so the
  wizard can be completed, and the result is checked against the registry: Winnow reports when a program is
  still installed (for example, when its wizard was cancelled).

## [1.0.1] - 2026-10-24 - Release Build

### Added
- **Language selector at startup**: English or Español is chosen before any option is shown. The last choice is
  highlighted next time, `-Lang en|es` skips the screen, and the main menu can switch language at any time.
- Full Spanish translation: menus, prompts, status messages, and every tweak, service and preset name and description.
- **Uninstall programs**: lists every installed desktop program (the same entries as Settings > Apps) and
  Microsoft Store app. MSI programs and programs with a quiet uninstaller are removed silently; others open their
  own uninstaller. A restore point and backup are taken first, as for every change.

### Changed
- Version label is now `1.0.1 Release Build` in the header, window title and release.

### Fixed
- Check lists with a single item returned no selection on Windows PowerShell 5.1.

## [1.0.0] - 2026-10-24

First release.

### Added
- Keyboard-driven terminal UI with the Winnow logo banner: arrow-key menus, Space to select, `/` to search,
  `U` to undo, Esc to go back.
- Declarative tweak catalog (`config/tweaks.json`): 51 tweaks in 6 categories (Essential, Privacy, Performance,
  Interface, Bloatware, Advanced) with live status detection and real undo, plus 18 ON/OFF preference switches.
- Presets: Minimal, Standard and Heavy, opened pre-selected for review.
- "Undo applied tweaks" scan.
- Backup before every change: a JSON snapshot of the exact registry values, service startup types, DNS servers
  and installed-app list, restorable from **Backups & restore**.
- Backups & restore menu: create, list and roll back to System Restore points; delete the oldest or all restore
  points (system drive only); delete Winnow backups.
- Automatic System Restore point before the first change of each session.
- Simulation mode (`-DryRun` or the `M` key): prints every registry, service, app and command step without running it.
- App Manager: 376 apps via winget with Chocolatey fallback, installed detection, upgrade all.
- Services manager: current vs recommended vs Windows default for 18 common services.
- Startup Manager using Task Manager's own enable/disable flags.
- Repair & maintenance: SFC, DISM, chkdsk scan, temp and disk cleanup, DNS flush, network reset,
  Windows Update reset, Store reset, winget source reset.
- Windows Update: recommended (deferred) policy, Windows defaults, pause 1-35 days, resume.
- DNS changer (Cloudflare, Google, Quad9, OpenDNS, AdGuard or DHCP) and hosts file blocks that can be removed exactly.
- System information and log viewer (`%ProgramData%\Winnow\logs`).
- Scripted use: `-Preset`, `-Apply`, `-Undo`, `-Install`, `-List`, `-Status`, `-Yes`, `-NoRestorePoint`.
- One-line launcher: `irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex`.

[Unreleased]: https://github.com/eperez98/Winnow/compare/v1.0.5...HEAD
[1.0.5]: https://github.com/eperez98/Winnow/releases/tag/v1.0.5
[1.0.1]: https://github.com/eperez98/Winnow/releases/tag/v1.0.1
[1.0.0]: https://github.com/eperez98/Winnow/releases/tag/v1.0.0
