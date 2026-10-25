# core/I18n.ps1
# English / Spanish UI. Strings live in config/i18n.json; tweak, service and preset texts in
# config/catalog.es.json are laid over the English catalog when Spanish is selected.

function T {
    # Localized string by key, formatted with any extra arguments: T 'apps.installed' $name
    param([Parameter(Mandatory)][string]$Key, [Parameter(ValueFromRemainingArguments)][object[]]$FormatArgs)
    $s = $null
    if ($WN.Strings) { $s = $WN.Strings.$Key }
    if (-not $s -and $WN.I18n) { $s = $WN.I18n.en.$Key }
    if (-not $s) { return $Key }
    # Count, not truthiness: a lone 0 or empty string is still an argument to format
    if ($null -ne $FormatArgs -and $FormatArgs.Count -gt 0) { return ($s -f $FormatArgs) }
    return $s
}

function Get-WNSettings {
    $file = Join-Path $WN.DataDir 'settings.json'
    if (Test-Path $file) { try { return Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    return [pscustomobject]@{}
}

function Save-WNSetting {
    param([Parameter(Mandatory)][string]$Name, $Value)
    $s = Get-WNSettings
    $s | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    try { $s | ConvertTo-Json | Set-Content (Join-Path $WN.DataDir 'settings.json') -Encoding UTF8 } catch { }
}

function Set-WNLanguage {
    param([ValidateSet('en', 'es')][string]$Lang = 'en')
    if (-not $WN.I18n) {
        $WN.I18n = Get-Content (Join-Path $WN.Root 'config\i18n.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $WN.CatalogEs = Get-Content (Join-Path $WN.Root 'config\catalog.es.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    $WN.Lang = $Lang
    $WN.Strings = $WN.I18n.$Lang

    # Keep the English texts once so the language can be switched back and forth
    foreach ($t in @($WN.Config.tweaks)) {
        if (-not $t.PSObject.Properties['NameEn']) {
            $t | Add-Member -NotePropertyName NameEn -NotePropertyValue $t.Name
            $t | Add-Member -NotePropertyName DescriptionEn -NotePropertyValue $t.Description
        }
        $tr = if ($Lang -eq 'es') { $WN.CatalogEs.tweaks.($t.Key) } else { $null }
        $t.Name = if ($tr) { $tr.Name } else { $t.NameEn }
        $t.Description = if ($tr) { $tr.Description } else { $t.DescriptionEn }
    }
    foreach ($s in @($WN.Config.services)) {
        if (-not $s.PSObject.Properties['DisplayNameEn']) {
            $s | Add-Member -NotePropertyName DisplayNameEn -NotePropertyValue $s.DisplayName
            $s | Add-Member -NotePropertyName DescriptionEn -NotePropertyValue $s.Description
        }
        $tr = if ($Lang -eq 'es') { $WN.CatalogEs.services.($s.Name) } else { $null }
        $s.DisplayName = if ($tr) { $tr.DisplayName } else { $s.DisplayNameEn }
        $s.Description = if ($tr) { $tr.Description } else { $s.DescriptionEn }
    }
    foreach ($p in @($WN.Config.presets.PSObject.Properties)) {
        if (-not $p.Value.PSObject.Properties['DescriptionEn']) {
            $p.Value | Add-Member -NotePropertyName DescriptionEn -NotePropertyValue $p.Value.Description
        }
        $tr = if ($Lang -eq 'es') { $WN.CatalogEs.presets.($p.Name) } else { $null }
        $p.Value.Description = if ($tr) { $tr } else { $p.Value.DescriptionEn }
    }
    Write-WNLog "Language: $Lang"
}

function Show-WNLanguagePicker {
    # Asked every time the interactive app starts; the last choice is highlighted first
    $last = (Get-WNSettings).Lang
    $order = if ($last -eq 'es') { @('es', 'en') } else { @('en', 'es') }
    $items = @($order | ForEach-Object { @{ Label = $WN.I18n.$_.('lang.' + $_); Value = $_; Hint = $WN.I18n.$_.tagline } })
    $WN.Strings = $WN.I18n.($order[0])
    $choice = Show-WNMenu -Title (T 'lang.title') -Subtitle (T 'lang.subtitle') -Items $items -BackLabel (T 'lang.exit') -Banner
    if ($choice) { Save-WNSetting 'Lang' $choice }
    return $choice
}
