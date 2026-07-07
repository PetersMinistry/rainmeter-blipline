param(
    [string]$SettingsPath,
    [string]$OutputPath,
    [switch]$UseExistingCache
)

$ErrorActionPreference = 'Stop'

# Ensure modern TLS protocols are enabled for network requests (fixes connection issues on older Windows machines)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072
} catch {}

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

$BliplineLocales = [ordered]@{
    en = @{
        Name = 'English'; Culture = 'en-US'; AllDay = 'All day'; Untitled = '(Untitled)'
        NoEvents = 'No events'; Ends = 'ENDS'; Next = 'NEXT'; Done = 'DONE'
        UnitMinute = 'min'; UnitMinuteSuffix = 'm'; UnitHour = 'hr'; UnitHourSuffix = 'h'; UnitDay = 'day'; UnitDayPlural = 'days'; UnitDaySuffix = 'd'; UnitJoiner = ''
        SampleData = 'Sample data'; DemoData = 'Demo data'; NoFeedsConfigured = 'No feeds configured'
        RefreshFailedSampleData = 'Refresh failed - sample data'
        UpdatedFeeds = 'Updated {0} feed(s)'; UpdatedFeedsFailed = 'Updated {0} feed(s), {1} failed'; ZeroUpdated = '0 of {0} feed(s) updated'
    }
    ru = @{
        Name = 'Russian'; Culture = 'en-US'; AllDay = 'Ves den'; Untitled = '(Bez nazvaniya)'
        NoEvents = 'Net sobytiy'; Ends = 'KONETS'; Next = 'DALEE'; Done = 'GOTOVO'
        UnitMinute = 'min'; UnitMinuteSuffix = 'm'; UnitHour = 'ch'; UnitHourSuffix = 'ch'; UnitDay = 'den'; UnitDayPlural = 'dney'; UnitDaySuffix = 'd'; UnitJoiner = 'space'
        SampleData = 'Primer dannyh'; DemoData = 'Demo'; NoFeedsConfigured = 'Lenty ne nastroeny'
        RefreshFailedSampleData = 'Sboy obnovleniya - primer'
        UpdatedFeeds = 'Obnovleno: {0}'; UpdatedFeedsFailed = 'Obnovleno: {0}, oshibok: {1}'; ZeroUpdated = 'Obnovleno 0 iz {0}'
    }
    es = @{
        Name = 'Spanish'; Culture = 'es-ES'; AllDay = 'Todo el día'; Untitled = '(Sin título)'
        NoEvents = 'Sin eventos'; Ends = 'FIN'; Next = 'SIGUE'; Done = 'HECHO'
        UnitMinute = 'min'; UnitMinuteSuffix = 'm'; UnitHour = 'h'; UnitHourSuffix = 'h'; UnitDay = 'día'; UnitDayPlural = 'días'; UnitDaySuffix = 'd'; UnitJoiner = 'space'
        SampleData = 'Datos de ejemplo'; DemoData = 'Demo'; NoFeedsConfigured = 'Sin fuentes'
        RefreshFailedSampleData = 'Error - datos de ejemplo'
        UpdatedFeeds = '{0} fuente(s) actualizada(s)'; UpdatedFeedsFailed = '{0} fuente(s) actualizada(s), {1} error'; ZeroUpdated = '0 de {0} fuente(s) actualizada(s)'
    }
    it = @{
        Name = 'Italian'; Culture = 'it-IT'; AllDay = 'Tutto il giorno'; Untitled = '(Senza titolo)'
        NoEvents = 'Nessun evento'; Ends = 'FINISCE'; Next = 'PROSSIMO'; Done = 'FATTO'
        UnitMinute = 'min'; UnitMinuteSuffix = 'm'; UnitHour = 'h'; UnitHourSuffix = 'h'; UnitDay = 'giorno'; UnitDayPlural = 'giorni'; UnitDaySuffix = 'g'; UnitJoiner = 'space'
        SampleData = 'Dati di esempio'; DemoData = 'Demo'; NoFeedsConfigured = 'Nessun feed'
        RefreshFailedSampleData = 'Errore - dati di esempio'
        UpdatedFeeds = '{0} feed aggiornati'; UpdatedFeedsFailed = '{0} feed aggiornati, {1} errori'; ZeroUpdated = '0 di {0} feed aggiornati'
    }
    fr = @{
        Name = 'French'; Culture = 'fr-FR'; AllDay = 'Toute la journée'; Untitled = '(Sans titre)'
        NoEvents = 'Aucun événement'; Ends = 'FIN'; Next = 'SUIVANT'; Done = 'TERMINÉ'
        UnitMinute = 'min'; UnitMinuteSuffix = 'm'; UnitHour = 'h'; UnitHourSuffix = 'h'; UnitDay = 'jour'; UnitDayPlural = 'jours'; UnitDaySuffix = 'j'; UnitJoiner = 'space'
        SampleData = 'Données de test'; DemoData = 'Démo'; NoFeedsConfigured = 'Aucun flux'
        RefreshFailedSampleData = 'Échec - données de test'
        UpdatedFeeds = '{0} flux actualisé(s)'; UpdatedFeedsFailed = '{0} flux actualisé(s), {1} échec(s)'; ZeroUpdated = '0 sur {0} flux actualisé(s)'
    }
    de = @{
        Name = 'German'; Culture = 'de-DE'; AllDay = 'Ganztägig'; Untitled = '(Ohne Titel)'
        NoEvents = 'Keine Ereignisse'; Ends = 'ENDET'; Next = 'NÄCHSTES'; Done = 'FERTIG'
        UnitMinute = 'Min'; UnitMinuteSuffix = 'm'; UnitHour = 'Std'; UnitHourSuffix = 'h'; UnitDay = 'Tag'; UnitDayPlural = 'Tage'; UnitDaySuffix = 'T'; UnitJoiner = 'space'
        SampleData = 'Beispieldaten'; DemoData = 'Demo'; NoFeedsConfigured = 'Keine Feeds eingerichtet'
        RefreshFailedSampleData = 'Aktualisierung fehlgeschlagen - Beispiel'
        UpdatedFeeds = '{0} Feed(s) aktualisiert'; UpdatedFeedsFailed = '{0} Feed(s) aktualisiert, {1} fehlgeschlagen'; ZeroUpdated = '0 von {0} Feed(s) aktualisiert'
    }
}

function Get-BliplineLocale {
    param([string]$Path)

    $code = (Get-SettingValue -Path $Path -Name 'Language' -Default 'en').Trim().ToLowerInvariant()
    $aliases = @{
        english = 'en'; russian = 'ru'; spanish = 'es'; italian = 'it'; french = 'fr'; german = 'de'
    }
    if ($aliases.ContainsKey($code)) {
        $code = $aliases[$code]
    }
    if (!$BliplineLocales.Contains($code)) {
        $code = 'en'
    }

    $locale = @{} + $BliplineLocales[$code]
    $locale['Code'] = $code
    return $locale
}

function Test-MojibakeText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return ($Text -match '[ÃÂ�]')
}

function Get-LocaleText {
    param(
        [hashtable]$Locale,
        [string]$Key
    )

    if ($Locale.ContainsKey($Key)) {
        return [string]$Locale[$Key]
    }

    return [string]$BliplineLocales['en'][$Key]
}

function Convert-StatusText {
    param(
        [string]$Status,
        [hashtable]$Locale
    )

    if ($Status -eq 'Sample data') { return Get-LocaleText -Locale $Locale -Key 'SampleData' }
    if ($Status -eq 'Demo data') { return Get-LocaleText -Locale $Locale -Key 'DemoData' }
    if ($Status -eq 'No feeds configured') { return Get-LocaleText -Locale $Locale -Key 'NoFeedsConfigured' }
    if ($Status -eq 'Refresh failed - sample data') { return Get-LocaleText -Locale $Locale -Key 'RefreshFailedSampleData' }
    if ($Status -match '^Updated (\d+) feed\(s\), (\d+) failed$') {
        return (Get-LocaleText -Locale $Locale -Key 'UpdatedFeedsFailed') -f [int]$matches[1], [int]$matches[2]
    }
    if ($Status -match '^Updated (\d+) feed\(s\)$') {
        return (Get-LocaleText -Locale $Locale -Key 'UpdatedFeeds') -f [int]$matches[1]
    }
    if ($Status -match '^0 of (\d+) feed\(s\) updated$') {
        return (Get-LocaleText -Locale $Locale -Key 'ZeroUpdated') -f [int]$matches[1]
    }

    return Convert-DisplayText $Status
}

function Format-LocalizedDateLabel {
    param(
        [DateTime]$Date,
        [hashtable]$Locale
    )

    try {
        $culture = [Globalization.CultureInfo]::GetCultureInfo([string]$Locale['Culture'])
        return (Convert-RainmeterText ($Date.ToString('ddd  dd MMM', $culture).ToUpper($culture)))
    }
    catch {
        return $Date.ToString('ddd  dd MMM').ToUpperInvariant()
    }
}


function Get-SettingValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Default = ''
    )

    if (!(Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $pattern = '^\s*' + [regex]::Escape($Name) + '\s*=\s*(.*)$'
    $settingsEncoding = Get-RainmeterIncludeEncoding
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $settingsEncoding)) {
        if ($line -match $pattern) {
            return $matches[1].Trim()
        }
    }

    return $Default
}

function Set-SettingValue {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Value
    )

    $escaped = [regex]::Escape($Name)
    $pattern = "^$escaped="
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

function Save-FeedStatus {
    param(
        [string]$Path,
        [object[]]$Statuses,
        [int]$MaxFeeds,
        [string]$Summary
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path -LiteralPath $Path)) {
        return
    }

    $settingsEncoding = Get-RainmeterIncludeEncoding
    $lines = @([System.IO.File]::ReadAllLines($Path, $settingsEncoding))
    $lines = @(Set-SettingValue -Lines $lines -Name 'FeedStatusSummary' -Value (($Summary -replace '[\r\n=]', ' ').Trim()))

    for ($i = 1; $i -le $MaxFeeds; $i++) {
        $status = @($Statuses | Where-Object { $_.Index -eq $i } | Select-Object -First 1)
        $name = ''
        $result = ''
        $count = ''
        $color = '255,255,255,0'

        if ($status.Count -gt 0) {
            $name = Convert-DisplayText $status[0].Name
            $result = Convert-DisplayText $status[0].Result
            $count = [string]$status[0].Count
            $color = if ($status[0].Color) { $status[0].Color } else { '205,214,224,230' }
        }

        $lines = @(Set-SettingValue -Lines $lines -Name "Feed${i}Name" -Value $name)
        $lines = @(Set-SettingValue -Lines $lines -Name "Feed${i}Result" -Value $result)
        $lines = @(Set-SettingValue -Lines $lines -Name "Feed${i}Count" -Value $count)
        $lines = @(Set-SettingValue -Lines $lines -Name "Feed${i}Color" -Value $color)
    }

    # Rainmeter @Include files must stay BOM-free or variables can render literally.
    [System.IO.File]::WriteAllLines($Path, $lines, $settingsEncoding)
}

function Convert-IcsText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }

    return $Text.Replace('\n', ' ').Replace('\N', ' ').Replace('\,', ',').Replace('\;', ';').Replace('\\', '\').Trim()
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

function Convert-RainmeterText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $clean = $Text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''
    $clean = Remove-RainmeterUnsafeUnicode $clean

    return (($clean -replace '\s+', ' ').Trim() -replace '[\r\n=]', ' ')
}

function Convert-SafeInlineText {
    param(
        [string]$Text,
        [bool]$UseEmojiWords = $false
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $clean = $Text
    if ($UseEmojiWords) {
        $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F37D), ' Meal ')
        $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F304), ' Sunrise ')
        $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F4D6), ' Book ')
        $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F382), ' B-day ')
    }

    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F37D), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F304), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F4D6), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F338), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F382), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F98B), ' ')
    $clean = $clean.Replace([char]::ConvertFromUtf32(0x1F56F), ' ')
    $clean = $clean.Replace(([char]0x2615).ToString(), ' ')
    $clean = $clean.Replace(([char]0x271D).ToString(), ' ')
    $clean = $clean.Replace(([char]0x27A1).ToString(), ' ')
    $clean = $clean.Replace(([char]0x2694).ToString(), ' ')
    $clean = $clean.Replace(([char]0x2026).ToString(), '...')
    $clean = $clean.Replace(([char]0x2022).ToString(), '-')
    $clean = $clean.Replace(([char]0x2018).ToString(), "'")
    $clean = $clean.Replace(([char]0x2019).ToString(), "'")
    $clean = $clean.Replace(([char]0x201C).ToString(), '"')
    $clean = $clean.Replace(([char]0x201D).ToString(), '"')
    $clean = $clean.Replace(([char]0x2013).ToString(), '-')
    $clean = $clean.Replace(([char]0x2014).ToString(), '-')
    $clean = $clean -replace '[\u200D\uFE0E\uFE0F]', ''
    $clean = $clean -replace '[\u2600-\u27BF]', ' '
    $clean = $clean -replace '[\uD800-\uDFFF]', ''

    return Convert-RainmeterText $clean
}

function Convert-DisplayText {
    param([string]$Text)

    $clean = Convert-IcsText $Text
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return ''
    }
    $clean = [System.Net.WebUtility]::HtmlDecode($clean)
    $clean = $clean -replace '<[^>]+>', ' '

    return Convert-SafeInlineText -Text $clean -UseEmojiWords:$true
}

function Get-EventIcon {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    if ($Text.Contains([char]::ConvertFromUtf32(0x1F37D))) { return 'MEAL' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F304))) { return 'SUN' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F31F))) { return 'SUN' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F4D6))) { return 'BOOK' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F338))) { return 'LADY' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F382))) { return 'BDAY' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F389))) { return 'BDAY' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F98B))) { return 'BUTTERFLY' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F56F))) { return 'CANDLE' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F90D))) { return 'LADY' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F4AA))) { return 'IRON' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F4C5))) { return 'MARKER' }
    if ($Text.Contains([char]::ConvertFromUtf32(0x1F4C6))) { return 'MARKER' }
    if ($Text.Contains(([char]0x2728).ToString())) { return 'SUN' }
    if ($Text.Contains(([char]0x2B50).ToString())) { return 'SUN' }
    if ($Text.Contains(([char]0x2764).ToString())) { return 'LADY' }
    if ($Text.Contains(([char]0x2665).ToString())) { return 'LADY' }
    if ($Text.Contains(([char]0x2705).ToString())) { return 'MARKER' }
    if ($Text.Contains(([char]0x2714).ToString())) { return 'MARKER' }
    if ($Text.Contains(([char]0x271D).ToString())) { return '+' }
    if ($Text.Contains(([char]0x2694).ToString())) { return 'IRON' }
    if ($Text -match '(?i)\bbible\b') { return 'BOOK' }
    if ($Text -match '(?i)\bbreakfast|lunch|dinner|meal\b') { return 'MEAL' }
    if ($Text -match '(?i)\bbirthday|b-day|bday\b') { return 'BDAY' }

    return ''
}

function Convert-TitleText {
    param([string]$Text)

    $clean = Convert-IcsText $Text
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return ''
    }
    $clean = [System.Net.WebUtility]::HtmlDecode($clean)
    $clean = $clean -replace '<[^>]+>', ' '

    return ((Convert-SafeInlineText -Text $clean) -replace '^\s*[-|>]+\s*', '')
}

function Convert-HexColorToRainmeter {
    param([string]$Color)

    if ([string]::IsNullOrWhiteSpace($Color)) {
        return ''
    }

    $clean = $Color.Trim()
    if ($clean -match '^#?([0-9A-Fa-f]{6})$') {
        $hex = $matches[1]
        $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
        $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
        $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
        return "$r,$g,$b,255"
    }

    return ''
}

function Convert-BytesToText {
    param([byte[]]$Bytes)

    if ($null -eq $Bytes -or $Bytes.Count -eq 0) {
        return ''
    }

    if ($Bytes.Count -ge 3 -and $Bytes[0] -eq 239 -and $Bytes[1] -eq 187 -and $Bytes[2] -eq 191) {
        return [Text.Encoding]::UTF8.GetString($Bytes, 3, $Bytes.Count - 3)
    }

    return [Text.Encoding]::UTF8.GetString($Bytes)
}

function Convert-IcsDate {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $clean = $Value.Trim()
    $culture = [Globalization.CultureInfo]::InvariantCulture

    if ($clean -match '^\d{8}$') {
        return [datetime]::ParseExact($clean, 'yyyyMMdd', $culture)
    }

    if ($clean -match '^\d{8}T\d{6}Z$') {
        return ([datetime]::ParseExact($clean, "yyyyMMdd'T'HHmmss'Z'", $culture, [Globalization.DateTimeStyles]::AssumeUniversal)).ToLocalTime()
    }

    if ($clean -match '^\d{8}T\d{6}$') {
        return [datetime]::ParseExact($clean, "yyyyMMdd'T'HHmmss", $culture)
    }

    return $null
}

function Get-IcsRuleMap {
    param([string]$RuleText)

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($RuleText)) {
        return $map
    }

    foreach ($part in ($RuleText -split ';')) {
        if ($part -match '^([^=]+)=(.*)$') {
            $map[$matches[1].ToUpperInvariant()] = $matches[2]
        }
    }

    return $map
}

function Test-IcsDayMatch {
    param(
        [datetime]$Date,
        [string]$ByDay
    )

    if ([string]::IsNullOrWhiteSpace($ByDay)) {
        return $true
    }

    $dayMap = @{
        SU = [DayOfWeek]::Sunday
        MO = [DayOfWeek]::Monday
        TU = [DayOfWeek]::Tuesday
        WE = [DayOfWeek]::Wednesday
        TH = [DayOfWeek]::Thursday
        FR = [DayOfWeek]::Friday
        SA = [DayOfWeek]::Saturday
    }

    foreach ($day in ($ByDay -split ',')) {
        $clean = ($day -replace '^[+-]?\d+', '').ToUpperInvariant()
        if ($dayMap.ContainsKey($clean) -and $Date.DayOfWeek -eq $dayMap[$clean]) {
            return $true
        }
    }

    return $false
}

function Get-MonthlyByDayDate {
    param(
        [int]$Year,
        [int]$Month,
        [string]$ByDay
    )

    if ([string]::IsNullOrWhiteSpace($ByDay)) {
        return $null
    }

    $dayMap = @{
        SU = [DayOfWeek]::Sunday
        MO = [DayOfWeek]::Monday
        TU = [DayOfWeek]::Tuesday
        WE = [DayOfWeek]::Wednesday
        TH = [DayOfWeek]::Thursday
        FR = [DayOfWeek]::Friday
        SA = [DayOfWeek]::Saturday
    }

    # Parse BYDAY ordinal and day code: "3SA" => ordinal=3, dayCode=SA
    #                                        "-1MO" => ordinal=-1, dayCode=MO
    #                                        "SA" => ordinal=0, dayCode=SA
    $ordinal = 0
    $dayCode = $ByDay.Trim().ToUpperInvariant()
    if ($dayCode -match '^([+-]?\d+)([A-Z]{2})$') {
        $ordinal = [int]$matches[1]
        $dayCode = $matches[2]
    }

    if (!$dayMap.ContainsKey($dayCode)) {
        return $null
    }

    $targetDay = $dayMap[$dayCode]
    $daysInMonth = [DateTime]::DaysInMonth($Year, $Month)
    $firstOfMonth = Get-Date -Year $Year -Month $Month -Day 1

    if ($ordinal -gt 0) {
        # Nth occurrence from start (e.g., 3SA = 3rd Saturday)
        $firstOccurrence = $firstOfMonth.AddDays(([int]$targetDay - [int]$firstOfMonth.DayOfWeek + 7) % 7)
        $result = $firstOccurrence.AddDays(7 * ($ordinal - 1))
        if ($result.Month -ne $Month) {
            return $null  # Ordinal exceeds available occurrences this month
        }
        return $result
    }
    elseif ($ordinal -lt 0) {
        # Nth-from-last occurrence (e.g., -1MO = last Monday, -2MO = 2nd-to-last)
        $lastOfMonth = Get-Date -Year $Year -Month $Month -Day $daysInMonth
        $offset = ([int]$lastOfMonth.DayOfWeek - [int]$targetDay + 7) % 7
        $lastOccurrence = $lastOfMonth.AddDays(-$offset)
        $result = $lastOccurrence.AddDays(7 * ($ordinal + 1))
        if ($result.Month -ne $Month) {
            return $null  # Ordinal exceeds available occurrences this month
        }
        return $result
    }
    else {
        # No ordinal prefix — not meaningful for MONTHLY; fall back
        return $null
    }
}

function Get-IcsWeekStartDate {
    param(
        [datetime]$Date,
        [string]$WeekStart
    )

    $dayMap = @{
        SU = [DayOfWeek]::Sunday
        MO = [DayOfWeek]::Monday
        TU = [DayOfWeek]::Tuesday
        WE = [DayOfWeek]::Wednesday
        TH = [DayOfWeek]::Thursday
        FR = [DayOfWeek]::Friday
        SA = [DayOfWeek]::Saturday
    }

    $startDay = [DayOfWeek]::Monday
    $clean = if ($WeekStart) { $WeekStart.ToUpperInvariant() } else { '' }
    if ($dayMap.ContainsKey($clean)) {
        $startDay = $dayMap[$clean]
    }

    $offset = ([int]$Date.DayOfWeek - [int]$startDay + 7) % 7
    return $Date.Date.AddDays(-$offset)
}

function New-ShiftedEvent {
    param(
        [object]$Event,
        [datetime]$Start
    )

    $duration = $Event.End - $Event.Start
    New-EventObject -Start $Start -End $Start.Add($duration) -Title $Event.Title -Location $Event.Location -Notes $Event.Notes -AllDay:$Event.AllDay -Color $Event.Color -Calendar $Event.Calendar -Icon $Event.Icon
}

function Expand-IcsEvent {
    param(
        [object]$Event,
        [string]$RuleText,
        [object[]]$ExDates,
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    if ([string]::IsNullOrWhiteSpace($RuleText)) {
        return @($Event)
    }

    $rule = Get-IcsRuleMap -RuleText $RuleText
    $freq = ''
    if ($rule.ContainsKey('FREQ')) {
        $freq = $rule['FREQ'].ToUpperInvariant()
    }
    if ($freq -notin @('DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY')) {
        return @($Event)
    }

    $interval = 1
    if ($rule.ContainsKey('INTERVAL')) {
        $interval = [Math]::Max(1, [int]$rule['INTERVAL'])
    }

    $countLimit = if ($rule.ContainsKey('COUNT')) { [int]$rule['COUNT'] } else { 0 }
    $until = if ($rule.ContainsKey('UNTIL')) { Convert-IcsDate $rule['UNTIL'] } else { $null }
    $byDay = if ($rule.ContainsKey('BYDAY')) { $rule['BYDAY'] } else { '' }
    $weekStart = if ($rule.ContainsKey('WKST')) { $rule['WKST'] } else { 'MO' }
    $baseWeekStart = Get-IcsWeekStartDate -Date $Event.Start -WeekStart $weekStart
    $exKeys = @{}
    foreach ($exDate in @($ExDates)) {
        if ($exDate) {
            $exKeys[$exDate.ToString('yyyyMMddHHmmss')] = $true
        }
    }

    $expanded = New-Object System.Collections.Generic.List[object]
    $candidate = $Event.Start
    $generated = 0
    $guard = 0
    $maxWindow = $WindowEnd.AddDays(1)

    while ($candidate -lt $maxWindow -and $guard -lt 1000) {
        $guard++
        $include = $true
        if ($until -and $candidate -gt $until) { break }
        if ($countLimit -gt 0 -and $generated -ge $countLimit) { break }

        if ($freq -eq 'WEEKLY' -and -not (Test-IcsDayMatch -Date $candidate -ByDay $byDay)) {
            $include = $false
        }
        elseif ($freq -eq 'WEEKLY' -and ![string]::IsNullOrWhiteSpace($byDay)) {
            $candidateWeekStart = Get-IcsWeekStartDate -Date $candidate -WeekStart $weekStart
            $weekOffset = [int][Math]::Floor((New-TimeSpan -Start $baseWeekStart -End $candidateWeekStart).TotalDays / 7)
            if ($weekOffset -lt 0 -or ($weekOffset % $interval) -ne 0) {
                $include = $false
            }
        }

        if ($include) {
            $generated++
            $shifted = New-ShiftedEvent -Event $Event -Start $candidate
            $key = $candidate.ToString('yyyyMMddHHmmss')
            if ($shifted.End -ge $WindowStart -and $shifted.Start -lt $WindowEnd -and -not $exKeys.ContainsKey($key)) {
                $expanded.Add($shifted)
            }
        }

        if ($freq -eq 'DAILY') {
            $candidate = $candidate.AddDays($interval)
        }
        elseif ($freq -eq 'WEEKLY') {
            if ([string]::IsNullOrWhiteSpace($byDay)) {
                $candidate = $candidate.AddDays(7 * $interval)
            }
            else {
                $candidate = $candidate.AddDays(1)
            }
        }
        elseif ($freq -eq 'MONTHLY') {
            do {
                $candidate = $candidate.AddMonths($interval)
                $byDayValid = $true
                if (![string]::IsNullOrWhiteSpace($byDay)) {
                    $adjusted = Get-MonthlyByDayDate -Year $candidate.Year -Month $candidate.Month -ByDay $byDay
                    if ($adjusted) {
                        $candidate = Get-Date -Year $adjusted.Year -Month $adjusted.Month -Day $adjusted.Day `
                            -Hour $candidate.Hour -Minute $candidate.Minute -Second $candidate.Second
                    }
                    else {
                        $byDayValid = $false
                    }
                }
            } while (!$byDayValid -and $guard -lt 1000)
        }
        elseif ($freq -eq 'YEARLY') {
            $candidate = $candidate.AddYears($interval)
        }
    }

    return $expanded.ToArray()
}

function Get-UnixSeconds {
    param([datetime]$Date)
    return ([DateTimeOffset]$Date).ToUnixTimeSeconds()
}

function New-EventObject {
    param(
        [datetime]$Start,
        [datetime]$End,
        [string]$Title,
        [string]$Location,
        [string]$Notes,
        [bool]$AllDay,
        [string]$Color,
        [string]$Calendar,
        [string]$Icon = ''
    )

    [pscustomobject]@{
        Start = $Start
        End = $End
        Title = $Title
        Location = $Location
        Notes = $Notes
        AllDay = $AllDay
        Color = $Color
        Calendar = $Calendar
        Icon = $Icon
    }
}

function Expand-DisplayEvent {
    param(
        [object]$Event,
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    if (!$Event.AllDay -or $Event.End.Date -le $Event.Start.Date.AddDays(1)) {
        return @($Event)
    }

    $expanded = New-Object System.Collections.Generic.List[object]
    $cursor = $Event.Start.Date
    $endDate = $Event.End.Date

    while ($cursor -lt $endDate) {
        $sliceStart = $cursor
        $sliceEnd = $cursor.AddDays(1)
        if ($sliceEnd -ge $WindowStart -and $sliceStart -lt $WindowEnd) {
            $expanded.Add((New-EventObject -Start $sliceStart -End $sliceEnd -Title $Event.Title -Location $Event.Location -Notes $Event.Notes -AllDay:$true -Color $Event.Color -Calendar $Event.Calendar -Icon $Event.Icon))
        }
        $cursor = $cursor.AddDays(1)
    }

    return $expanded.ToArray()
}

function Get-SampleEvents {
    $now = Get-Date
    $base = Get-Date -Hour $now.Hour -Minute 0 -Second 0
    $next = $now.AddMinutes(15)

    @(
        New-EventObject -Start $base.AddHours(-2) -End $base.AddHours(-1).AddMinutes(-15) -Title 'Morning Focus' -Location '' -Notes '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start $base.AddHours(-1) -End $base.AddMinutes(-15) -Title 'Deep Work' -Location '' -Notes '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start $next -End $next.AddMinutes(45) -Title '✝ Team Sync' -Location 'Conference Room A' -Notes 'Bring the weekly notes.' -AllDay:$false -Color '255,199,50,255' -Calendar 'Work'
        New-EventObject -Start $next.AddHours(1.5) -End $next.AddHours(2.25) -Title 'Lunch' -Location '' -Notes '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Personal'
        New-EventObject -Start $next.AddHours(3) -End $next.AddHours(4) -Title '📖 Design Review' -Location 'Studio call' -Notes 'Review the visual pass.' -AllDay:$false -Color '104,170,255,245' -Calendar 'Work'
        New-EventObject -Start $next.AddHours(5) -End $next.AddHours(5.5) -Title 'Client Call' -Location '' -Notes '' -AllDay:$false -Color '126,220,117,245' -Calendar 'Clients'
        New-EventObject -Start $next.AddHours(7.5) -End $next.AddHours(8) -Title 'Wrap Up' -Location '' -Notes '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start (Get-Date).Date.AddDays(1).AddHours(9) -End (Get-Date).Date.AddDays(1).AddHours(10) -Title 'Tomorrow Planning' -Location '' -Notes '' -AllDay:$false -Color '238,120,150,245' -Calendar 'Planning'
        New-EventObject -Start (Get-Date).Date.AddDays(1).AddHours(14) -End (Get-Date).Date.AddDays(1).AddHours(14).AddMinutes(45) -Title 'Follow-up Window' -Location '' -Notes '' -AllDay:$false -Color '104,170,255,245' -Calendar 'Planning'
    )
}

function Parse-IcsEvents {
    param(
        [string]$Content,
        [string]$CalendarName,
        [string]$Color,
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    $unfolded = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Content -split "`r?`n")) {
        if (($line.StartsWith(' ') -or $line.StartsWith("`t")) -and $unfolded.Count -gt 0) {
            $unfolded[$unfolded.Count - 1] = $unfolded[$unfolded.Count - 1] + $line.Substring(1)
        }
        else {
            $unfolded.Add($line)
        }
    }

    $events = New-Object System.Collections.Generic.List[object]
    $rawEvents = New-Object System.Collections.Generic.List[object]
    $inEvent = $false
    $current = @{}

    foreach ($line in $unfolded) {
        if ($line -eq 'BEGIN:VEVENT') {
            $inEvent = $true
            $current = @{}
            continue
        }

        if ($line -eq 'END:VEVENT') {
            $inEvent = $false
            $rawEvents.Add($current.Clone())
            continue
        }

        if (!$inEvent) { continue }
        if ($line -notmatch '^([^:]+):(.*)$') { continue }

        $rawName = $matches[1]
        $value = $matches[2]
        $name = ($rawName -split ';')[0].ToUpperInvariant()

        if ($name -eq 'DTSTART') {
            $current['DTSTART'] = $value
            if ($rawName -match 'VALUE=DATE') { $current['DTSTART_ALLDAY'] = '1' }
        }
        elseif ($name -eq 'DTEND') {
            $current['DTEND'] = $value
        }
        elseif ($name -eq 'SUMMARY' -or $name -eq 'LOCATION' -or $name -eq 'DESCRIPTION') {
            $current[$name] = $value
        }
        elseif ($name -eq 'UID' -or $name -eq 'RECURRENCE-ID') {
            $current[$name] = $value
        }
        elseif ($name -eq 'STATUS' -or $name -eq 'RRULE') {
            $current[$name] = $value
        }
        elseif ($name -eq 'EXDATE') {
            $dates = @()
            foreach ($dateValue in ($value -split ',')) {
                $date = Convert-IcsDate $dateValue
                if ($date) { $dates += $date }
            }
            $current['EXDATE'] = @($current['EXDATE']) + $dates
        }
    }

    $overrideDatesByUid = @{}
    foreach ($item in $rawEvents) {
        if (!$item.ContainsKey('UID') -or !$item.ContainsKey('RECURRENCE-ID')) {
            continue
        }

        $uid = $item['UID']
        $recurrenceDate = Convert-IcsDate $item['RECURRENCE-ID']
        if ([string]::IsNullOrWhiteSpace($uid) -or !$recurrenceDate) {
            continue
        }

        if (!$overrideDatesByUid.ContainsKey($uid)) {
            $overrideDatesByUid[$uid] = @()
        }
        $overrideDatesByUid[$uid] = @($overrideDatesByUid[$uid] + $recurrenceDate)
    }

    foreach ($current in $rawEvents) {
        $status = ''
        if ($current.ContainsKey('STATUS')) {
            $status = $current['STATUS'].ToUpperInvariant()
        }
        if ($status -eq 'CANCELLED') {
            continue
        }

        $start = Convert-IcsDate $current['DTSTART']
        $end = Convert-IcsDate $current['DTEND']
        if (!$start) {
            continue
        }

        $allDay = $current['DTSTART_ALLDAY'] -eq '1'
        if (!$end) {
            $end = if ($allDay) { $start.AddDays(1) } else { $start.AddMinutes(30) }
        }
        $rawTitle = $current['SUMMARY']
        $icon = Get-EventIcon $rawTitle
        $title = Convert-IcsText $rawTitle
        if (!$title) { $title = 'Calendar event' }

        $hasRecurrenceId = $current.ContainsKey('RECURRENCE-ID') -and ![string]::IsNullOrWhiteSpace($current['RECURRENCE-ID'])
        if (!$hasRecurrenceId -and $title -match '^(?i:cancelled|canceled)\b') {
            continue
        }

        $location = Convert-IcsText $current['LOCATION']
        $notes = Convert-IcsText $current['DESCRIPTION']
        $baseEvent = New-EventObject -Start $start -End $end -Title $title -Location $location -Notes $notes -AllDay:$allDay -Color $Color -Calendar $CalendarName -Icon $icon

        if ($hasRecurrenceId) {
            if ($baseEvent.End -ge $WindowStart -and $baseEvent.Start -lt $WindowEnd) {
                foreach ($event in (Expand-DisplayEvent -Event $baseEvent -WindowStart $WindowStart -WindowEnd $WindowEnd)) {
                    $events.Add($event)
                }
            }
            continue
        }

        $exDates = @($current['EXDATE'])
        if ($current.ContainsKey('UID') -and $overrideDatesByUid.ContainsKey($current['UID'])) {
            $exDates += @($overrideDatesByUid[$current['UID']])
        }

        foreach ($event in (Expand-IcsEvent -Event $baseEvent -RuleText $current['RRULE'] -ExDates $exDates -WindowStart $WindowStart -WindowEnd $WindowEnd)) {
            foreach ($displayEvent in (Expand-DisplayEvent -Event $event -WindowStart $WindowStart -WindowEnd $WindowEnd)) {
                $events.Add($displayEvent)
            }
        }
    }

    return $events.ToArray()
}

function Get-IcsCalendarName {
    param([string]$Content)

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match '^X-WR-CALNAME:(.*)$') {
            $name = Convert-IcsText $matches[1]
            if (![string]::IsNullOrWhiteSpace($name)) {
                return $name
            }
        }
    }

    return ''
}

function Get-IcsCalendarColor {
    param([string]$Content)

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match '^(?:COLOR|X-APPLE-CALENDAR-COLOR|X-WR-CALCOLOR):(.*)$') {
            $color = Convert-HexColorToRainmeter $matches[1]
            if (![string]::IsNullOrWhiteSpace($color)) {
                return $color
            }
        }
    }

    return ''
}

function Get-CalendarFeeds {
    param([string]$Path)

    $feeds = @()
    $maxFeeds = [int](Get-SettingValue -Path $Path -Name 'CalendarSlots' -Default '8')
    $maxFeeds = [Math]::Max(3, [Math]::Min(15, $maxFeeds))
    $defaultColors = @(
        '255,199,50,255',
        '104,170,255,245',
        '126,220,117,245',
        '238,120,150,245',
        '155,111,225,245',
        '24,163,214,245',
        '224,72,72,245',
        '234,191,48,245',
        '118,118,118,245',
        '255,132,64,245',
        '92,214,168,245',
        '255,108,180,245',
        '130,204,255,245',
        '186,220,88,245',
        '200,156,255,245',
        '205,214,224,230',
        '255,255,255,245',
        '230,147,139,245',
        '176,150,136,245',
        '255,176,96,245',
        '90,220,220,245',
        '128,144,255,245',
        '168,235,140,245',
        '255,214,120,245',
        '172,172,172,245'
    )

    for ($i = 1; $i -le $maxFeeds; $i++) {
        $urlKey = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
        $url = Get-SettingValue -Path $Path -Name $urlKey
        if ($i -eq 1 -and [string]::IsNullOrWhiteSpace($url)) {
            $url = Get-SettingValue -Path $Path -Name 'CalendarUrl1'
        }
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        $defaultColor = $defaultColors[($i - 1) % $defaultColors.Count]

        $feeds += [pscustomobject]@{
            Index = $i
            Url = $url
            Name = Get-SettingValue -Path $Path -Name "CalendarName$i"
            FallbackName = "Calendar $i"
            Color = Get-SettingValue -Path $Path -Name "CalendarColor$i" -Default $defaultColor
        }
    }

    return $feeds
}

function Get-CalendarContent {
    param([string]$Source)

    if (Test-Path -LiteralPath $Source) {
        return Get-Content -LiteralPath $Source -Raw -Encoding UTF8
    }

    try {
        $client = New-Object System.Net.WebClient
        $client.Headers.Add('User-Agent', 'Blipline/0.3')
        $client.Headers.Add('Accept', 'text/calendar,text/plain,*/*')
        return Convert-BytesToText ($client.DownloadData($Source))
    }
    catch {
        try {
            Add-Type -AssemblyName System.Net.Http
            $client = New-Object System.Net.Http.HttpClient
            $client.Timeout = [TimeSpan]::FromSeconds(25)
            $client.DefaultRequestHeaders.UserAgent.ParseAdd('Blipline/0.3')
            return $client.GetStringAsync($Source).GetAwaiter().GetResult()
        }
        catch {
            $helperPath = Get-SettingValue -Path $SettingsPath -Name 'FetchHelperPath'
            if ([string]::IsNullOrWhiteSpace($helperPath) -or !(Test-Path -LiteralPath $helperPath)) {
                throw
            }

            $tempScript = Join-Path $env:TEMP ('BliplineFetch-' + [guid]::NewGuid().ToString('N') + '.py')
            $tempFile = Join-Path $env:TEMP ('BliplineFeed-' + [guid]::NewGuid().ToString('N') + '.ics')
            Set-Content -LiteralPath $tempScript -Encoding UTF8 -Value @'
import sys
import urllib.request

url = sys.argv[1]
out_file = sys.argv[2]
request = urllib.request.Request(
    url,
    headers={
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Blipline/0.3",
        "Accept": "text/calendar,text/plain,*/*",
    },
)
with urllib.request.urlopen(request, timeout=25) as response:
    data = response.read()
with open(out_file, "wb") as handle:
    handle.write(data)
'@
            try {
                & $helperPath $tempScript $Source $tempFile
                if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $tempFile)) {
                    throw 'Fetch helper failed'
                }
                return Get-Content -LiteralPath $tempFile -Raw -Encoding UTF8
            }
            finally {
                Remove-Item -LiteralPath $tempScript -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Test-AgendaCacheExists {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        return $false
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^EventCount=([1-9][0-9]*)') {
            return $true
        }
    }

    return $false
}

function Read-AgendaCache {
    param([string]$Path)

    $vars = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^([^=]+)=(.*)$') {
            $vars[$matches[1]] = $matches[2]
        }
    }

    function Get-CacheValue {
        param(
            [hashtable]$Vars,
            [string]$Name,
            [string]$Default = ''
        )

        if ($Vars.ContainsKey($Name)) {
            return [string]$Vars[$Name]
        }

        return $Default
    }

    $events = @()
    $count = [int](Get-CacheValue -Vars $vars -Name 'EventCount' -Default '0')
    for ($i = 1; $i -le $count; $i++) {
        $startEpoch = [int64](Get-CacheValue -Vars $vars -Name "Event${i}StartEpoch" -Default '0')
        $endEpoch = [int64](Get-CacheValue -Vars $vars -Name "Event${i}EndEpoch" -Default '0')
        if ($startEpoch -le 0 -or $endEpoch -le 0) {
            continue
        }

        $events += New-EventObject `
            -Start ([DateTimeOffset]::FromUnixTimeSeconds($startEpoch).LocalDateTime) `
            -End ([DateTimeOffset]::FromUnixTimeSeconds($endEpoch).LocalDateTime) `
            -Title (Get-CacheValue -Vars $vars -Name "Event${i}Title") `
            -Location (Get-CacheValue -Vars $vars -Name "Event${i}Location") `
            -Notes (Get-CacheValue -Vars $vars -Name "Event${i}Notes") `
            -AllDay ((Get-CacheValue -Vars $vars -Name "Event${i}AllDay" -Default '0') -eq '1') `
            -Color (Get-CacheValue -Vars $vars -Name "Event${i}Color" -Default '205,214,224,230') `
            -Calendar (Get-CacheValue -Vars $vars -Name "Event${i}Calendar") `
            -Icon (Get-CacheValue -Vars $vars -Name "Event${i}Icon")
    }

    return @{
        Events = $events
        Status = (Get-CacheValue -Vars $vars -Name 'SourceStatus')
    }
}

function Write-AgendaCache {
    param(
        [object[]]$Events,
        [string]$Path,
        [string]$Status
    )

    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $now = Get-Date
    $today = $now.Date
    $maxRows = [int](Get-SettingValue -Path $SettingsPath -Name 'MaxRows' -Default '6')
    $minRows = [Math]::Max(1, $maxRows)
    $cacheLimit = [int](Get-SettingValue -Path $SettingsPath -Name 'CacheLimit' -Default '120')
    $cacheLimit = [Math]::Max($minRows, $cacheLimit)
    $configuredFeedCount = @(Get-CalendarFeeds -Path $SettingsPath).Count
    $cacheScale = [Math]::Max(1, [Math]::Ceiling([Math]::Max(1, $configuredFeedCount) / 5))
    $effectiveCacheLimit = [Math]::Min($cacheLimit * $cacheScale, [Math]::Max($cacheLimit, 360))
    $pastDays = [int](Get-SettingValue -Path $SettingsPath -Name 'CachePastDays' -Default '14')
    $futureDays = [int](Get-SettingValue -Path $SettingsPath -Name 'CacheFutureDays' -Default '90')
    $perCalendarMinimum = [int](Get-SettingValue -Path $SettingsPath -Name 'CachePerCalendarMinimum' -Default '24')
    $perCalendarMinimum = [Math]::Max(0, [Math]::Min(120, $perCalendarMinimum))
    $windowStart = $today.AddDays(-[Math]::Max(0, $pastDays))
    $windowEnd = $today.AddDays([Math]::Max(1, $futureDays))
    $sorted = @(
        $Events |
            Where-Object { $_.End -ge $windowStart -and $_.Start -lt $windowEnd } |
            Sort-Object `
                @{ Expression = { $_.Start.Date } },
                @{ Expression = { $_.AllDay } },
                @{ Expression = { $_.Start } },
                @{ Expression = { $_.Calendar } },
                @{ Expression = { $_.Title } }
    )
    $past = @($sorted | Where-Object { $_.End -lt $now })
    $future = @($sorted | Where-Object { $_.End -ge $now })
    $pastLimit = [Math]::Min($past.Count, [Math]::Max($maxRows, [Math]::Floor($effectiveCacheLimit * 0.25)))
    $futureLimit = [Math]::Max($maxRows, $effectiveCacheLimit - $pastLimit)
    $timelineEvents = @()
    if ($pastLimit -gt 0) {
        $timelineEvents += @($past | Select-Object -Last $pastLimit)
    }
    $timelineEvents += @($future | Select-Object -First $futureLimit)
    if ($perCalendarMinimum -gt 0) {
        foreach ($group in ($sorted | Group-Object Calendar)) {
            $calendarPast = @($group.Group | Where-Object { $_.End -lt $now } | Select-Object -Last ([Math]::Min($maxRows, $perCalendarMinimum)))
            $calendarFuture = @($group.Group | Where-Object { $_.End -ge $now } | Select-Object -First $perCalendarMinimum)
            $timelineEvents += @($calendarPast + $calendarFuture)
        }
    }

    $filtered = @()
    $seen = @{}

    foreach ($event in $timelineEvents) {
        $key = '{0}|{1}|{2}' -f (Get-UnixSeconds $event.Start), $event.Title, $event.Calendar
        if ($seen.ContainsKey($key)) {
            continue
        }

        $seen[$key] = $true
        $filtered = @($filtered + $event)

        if ($filtered.Count -ge $effectiveCacheLimit) {
            break
        }
    }

    $filtered = @(
        $filtered |
            Sort-Object `
                @{ Expression = { $_.Start.Date } },
                @{ Expression = { $_.AllDay } },
                @{ Expression = { $_.Start } },
                @{ Expression = { $_.Calendar } },
                @{ Expression = { $_.Title } } |
            Select-Object -First $effectiveCacheLimit
    )

    $locale = Get-BliplineLocale -Path $SettingsPath
    $timeFormatSetting = (Get-SettingValue -Path $SettingsPath -Name 'TimeFormat' -Default '12').Trim()
    $timePattern = if ($timeFormatSetting -match '(?i)^(24|24h|hh:mm|h24|true|1)$') { 'HH:mm' } else { 'h:mm tt' }
    $allDayDefault = Get-LocaleText -Locale $locale -Key 'AllDay'
    $allDaySetting = Get-SettingValue -Path $SettingsPath -Name 'AllDayLabel' -Default ''
    if ([string]::IsNullOrWhiteSpace($allDaySetting) -or
        ($locale['Code'] -ne 'en' -and $allDaySetting -eq 'All day') -or
        (Test-MojibakeText $allDaySetting)) {
        $allDaySetting = $allDayDefault
    }
    $allDayLabel = Convert-RainmeterText $allDaySetting
    if ([string]::IsNullOrWhiteSpace($allDayLabel)) {
        $allDayLabel = Convert-RainmeterText $allDayDefault
    }
    $untitledLabel = Get-LocaleText -Locale $locale -Key 'Untitled'

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[Variables]')
    $lines.Add(('LocaleCode={0}' -f $locale['Code']))
    $lines.Add(('LocaleName={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'Name'))))
    $lines.Add(('LabelNoEvents={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'NoEvents'))))
    $lines.Add(('LabelCountdownEnds={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'Ends'))))
    $lines.Add(('LabelCountdownNext={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'Next'))))
    $lines.Add(('LabelCountdownDone={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'Done'))))
    $lines.Add(('UnitMinute={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitMinute'))))
    $lines.Add(('UnitMinuteSuffix={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitMinuteSuffix'))))
    $lines.Add(('UnitHour={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitHour'))))
    $lines.Add(('UnitHourSuffix={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitHourSuffix'))))
    $lines.Add(('UnitDay={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitDay'))))
    $lines.Add(('UnitDayPlural={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitDayPlural'))))
    $lines.Add(('UnitDaySuffix={0}' -f (Convert-RainmeterText (Get-LocaleText -Locale $locale -Key 'UnitDaySuffix'))))
    $lines.Add(('UnitJoiner={0}' -f (Get-LocaleText -Locale $locale -Key 'UnitJoiner')))
    $lines.Add(('LastUpdated={0}' -f (Get-Date -Format $timePattern)))
    $lines.Add(('SourceStatus={0}' -f (Convert-StatusText -Status $Status -Locale $locale)))
    $lines.Add(('EventCount={0}' -f $filtered.Count))

    $colors = @('205,214,224,230', '255,199,50,255', '104,170,255,245', '126,220,117,245', '238,120,150,245')
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $n = $i + 1
        $event = $filtered[$i]
        $color = if ($event.Color) { $event.Color } else { $colors[$i % $colors.Count] }
        $time = if ($event.AllDay) { $allDayLabel } else { $event.Start.ToString($timePattern) }
        $endTime = if ($event.AllDay) { '' } else { $event.End.ToString($timePattern) }
        $dateLabel = Format-LocalizedDateLabel -Date $event.Start -Locale $locale
        $icon = if ($event.Icon) { $event.Icon } else { Get-EventIcon $event.Title }
        $title = Convert-TitleText $event.Title
        $location = Convert-DisplayText $event.Location
        $notes = Convert-DisplayText $event.Notes
        $calendar = Convert-DisplayText $event.Calendar

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = $untitledLabel
        }

        $lines.Add(("Event{0}Title={1}" -f $n, $title))
        $lines.Add(("Event{0}Icon={1}" -f $n, $icon))
        $lines.Add(("Event{0}Location={1}" -f $n, $location))
        $lines.Add(("Event{0}Notes={1}" -f $n, $notes))
        $lines.Add(("Event{0}Calendar={1}" -f $n, $calendar))
        $lines.Add(("Event{0}Time={1}" -f $n, $time))
        $lines.Add(("Event{0}EndTime={1}" -f $n, $endTime))
        $lines.Add(("Event{0}Date={1}" -f $n, $dateLabel))
        $lines.Add(("Event{0}StartEpoch={1}" -f $n, (Get-UnixSeconds $event.Start)))
        $lines.Add(("Event{0}EndEpoch={1}" -f $n, (Get-UnixSeconds $event.End)))
        $lines.Add(("Event{0}AllDay={1}" -f $n, ($(if ($event.AllDay) { 1 } else { 0 }))))
        $lines.Add(("Event{0}Color={1}" -f $n, $color))
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllLines($Path, [string[]]$lines, $utf8Bom)
}

try {
    if ($UseExistingCache -and (Test-AgendaCacheExists -Path $OutputPath)) {
        $cache = Read-AgendaCache -Path $OutputPath
        $status = Get-SettingValue -Path $SettingsPath -Name 'FeedStatusSummary' -Default ''
        if ([string]::IsNullOrWhiteSpace($status)) {
            $status = $cache.Status
        }
        if ([string]::IsNullOrWhiteSpace($status)) {
            $status = 'Updated 0 feed(s)'
        }

        Write-AgendaCache -Events $cache.Events -Path $OutputPath -Status $status
        return
    }

    $useSample = Get-SettingValue -Path $SettingsPath -Name 'UseSample' -Default '0'
    $maxStatusFeeds = [int](Get-SettingValue -Path $SettingsPath -Name 'CalendarSlots' -Default '8')
    $maxStatusFeeds = [Math]::Max(3, [Math]::Min(15, $maxStatusFeeds))
    if ($useSample -eq '1') {
        Save-FeedStatus -Path $SettingsPath -Statuses @() -MaxFeeds $maxStatusFeeds -Summary 'Demo data'
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Demo data'
        return
    }

    $feeds = @(Get-CalendarFeeds -Path $SettingsPath)
    $today = (Get-Date).Date
    $pastDays = [int](Get-SettingValue -Path $SettingsPath -Name 'CachePastDays' -Default '14')
    $futureDays = [int](Get-SettingValue -Path $SettingsPath -Name 'CacheFutureDays' -Default '90')
    $parseWindowStart = $today.AddDays(-[Math]::Max(7, $pastDays))
    $parseWindowEnd = $today.AddDays([Math]::Max(31, $futureDays))

    if ($feeds.Count -eq 0) {
        Save-FeedStatus -Path $SettingsPath -Statuses @() -MaxFeeds $maxStatusFeeds -Summary 'No feeds configured'
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Sample data'
        return
    }

    $allEvents = New-Object System.Collections.Generic.List[object]
    $feedStatuses = New-Object System.Collections.Generic.List[object]
    $successCount = 0
    $failureCount = 0

    foreach ($feed in $feeds) {
        try {
            $content = Get-CalendarContent -Source $feed.Url
            $calendarName = $feed.Name
            if ([string]::IsNullOrWhiteSpace($calendarName)) {
                $calendarName = Get-IcsCalendarName -Content $content
            }
            if ([string]::IsNullOrWhiteSpace($calendarName)) {
                $calendarName = $feed.FallbackName
            }

            $detectedColor = Get-IcsCalendarColor -Content $content
            $calendarColor = if (![string]::IsNullOrWhiteSpace($feed.Color) -and $feed.Color -ne '255,255,255,0') { $feed.Color } elseif (![string]::IsNullOrWhiteSpace($detectedColor)) { $detectedColor } else { $feed.Color }
            $events = Parse-IcsEvents -Content $content -CalendarName $calendarName -Color $calendarColor -WindowStart $parseWindowStart -WindowEnd $parseWindowEnd
            foreach ($event in $events) { $allEvents.Add($event) }
            $feedStatuses.Add([pscustomobject]@{
                Index = $feed.Index
                Name = $calendarName
                Result = 'OK'
                Count = @($events).Count
                Color = $calendarColor
            })
            $successCount++
        }
        catch {
            $feedStatuses.Add([pscustomobject]@{
                Index = $feed.Index
                Name = if (![string]::IsNullOrWhiteSpace($feed.Name)) { $feed.Name } else { $feed.FallbackName }
                Result = 'Failed'
                Count = 0
                Color = $feed.Color
            })
            $failureCount++
        }
    }

    if ($successCount -eq 0) {
        Save-FeedStatus -Path $SettingsPath -Statuses $feedStatuses.ToArray() -MaxFeeds $maxStatusFeeds -Summary ("0 of {0} feed(s) updated" -f $feeds.Count)
        if (!(Test-AgendaCacheExists -Path $OutputPath)) {
            Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Refresh failed - sample data'
        }
        return
    }

    $status = if ($failureCount -gt 0) {
        "Updated $successCount feed(s), $failureCount failed"
    }
    else {
        "Updated $successCount feed(s)"
    }
    Save-FeedStatus -Path $SettingsPath -Statuses $feedStatuses.ToArray() -MaxFeeds $maxStatusFeeds -Summary $status
    Write-AgendaCache -Events $allEvents.ToArray() -Path $OutputPath -Status $status
}
catch {
    if (!(Test-AgendaCacheExists -Path $OutputPath)) {
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status ("Refresh failed - sample data")
    }
    return
}
