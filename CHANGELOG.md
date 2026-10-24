# Changelog

All notable changes to Winnow are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- A more visual UI (graphical interface) on top of the same engine, alongside the terminal edition.
- Shorter launch URL for the one-line installer.
- Spanish / English language option.

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

[Unreleased]: https://github.com/eperez98/Winnow/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/eperez98/Winnow/releases/tag/v1.0.0
