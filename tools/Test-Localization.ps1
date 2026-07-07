$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (!$Condition) {
        throw $Message
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$localizationScript = Join-Path $projectRoot 'Skins\Blipline\@Resources\Scripts\Localization.ps1'
. $localizationScript

$localeDir = Join-Path $projectRoot 'Skins\Blipline\@Resources\Locales'
$requiredBaseCodes = @('en', 'ru', 'es', 'it', 'fr', 'de')
$expectedCodes = @(Get-ChildItem -LiteralPath $localeDir -Filter '*.ini' | ForEach-Object { $_.BaseName } | Sort-Object)
foreach ($code in $requiredBaseCodes) {
    Assert-True ($code -in $expectedCodes) "Missing required base locale: $code.ini"
}
$english = Read-BliplineLocaleFile -Path (Join-Path $localeDir 'en.ini')

foreach ($code in $expectedCodes) {
    $path = Join-Path $localeDir "$code.ini"
    Assert-True (Test-Path -LiteralPath $path) "Missing locale file: $code.ini"

    $bytes = [System.IO.File]::ReadAllBytes($path)
    Assert-True ($bytes.Length -gt 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) "$code.ini is not UTF-8 with BOM."

    $pack = Read-BliplineLocaleFile -Path $path
    foreach ($section in $english.Keys) {
        Assert-True ($pack.Contains($section)) "$code.ini missing [$section]."

        $expectedKeys = @($english[$section].Keys | Sort-Object)
        $actualKeys = @($pack[$section].Keys | Sort-Object)
        $missing = @($expectedKeys | Where-Object { $_ -notin $actualKeys })
        $extra = @($actualKeys | Where-Object { $_ -notin $expectedKeys })
        Assert-True ($missing.Count -eq 0) "$code.ini [$section] missing key(s): $($missing -join ', ')"
        Assert-True ($extra.Count -eq 0) "$code.ini [$section] has unexpected key(s): $($extra -join ', ')"
    }

    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    Assert-True ($text -notmatch '[ÃÂ�]') "$code.ini contains mojibake marker text."
}

$fr = Get-BliplineLocalePack -Code 'fr'
$es = Get-BliplineLocalePack -Code 'es'
$de = Get-BliplineLocalePack -Code 'de'

Assert-True ($fr['Timeline']['AllDay'] -eq 'Toute la journée') 'French all-day label is wrong.'
Assert-True ($fr['Import']['ClipboardEmpty'] -like 'Le presse-papiers*') 'French clipboard-empty message is wrong.'
Assert-True ($es['Settings']['UiAddCalendars'] -eq 'Añadir calendarios') 'Spanish Add Calendars label is wrong.'
Assert-True ($de['Timeline']['AllDay'] -eq 'Ganztägig') 'German all-day label is wrong.'

Assert-True ((Resolve-BliplineLanguageCode -Code 'Français') -eq 'fr') 'French native language alias did not resolve.'
Assert-True ((Resolve-BliplineLanguageCode -Code 'Español') -eq 'es') 'Spanish native language alias did not resolve.'
Assert-True ((Resolve-BliplineLanguageCode -Code 'Deutsch') -eq 'de') 'German native language alias did not resolve.'

'Blipline localization tests passed.'
