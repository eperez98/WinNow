# core/Common.ps1
# Shared state, logging, environment detection and small helpers.

function Initialize-WNContext {
    param(
        [Parameter(Mandatory)][string]$Root,
        [switch]$DryRun,
        [switch]$Yes,
        [switch]$NoRestorePoint
    )

    $os = [Environment]::OSVersion.Version
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    $global:WN = [ordered]@{
        Name             = 'Winnow'
        Version          = '1.2.2'
        Channel          = "Secure Update $([char]0x00B7) Security Compliance Hotfix"
        GuiVersion       = '1.2.2'
        GuiChannel       = "Secure Update $([char]0x00B7) Security Compliance Hotfix"
        Author           = 'ErickP (Eperez98)'
        Repo             = 'https://github.com/eperez98/Winnow'
        Donate           = 'https://www.paypal.com/donate/?business=erapc%40outlook.com&currency_code=USD'
        Root             = $Root
        DryRun           = [bool]$DryRun
        Yes              = [bool]$Yes
        NoRestorePoint   = [bool]$NoRestorePoint
        IsAdmin          = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        OSBuild          = $os.Build
        IsWin11          = $os.Build -ge 22000
        OSLabel          = if ($os.Build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
        Interactive      = -not [Console]::IsInputRedirected
        Gui              = $false
        Handoff          = $false
        RestorePointDone = $false
        ErrorCount       = 0
        Config           = @{}
        Cache            = @{}
        DataDir          = $null
        LogFile          = $null
        Lang             = 'en'
        I18n             = $null
        Strings          = $null
        CatalogEs        = $null
    }

    # Logs and backups live in ProgramData when elevated, otherwise in TEMP (DryRun without admin)
    $base = if ($WN.IsAdmin) { Join-Path $env:ProgramData 'Winnow' } else { Join-Path $env:TEMP 'Winnow' }
    if ($WN.IsAdmin) { Protect-WNDataDir $base }
    foreach ($d in @($base, (Join-Path $base 'logs'), (Join-Path $base 'backup'))) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $WN.DataDir = $base
    $WN.LogFile = Join-Path $base ("logs\Winnow_{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

    # Backups taken before the rename live in the old WinTooler folder; copy them over once
    $legacy = Join-Path (Split-Path $base) 'WinTooler\backup'
    if (Test-Path $legacy) {
        # Only files an admin wrote: that folder is open to every user
        Get-ChildItem -Path $legacy -File -ErrorAction SilentlyContinue |
            Where-Object { (Test-WNTrustedOwner $_.FullName) -and -not (Test-Path (Join-Path $base "backup\$($_.Name)")) } |
            Copy-Item -Destination (Join-Path $base 'backup') -ErrorAction SilentlyContinue
    }

    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -Scope Global | Out-Null
    }

    Write-WNLog "==== $($WN.Name) $($WN.Version) start | $env:COMPUTERNAME | $($WN.OSLabel) build $($WN.OSBuild) | admin=$($WN.IsAdmin) dryrun=$($WN.DryRun) | PS $($PSVersionTable.PSVersion)"
}

function Test-WNTrustedOwner {
    # Owned by Administrators, SYSTEM or the account running Winnow (never another standard user)
    param([Parameter(Mandatory)][string]$Path)
    try { $sid = (Get-Acl -LiteralPath $Path).GetOwner([Security.Principal.SecurityIdentifier]).Value } catch { return $false }
    return ($sid -in 'S-1-5-32-544', 'S-1-5-18', [Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
}

function Protect-WNDataDir {
    # ProgramData lets every user create files in new folders, and an elevated restore applies the backups found
    # here. Make the folder admin-only: owner Administrators, SYSTEM / Administrators full control, Users read.
    # Also takes back a folder another user created first, and removes links planted in place of the folders.
    param([Parameter(Mandatory)][string]$Path)
    # icacls reports per-file problems on stderr; under a caller's 'Stop' preference that would abort the start
    $ErrorActionPreference = 'Continue'
    foreach ($d in @($Path, (Join-Path $Path 'logs'), (Join-Path $Path 'backup'))) {
        $i = Get-Item -LiteralPath $d -Force -ErrorAction SilentlyContinue
        if ($i -and ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)) { [IO.Directory]::Delete($d) }
    }
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    $acl = Get-Acl -LiteralPath $Path
    if ($acl.AreAccessRulesProtected -and $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-32-544') { return }
    & icacls.exe $Path /setowner '*S-1-5-32-544' /T /C /Q *> $null
    & icacls.exe $Path /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' /Q *> $null
    if (Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue) { & icacls.exe "$Path\*" /reset /T /C /Q *> $null }
}

function Write-WNLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DRY')][string]$Level = 'INFO',
        [string]$Component = 'Core'
    )
    if (-not $global:WN -or -not $WN.LogFile) { return }
    $line = '[{0}][{1}][{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Component, $Message
    try { Add-Content -Path $WN.LogFile -Value $line -Encoding UTF8 -ErrorAction Stop } catch { }
}

# Console status line + log entry. Kind controls the tag and colour.
function Write-WNStatus {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Ok', 'Warn', 'Error', 'Dry', 'Step', 'Skip')][string]$Kind = 'Info',
        [string]$Component = 'Core'
    )
    $map = @{
        Info  = @('  ..  ', 'Gray',     'INFO')
        Ok    = @('  OK  ', 'Green',    'INFO')
        Warn  = @(' WARN ', 'Yellow',   'WARN')
        Error = @(' FAIL ', 'Red',      'ERROR')
        Dry   = @(' DRY  ', 'Magenta',  'DRY')
        Step  = @('  >>  ', 'Cyan',     'INFO')
        Skip  = @(' SKIP ', 'DarkGray', 'INFO')
    }
    $tag, $color, $level = $map[$Kind]
    if ($Kind -eq 'Error') { $WN.ErrorCount++ }
    Write-Host ' [' -NoNewline -ForegroundColor DarkGray
    Write-Host $tag -NoNewline -ForegroundColor $color
    Write-Host '] ' -NoNewline -ForegroundColor DarkGray
    Write-Host $Message
    Write-WNLog -Message $Message -Level $level -Component $Component
}

function Import-WNConfig {
    $cfg = Join-Path $WN.Root 'config'
    foreach ($name in @('tweaks', 'presets', 'apps', 'services', 'dns')) {
        $file = Join-Path $cfg "$name.json"
        if (-not (Test-Path $file)) { throw "Missing config file: $file" }
        try {
            $WN.Config[$name] = Get-Content -Path $file -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            throw "Invalid JSON in $file : $($_.Exception.Message)"
        }
    }
    # Hide tweaks that do not apply to this Windows build
    $WN.Config.tweaks = @($WN.Config.tweaks | Where-Object { -not $_.MinBuild -or $WN.OSBuild -ge [int]$_.MinBuild })
    Write-WNLog "Config loaded: $(@($WN.Config.tweaks).Count) tweaks, $(@($WN.Config.apps).Count) apps, $(@($WN.Config.services).Count) services"
}

function Get-WNTweak {
    param([Parameter(Mandatory)][string]$Key)
    $WN.Config.tweaks | Where-Object { $_.Key -eq $Key } | Select-Object -First 1
}

function Find-WNWinget {
    if ($WN.Cache.ContainsKey('winget')) { return $WN.Cache.winget }
    $path = $null
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { $path = $cmd.Source }
    if (-not $path) {
        $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if (Test-Path $candidate) { $path = $candidate }
    }
    if (-not $path) {
        # When elevated as a different user the WindowsApps alias is missing; use the package folder
        $pkg = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending | Select-Object -First 1
        if ($pkg) { $path = $pkg.FullName }
    }
    $WN.Cache.winget = $path
    return $path
}

function Restart-WNExplorer {
    if ($WN.DryRun) { Write-WNStatus (T 'exp.dry') Dry; return }
    Write-WNStatus (T 'exp.restarting') Step
    Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 1200
    # Windows usually restarts the shell by itself; start it only if it did not come back
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function Test-WNCanChange {
    # Every write path calls this first: real changes need admin, DryRun never touches the system
    if ($WN.DryRun) { return $true }
    if (-not $WN.IsAdmin) {
        Write-WNStatus (T 'common.needAdmin') Error
        return $false
    }
    return $true
}

function Invoke-WNNative {
    # Runs an external command, streams its output, logs exit code. Honors DryRun.
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$Component = 'Exec'
    )
    $display = "$FilePath $($ArgumentList -join ' ')".Trim()
    if ($WN.DryRun) { Write-WNStatus (T 'run.dry' $display) Dry $Component; return 0 }
    Write-WNLog "Run: $display" -Component $Component
    if ($WN.Gui) {
        # The GUI reads Write-Host records; keep the last progress frame of each line and drop the
        # NUL padding sfc/dism print in UTF-16
        & $FilePath @ArgumentList 2>&1 | ForEach-Object { $l = (("$_" -replace "`0", '') -split "`r")[-1]; if ($l.Trim()) { Write-Host $l } }
    } else {
        & $FilePath @ArgumentList | Out-Host
    }
    $code = $LASTEXITCODE
    if (Get-Command Clear-WNKeyBuffer -ErrorAction SilentlyContinue) { Clear-WNKeyBuffer }
    Write-WNLog "Exit $code : $display" -Component $Component
    return $code
}
