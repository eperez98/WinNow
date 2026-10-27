# Self-check for the CHANGELOG reader used by the update check. Run: powershell -File tests\ConvertFrom-WNChangelog.Tests.ps1
. "$PSScriptRoot\..\core\Update.ps1"
$md = @(
    '# Changelog', '', '## [Unreleased]', '- planned', '',
    '## [1.0.7.1] - 2026-10-27 - Release Build', '### Added', '- **GUI** with `every` module', '',
    '## [1.0.5] - 2026-10-25', '### Fixed', '- uninstall', '',
    '## [1.0.1] - 2026-10-24', '- old', '',
    '[Unreleased]: https://example/compare', '[1.0.5]: https://example/tag'
)
$r = ConvertFrom-WNChangelog $md ([version]'1.0.1')
$expected = @('[1.0.7.1] - 2026-10-27 - Release Build', '### Added', '- GUI with every module', '', '[1.0.5] - 2026-10-25', '### Fixed', '- uninstall')
if (($r -join '|') -ne ($expected -join '|')) { throw "FAIL got: $($r -join ' | ')" }
if (@(ConvertFrom-WNChangelog $md ([version]'1.0.7.1')).Count) { throw 'FAIL nothing is newer than 1.0.7.1' }
if ((ConvertTo-WNVersion 'v1.0.5') -ne [version]'1.0.5' -or (ConvertTo-WNVersion 'beta')) { throw 'FAIL version parsing' }
if (-not ((ConvertTo-WNVersion 'v1.0.10') -gt (ConvertTo-WNVersion '1.0.9'))) { throw 'FAIL numeric compare' }
'ConvertFrom-WNChangelog: all cases pass'
