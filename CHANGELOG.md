# Changelog

All notable changes to Winnow are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- Graphical interface: leave preview, per-step progress bars.
- Shorter launch URL for the one-line installer.

## [1.0.7.1] - 2026-10-27 - HotFix & Preview Update

### Added
- **Graphical interface with every module** (still a preview): Tweaks, Preferences, Services, Startup apps,
  App Manager, Uninstall programs, Repair & maintenance, Windows Update, Backups & restore, DNS, Hosts file,
  System information and Logs, grouped in the sidebar like the terminal main menu (Optimize, Apps, Maintain,
  Network, System).
- **New GUI design**: dark window with an orange accent, sidebar, a search bar on top that filters the list of the
  current page (Enter on the App Manager searches all of winget), round buttons for language, terminal edition and
  log, and a home page with a large banner, a **Start here** card that opens the recommended tweaks, and a poster
  card for every tool.
- **Tweak levels**: every tweak is now **Recommended** (18 gentle changes, safe for any PC: nothing is removed,
  services and network are untouched, all can be undone) or **Advanced** (33 changes that need care: removing apps,
  services, network, power plans, interface). The terminal Tweaks menu lists both levels first (`R`, `A`), then the
  categories; the GUI Tweaks page has Recommended / Advanced / All tabs with an explanation card, and asks again when
  advanced tweaks are selected. New `Level` field in `config/tweaks.json`.
- **Update check at every start**: Winnow asks GitHub for the latest release and, when it is newer, shows the
  version and the changelog sections since the installed one. Choices: update now (download, replace this copy,
  restart), keep using the current version, or skip that version. Silent when offline; a failed update rolls back.
  Also `U` in the main menu, the update button in the GUI, and `-NoUpdateCheck` to turn it off.
- **Desktop shortcut** with the Winnow logo (`LOGO/Winnow.ico`), offered once on the first start and available as
  `K` in the main menu and in the GUI. It opens the local copy directly; a copy started from the one-line command is
  first copied to `%LOCALAPPDATA%\Programs\Winnow`.
- GUI extras: select applied tweaks for undo, installed tags and upgrade all in the App Manager, desktop / Store
  switch when uninstalling, pause days for Windows Update, double confirmation before deleting every restore
  point, live output of SFC, DISM and winget in the log.
- Self-checks for the installed-app set and the changelog reader used by the update check.

### Changed
- **Presets follow the levels**: Standard is exactly the recommended set (it no longer trims services, edits the
  hosts file or removes Widgets); Minimal is privacy only; Heavy is Standard plus a selection of advanced tweaks.
- **Terminal main menu reorganized** into the same groups as the GUI: Optimize (1-4), Apps (5-6),
  Maintain (7-9: repair, Windows Update, backups), Network (`D` DNS, `H` hosts), System (`Y` information,
  `L` logs) and Winnow (`G` graphical interface, `U` updates, `K` shortcut, `I` language, `M` simulation).
- Repair tasks, Windows Update status, current DNS, system information, restore point deletion and backup
  deletion are now shared functions used by both editions.

### Fixed
- Installing or uninstalling apps ended with "Collection was of a fixed size": the installed-app list is now kept
  as a set, and it is read again from winget after every install or uninstall so the INSTALLED tags are current.

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

[Unreleased]: https://github.com/eperez98/Winnow/compare/v1.0.7.1...HEAD
[1.0.7.1]: https://github.com/eperez98/Winnow/releases/tag/v1.0.7.1
[1.0.5]: https://github.com/eperez98/Winnow/releases/tag/v1.0.5
[1.0.1]: https://github.com/eperez98/Winnow/releases/tag/v1.0.1
[1.0.0]: https://github.com/eperez98/Winnow/releases/tag/v1.0.0
