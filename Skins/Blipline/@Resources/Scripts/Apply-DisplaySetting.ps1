param(
    [string]$SettingsPath,
    [string]$OutputPath,
    [string]$Name,
    [string]$Value,
    [string]$Label = '',
    [string]$RefreshConfigs = ''
)

$ErrorActionPreference = 'Stop'

$localizationScript = Join-Path $PSScriptRoot 'Localization.ps1'
if (Test-Path -LiteralPath $localizationScript) {
    . $localizationScript
}

function Get-RainmeterIncludeEncoding {
    try {
        [System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
    } catch {}

    try {
        $ansiCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
        if ($ansiCodePage -gt 0) {
            return [System.Text.Encoding]::GetEncoding($ansiCodePage)
        }
    } catch {}

    return [System.Text.Encoding]::Default
}

function Set-IncValue {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Value
    )

    $pattern = '^' + [regex]::Escape($Name) + '='
    $replacement = "$Name=$Value"
    $found = $false
    $updated = foreach ($line in $Lines) {
        if (!$found -and $line -match $pattern) {
            $found = $true
            $replacement
        }
        else {
            $line
        }
    }

    if ($found) {
        return @($updated)
    }

    $insertAt = 0
    for ($i = 0; $i -lt $updated.Count; $i++) {
        if ($updated[$i] -match '^\[Variables\]') {
            $insertAt = $i + 1
            break
        }
    }

    if ($insertAt -le 0) {
        return @($replacement) + @($updated)
    }

    return @($updated[0..($insertAt - 1)]) + @($replacement) + @($updated[$insertAt..($updated.Count - 1)])
}

function Get-IncValue {
    param(
        [string[]]$Lines,
        [string]$Name
    )

    $pattern = '^' + [regex]::Escape($Name) + '=(.*)$'
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return ''
}

function Get-LanguageLabel {
    param([string]$Code)

    $pack = Get-BliplineLocalePack -Code $Code
    if ($pack.Contains('Meta') -and $pack['Meta'].Contains('Name')) {
        return [string]$pack['Meta']['Name']
    }
    return 'English'
}

function Get-LanguageIndex {
    param([string]$Code)

    $pack = Get-BliplineLocalePack -Code $Code
    $index = 1
    if ($pack.Contains('Meta') -and $pack['Meta'].Contains('Index') -and [int]::TryParse($pack['Meta']['Index'], [ref]$index)) {
        return $index
    }
    return 1
}

function Remove-RainmeterUnsafeUnicode {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Text.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::Control -and
            $category -ne [Globalization.UnicodeCategory]::Surrogate -and
            $char -ne [char]0xFFFD) {
            [void]$builder.Append($char)
        }
    }

    return $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Convert-SettingsLabel {
    param([string]$Text)
    return Convert-BliplineRainmeterText $Text
}

function Get-SettingsLabels {
    param([string]$Code)

    $resolvedCode = Resolve-BliplineLanguageCode -Code $Code -Fallback 'en'
    return Get-BliplineLocaleSection -Code $resolvedCode -Section 'Settings'
}

function Convert-ImportTemplateToRegex {
    param([string]$Text)

    $pattern = [regex]::Escape((Convert-SettingsLabel $Text))
    return '^' + ($pattern -replace '\\\{[0-9]+\\\}', '(.+?)') + '$'
}

function Format-ImportLabel {
    param(
        [hashtable]$Labels,
        [string]$Key,
        [object[]]$FormatArgs = @()
    )

    if (!$Labels.Contains($Key)) {
        return ''
    }

    $text = [string]$Labels[$Key]
    if ($FormatArgs.Count -gt 0) {
        try {
            return ($text -f $FormatArgs)
        } catch {
            return $text
        }
    }

    return $text
}

function Find-ImportTextMatch {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $cleanText = Convert-SettingsLabel $Text
    foreach ($languageCode in @(Get-BliplineAvailableLanguageCodes)) {
        $labels = Get-BliplineLocaleSection -Code $languageCode -Section 'Import'
        foreach ($entry in $labels.GetEnumerator()) {
            if ([string]$entry.Value -match '\{[0-9]+\}') {
                continue
            }

            if ($cleanText -eq (Convert-SettingsLabel $entry.Value)) {
                return @{
                    Key = $entry.Key
                    FormatArgs = @()
                }
            }
        }

        foreach ($entry in $labels.GetEnumerator()) {
            if ([string]$entry.Value -notmatch '\{[0-9]+\}') {
                continue
            }

            $match = [regex]::Match($cleanText, (Convert-ImportTemplateToRegex $entry.Value))
            if ($match.Success) {
                $args = @()
                for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                    $args += $match.Groups[$i].Value
                }
                return @{
                    Key = $entry.Key
                    FormatArgs = $args
                }
            }
        }
    }

    $legacyClearedMatch = [regex]::Match($cleanText, '^Cleared feeds at (.+)$')
    if ($legacyClearedMatch.Success) {
        return @{
            Key = 'Cleared'
            FormatArgs = @($legacyClearedMatch.Groups[1].Value)
        }
    }

    return $null
}

function Update-PersistedImportText {
    param(
        [string[]]$Lines,
        [string]$Name,
        [hashtable]$Labels
    )

    $match = Find-ImportTextMatch -Text (Get-IncValue -Lines $Lines -Name $Name)
    if ($null -ne $match -and $Labels.Contains($match.Key)) {
        $translated = Format-ImportLabel -Labels $Labels -Key $match.Key -FormatArgs $match.FormatArgs
        return @(Set-IncValue -Lines $Lines -Name $Name -Value (Convert-SettingsLabel $translated))
    }

    return @($Lines)
}

if ([string]::IsNullOrWhiteSpace($SettingsPath) -or !(Test-Path -LiteralPath $SettingsPath)) {
    exit 1
}

$nameClean = $Name.Trim()
$valueClean = $Value.Trim()
$settingsEncoding = Get-RainmeterIncludeEncoding
$lines = @([System.IO.File]::ReadAllLines($SettingsPath, $settingsEncoding))

if ($nameClean -eq 'Language') {
    $allowed = @(Get-BliplineAvailableLanguageCodes)
    $code = Resolve-BliplineLanguageCode -Code $valueClean -Fallback 'en'
    if ($code -notin $allowed) {
        $code = 'en'
    }

    $labelClean = if (![string]::IsNullOrWhiteSpace($Label)) { $Label.Trim() } else { Get-LanguageLabel $code }
    $lines = @(Set-IncValue -Lines $lines -Name 'Language' -Value $code)
    $lines = @(Set-IncValue -Lines $lines -Name 'LanguageIndex' -Value (Get-LanguageIndex $code))
    $lines = @(Set-IncValue -Lines $lines -Name 'LanguageLabel' -Value $labelClean)
    foreach ($entry in (Get-SettingsLabels -Code $code).GetEnumerator()) {
        $lines = @(Set-IncValue -Lines $lines -Name $entry.Key -Value (Convert-SettingsLabel $entry.Value))
    }

    $importLabels = Get-BliplineLocaleSection -Code $code -Section 'Import'
    $lines = @(Update-PersistedImportText -Lines $lines -Name 'FeedImportStatus' -Labels $importLabels)
    $lines = @(Update-PersistedImportText -Lines $lines -Name 'FeedStatusSummary' -Labels $importLabels)
}
elseif ($nameClean -eq 'TimeFormat') {
    $format = if ($valueClean -match '^(24|24h|hh:mm|h24|true|1)$') { '24' } else { '12' }
    $lines = @(Set-IncValue -Lines $lines -Name 'TimeFormat' -Value $format)
}
elseif ($nameClean -eq 'RefreshSeconds') {
    $seconds = 300
    $parsedSeconds = 0
    if ([int]::TryParse($valueClean, [ref]$parsedSeconds)) {
        $seconds = [Math]::Min([Math]::Max($parsedSeconds, 60), 3600)
    }
    $ticks = [Math]::Max(1, [int]($seconds * 20))
    $minutes = [Math]::Round($seconds / 60, 2)
    $lines = @(Set-IncValue -Lines $lines -Name 'RefreshMinutes' -Value $minutes)
    $lines = @(Set-IncValue -Lines $lines -Name 'RefreshSeconds' -Value $seconds)
    $lines = @(Set-IncValue -Lines $lines -Name 'RefreshTicks' -Value $ticks)
}
else {
    exit 1
}

[System.IO.File]::WriteAllLines($SettingsPath, [string[]]$lines, $settingsEncoding)

$agendaScript = Join-Path $PSScriptRoot 'Update-Agenda.ps1'
if (![string]::IsNullOrWhiteSpace($OutputPath) -and (Test-Path -LiteralPath $agendaScript)) {
    & $agendaScript -SettingsPath $SettingsPath -OutputPath $OutputPath -UseExistingCache
}

if (![string]::IsNullOrWhiteSpace($RefreshConfigs)) {
    $rainmeter = Join-Path ${env:ProgramFiles} 'Rainmeter\Rainmeter.exe'
    if (Test-Path -LiteralPath $rainmeter) {
        foreach ($config in ($RefreshConfigs -split '\|')) {
            $cleanConfig = $config.Trim()
            if (![string]::IsNullOrWhiteSpace($cleanConfig)) {
                & $rainmeter !Refresh $cleanConfig
            }
        }
    }
}
