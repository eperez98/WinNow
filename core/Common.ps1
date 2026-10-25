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
        Version          = '1.0.1'
        Channel          = 'Release Build'
        Author           = 'ErickP (Eperez98)'
        Repo             = 'https://github.com/eperez98/Winnow'
        Root             = $Root
        DryRun           = [bool]$DryRun
        Yes              = [bool]$Yes
        NoRestorePoint   = [bool]$NoRestorePoint
        IsAdmin          = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        OSBuild          = $os.Build
        IsWin11          = $os.Build -ge 22000
        OSLabel          = if ($os.Build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
        Interactive      = -not [Console]::IsInputRedirected
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
    foreach ($d in @($base, (Join-Path $base 'logs'), (Join-Path $base 'backup'))) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $WN.DataDir = $base
    $WN.LogFile = Join-Path $base ("logs\Winnow_{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

    # Backups taken before the rename live in the old WinTooler folder; copy them over once
    $legacy = Join-Path (Split-Path $base) 'WinTooler\backup'
    if (Test-Path $legacy) {
        Get-ChildItem -Path $legacy -File -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-Path (Join-Path $base "backup\$($_.Name)")) } |
            Copy-Item -Destination (Join-Path $base 'backup') -ErrorAction SilentlyContinue
    }

    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -Scope Global | Out-Null
    }

    Write-WNLog "==== $($WN.Name) $($WN.Version) start | $env:COMPUTERNAME | $($WN.OSLabel) build $($WN.OSBuild) | admin=$($WN.IsAdmin) dryrun=$($WN.DryRun) | PS $($PSVersionTable.PSVersion)"
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
    & $FilePath @ArgumentList | Out-Host
    $code = $LASTEXITCODE
    if (Get-Command Clear-WNKeyBuffer -ErrorAction SilentlyContinue) { Clear-WNKeyBuffer }
    Write-WNLog "Exit $code : $display" -Component $Component
    return $code
}
