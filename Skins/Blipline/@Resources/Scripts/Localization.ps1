function Get-BliplineRainmeterIncludeEncoding {
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

function Get-BliplineLocaleDirectory {
    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $scriptRoot = Split-Path -Parent $scriptPath
    return (Resolve-Path -LiteralPath (Join-Path $scriptRoot '..\Locales')).Path
}

function Convert-BliplineLanguageToken {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return (($Text.Trim().ToLowerInvariant()).Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '')
}

function Read-BliplineLocaleFile {
    param([string]$Path)

    $locale = [ordered]@{}
    $section = ''
    foreach ($line in [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)) {
        $clean = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($clean)) {
            continue
        }
        if ($clean.StartsWith(';')) {
            continue
        }
        if ($clean -match '^\[(.+)\]$') {
            $section = $matches[1].Trim()
            if (!$locale.Contains($section)) {
                $locale[$section] = [ordered]@{}
            }
            continue
        }
        if ($section -and $clean -match '^([^=]+)=(.*)$') {
            $locale[$section][$matches[1].Trim()] = $matches[2]
        }
    }

    return $locale
}

function Merge-BliplineLocaleSection {
    param(
        [hashtable]$Base,
        [hashtable]$Overlay
    )

    $merged = [ordered]@{}
    if ($Base) {
        foreach ($key in $Base.Keys) {
            $merged[$key] = $Base[$key]
        }
    }
    if ($Overlay) {
        foreach ($key in $Overlay.Keys) {
            $merged[$key] = $Overlay[$key]
        }
    }
    return $merged
}

function Get-BliplineLocalePack {
    param([string]$Code = 'en')

    if (!$script:BliplineLocaleCache) {
        $script:BliplineLocaleCache = @{}
    }

    $localeDir = Get-BliplineLocaleDirectory
    $code = Resolve-BliplineLanguageCode -Code $Code -Fallback 'en'
    if ($script:BliplineLocaleCache.ContainsKey($code)) {
        return $script:BliplineLocaleCache[$code]
    }

    $englishPath = Join-Path $localeDir 'en.ini'
    $english = Read-BliplineLocaleFile -Path $englishPath
    $selected = $english
    $selectedPath = Join-Path $localeDir "$code.ini"
    if ($code -ne 'en' -and (Test-Path -LiteralPath $selectedPath)) {
        $selected = Read-BliplineLocaleFile -Path $selectedPath
    }

    $pack = [ordered]@{}
    foreach ($section in $english.Keys) {
        $pack[$section] = Merge-BliplineLocaleSection -Base $english[$section] -Overlay $selected[$section]
    }

    if (!$pack['Meta'].Contains('Code')) {
        $pack['Meta']['Code'] = $code
    }

    $script:BliplineLocaleCache[$code] = $pack
    return $pack
}

function Get-BliplineAvailableLocaleMeta {
    $localeDir = Get-BliplineLocaleDirectory
    $items = @()
    foreach ($file in Get-ChildItem -LiteralPath $localeDir -Filter '*.ini') {
        $pack = Read-BliplineLocaleFile -Path $file.FullName
        if ($pack.Contains('Meta') -and $pack['Meta'].Contains('Code')) {
            $items += $pack['Meta']
        }
    }
    return @($items)
}

function Get-BliplineAvailableLanguageCodes {
    $codes = @()
    foreach ($meta in Get-BliplineAvailableLocaleMeta) {
        if ($meta.Contains('Code')) {
            $codes += [string]$meta['Code']
        }
    }
    return @($codes | Sort-Object -Unique)
}

function Resolve-BliplineLanguageCode {
    param(
        [string]$Code,
        [string]$Fallback = 'en'
    )

    $token = Convert-BliplineLanguageToken $Code
    if ([string]::IsNullOrWhiteSpace($token)) {
        return $Fallback
    }

    $localeDir = Get-BliplineLocaleDirectory
    if (Test-Path -LiteralPath (Join-Path $localeDir "$token.ini")) {
        return $token
    }

    foreach ($meta in Get-BliplineAvailableLocaleMeta) {
        $metaCode = Convert-BliplineLanguageToken $meta['Code']
        if ($token -eq $metaCode) {
            return [string]$meta['Code']
        }
        foreach ($key in @('Name', 'NativeName')) {
            if ($meta.Contains($key) -and $token -eq (Convert-BliplineLanguageToken $meta[$key])) {
                return [string]$meta['Code']
            }
        }
        if ($meta.Contains('Aliases')) {
            foreach ($alias in ([string]$meta['Aliases'] -split '\|')) {
                if ($token -eq (Convert-BliplineLanguageToken $alias)) {
                    return [string]$meta['Code']
                }
            }
        }
    }

    return $Fallback
}

function Get-BliplineLocaleSection {
    param(
        [string]$Code = 'en',
        [string]$Section
    )

    $pack = Get-BliplineLocalePack -Code $Code
    if ($pack.Contains($Section)) {
        return $pack[$Section]
    }
    return @{}
}

function Get-BliplineLocaleValue {
    param(
        [hashtable]$Pack,
        [string]$Section,
        [string]$Key,
        [string]$Default = ''
    )

    if ($Pack -and $Pack.Contains($Section) -and $Pack[$Section].Contains($Key)) {
        return [string]$Pack[$Section][$Key]
    }
    return $Default
}

function Format-BliplineText {
    param(
        [hashtable]$Labels,
        [string]$Key,
        [object[]]$FormatArgs = @()
    )

    $text = if ($Labels.Contains($Key)) { [string]$Labels[$Key] } else { '' }
    if ($FormatArgs.Count -gt 0) {
        return ($text -f $FormatArgs)
    }
    return $text
}

function Remove-BliplineUnsafeUnicode {
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

function Convert-BliplineRainmeterText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return ((Remove-BliplineUnsafeUnicode $Text) -replace '[\r\n=]', ' ').Trim()
}

function Test-BliplineMojibakeText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return ($Text -match '[ÃÂ�]')
}
