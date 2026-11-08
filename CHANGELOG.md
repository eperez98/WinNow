# Changelog

All notable changes to Winnow are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Planned
- **1.5 November Update**: new name WinNow and a logo for light and dark mode; startup apps listed active first.
- More changes may be added and others removed.

## [1.2.2] - 2026-11-07 - Secure Update · Security Compliance Hotfix

The terminal edition and the graphical interface are both **1.2.2 Secure Update**. It also ships everything
from 1.2 Exit & Launcher Update, which was not published on its own.

### Added
- **Update panel in the window**: the update button opens a panel over the window with an animation for each
  step: checking, **Update available** with what changed (Update / Not now / Skip this version), downloading, and
  **Restart required** with **Restart now** (Winnow closes, updates its files and restarts) or **Later** (the
  download is discarded and you keep using the current version). It replaces the plain message box. The download
  and the file swap are separate steps, so nothing is replaced until you choose Restart now.

### Security
- **Winnow's data folder (`C:\ProgramData\Winnow`) is now admin-only**: owner Administrators, full control for
  SYSTEM and Administrators, read-only for Users. Before, any standard account on the PC could add a backup file
  there, and restoring it as administrator would write its registry values. A folder another user created first
  is taken back, links planted in place of its subfolders are removed, and backups (also the ones imported from
  the old WinTooler folder) are only used when an administrator, SYSTEM or you wrote them.
- **Downloaded updates are checked before they are installed**: the SHA256 of every unpacked file is recorded when
  the update is downloaded and compared again at "Restart now"; if anything changed, the update stops.

### Fixed
- A failed update could leave a mix of two versions (for example the new `Winnow.ps1` with the old modules), and
  Winnow would no longer start. Every file and folder the update brings is now set aside first and put back if
  anything fails.

### Changed
- **Search winget never waits**: the winget search runs on its own instead of queuing behind the window's tasks
  (opening the App Manager reads the installed apps, which can take a while on some PCs), says "Searching all of
  winget..." at once, and reports a winget that does not answer within 60 seconds. With an empty box, Search winget
  asks for an app name. In the window, typing also searches all of winget after a short pause.
- **Theme picker**: the theme button unfolds a panel inside the window that grows out of the button, and the
  themes slide in one after the other, each with a swatch of its colours. A click outside it, Esc or a choice folds
  it back.
- **Minimal icons**: home tool icons are line glyphs on a quiet tile, white or black, and Panama blue on white
  in mes patrio.
- The search box selects its text on a click, so typing replaces it. The name in the top bar is smaller and opens
  About.
- **Support development**: About (window and terminal) links to WinNow's PayPal donation page.
## [1.2] - 2026-11-02 - Exit & Launcher Update

The terminal edition and the graphical interface are both **1.2 Exit & Launcher Update**.

### Added
- **Desktop shortcut question on exit**, in the terminal and the window, whenever there is no shortcut yet
  (always for a copy started with the one-line command). **Yes** creates the shortcut and keeps the files (a
  downloaded copy is first copied to `%LOCALAPPDATA%\Programs\Winnow`). **No** deletes Winnow's own files from
  this PC like an uninstall: the download in `%TEMP%`, that copy and the desktop shortcut, once every Winnow window
  started from them has closed. A folder you extracted yourself is never deleted, and "No" is remembered for it;
  logs and backups are kept.

### Changed
- Opening Winnow again (mode choice, update restart, terminal button) builds its arguments in one place, so the
  language, simulation and update-check settings always carry over.

### Removed
- `Launch-GUI.bat`. `Launch.bat` is the only launcher and asks for the mode (terminal or graphical interface).

## [1.1.5] - 2026-11-02 - Restore Point Choice

The terminal edition and the graphical interface are both **1.1.5 Restore Point Choice**.

### Added
- **Skip the restore point**: before the first change of a session the terminal asks whether to create a System
  Restore point, and the window's confirmation offers Yes (with restore point), No (without it) or Cancel. The
  JSON backup is taken either way.

## [1.1] - 2026-11-04 - Full GUI Release

The graphical interface leaves preview: the terminal and the window have the same tools. The Full GUI Release was
first planned as 1.2 for November 8, 2026.

### Added
- Graphical interface: **step-by-step progress bar** in the status bar for batches (tweaks, app installs and
  uninstalls, uninstall programs, Store apps), with "Step 2 of 5: name".
- Graphical interface: **List available upgrades** in the App Manager (what `winget upgrade` would update), also in
  simulation mode.

### Changed
- "Preview" / "Release Candidate" labels removed from the window, menus and docs.
- **Theme menu with mes patrio**: the theme button opens **Light**, **Dark** (the default logo and banner) and
  **Mes patrio**. November is Panama's patriotic month: mes patrio uses the Panama icon (window, taskbar, desktop
  shortcut), the flag on the Home banner and an aero background in Panama navy and red, and it is the starting theme
  in November. The README banner wears the flag of Panama, and "Proudly made in Panama PTY507" sits next to the
  logo on Home, About, the terminal banner and the README.
- README screenshots retaken for 1.1, including the mes patrio theme.

## [1.0.9] - 2026-11-03 - Selection Fix

The terminal edition and the graphical interface are both **1.0.9 Selection Fix**.

### Fixed
- Graphical interface: with two or more rows selected, **Uninstall programs**, **Install / Uninstall selected** in the
  App Manager and **Enable / Disable** in the Startup Manager sent one empty item named "Item" instead of the
  selected entries ("Uninstall of Item ended with code Cannot bind argument to parameter 'Line'").

### Changed
- Uninstalls (apps, programs, Store apps) print `[i/N]` before each item, like installs and tweaks.

## [1.0.8] - 2026-10-31 - Update Fixer

The terminal edition and the graphical interface are both **1.0.8 Update Fixer**.

### Added
- **Terminal or GUI on every start.** After the language, the first screen asks how to use Winnow: **Terminal**
  (keyboard menus) or **Graphical interface (GUI) (Preview)**. The last choice is highlighted first. `-Terminal`
  and `-GUI` skip the question; `Launch-GUI.bat`, the terminal button in the window and restarts after an update
  skip it too.
- **Shorter one-line command:** `irm eperez98.github.io/WinNow | iex`. It runs the launcher of the latest release, like the old
  `irm https://github.com/eperez98/Winnow/releases/latest/download/run.ps1 | iex`, which keeps working.
- **About Winnow**: `A` in the terminal main menu and Winnow > About Winnow in the window. What Winnow is, how
  its core works, every published release in one line, and what is on the way: **1.5 Full GUI Release** with
  all its upcoming changes. More changes may be added and others removed.

### Fixed
- **Updating from the graphical interface works again.** From 1.0.7.1 to 1.0.7.3 the window kept the logo files
  open, so the update stopped with "The process cannot access the file ... Winnow_icon_128.png" and only the
  terminal could update. The window now reads its images into memory, and the logos are renamed
  (`LOGO/Winnow_128.png`, `LOGO/Winnow_512.png`) so the 1.0.7.x windows can install this release too.

## [1.0.7.3] - 2026-10-29 - HotFix Update Fixer

The terminal edition and the graphical interface are both **1.0.7.3 HotFix Update Fixer**.

### Changed
- **Update all apps** (winget) no longer creates a System Restore point first, in the terminal and in the
  graphical interface. Creating one could take minutes, and winget upgrades are not something a restore point
  undoes. It also no longer asks for confirmation: the button (or `G` in the terminal) runs `winget upgrade --all`
  right away. The JSON backup with the list of installed apps is still saved. Tweaks, services, DNS and every other
  change still create the restore point as before.

## [1.0.7.2] - 2026-10-28 - GUI Release Candidate

Only the graphical interface changes. The terminal edition stays at **1.0.7.1 Stable Release**; the graphical
interface is **1.0.7.2 Release Candidate**.

### Added
- **Light and dark mode** with a sun / moon switch in the top bar. It starts in the Windows apps setting and
  remembers the choice; every colour, badge and the title bar follow it at once.
- **EN | ES** language switch in the top bar (the active language is highlighted) instead of the globe button.
- **Update status button**: "Check for this tool updates". After checking it reads "No updates available", or
  "Update available: x.y.z", which opens the changelog with update now / keep this version / skip this version.
  The startup check now runs in the background after the window opens instead of before it.

### Changed
- **New look**: translucent and flat, in the Windows 11 / iOS style. Acrylic backdrop on Windows 11 22H2 or later
  (solid colour on older builds), frosted cards, rounded corners, blue accent, and app-icon style tiles on the
  home page.
- Version labels: the terminal shows `1.0.7.1 Stable Release`, the window `1.0.7.2 Release Candidate`. The update
  check compares a release with the newer of the two.

### Fixed
- The graphical interface opened minimized when it was started from a minimized console (`Launch-GUI.bat`, after an
  update or a language switch).

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

[Unreleased]: https://github.com/eperez98/Winnow/compare/v1.2.2...HEAD
[1.2.2]: https://github.com/eperez98/Winnow/releases/tag/v1.2.2
[1.2]: https://github.com/eperez98/Winnow/releases/tag/v1.2.2
[1.1.5]: https://github.com/eperez98/Winnow/releases/tag/v1.1.5
[1.1]: https://github.com/eperez98/Winnow/releases/tag/v1.1
[1.0.9]: https://github.com/eperez98/Winnow/releases/tag/v1.0.9
[1.0.8]: https://github.com/eperez98/Winnow/releases/tag/v1.0.8
[1.0.7.3]: https://github.com/eperez98/Winnow/releases/tag/v1.0.7.3
[1.0.7.2]: https://github.com/eperez98/Winnow/releases/tag/v1.0.7.2
[1.0.7.1]: https://github.com/eperez98/Winnow/releases/tag/v1.0.7.1
[1.0.5]: https://github.com/eperez98/Winnow/releases/tag/v1.0.5
[1.0.1]: https://github.com/eperez98/Winnow/releases/tag/v1.0.1
[1.0.0]: https://github.com/eperez98/Winnow/releases/tag/v1.0.0
