param(
    [Parameter(Mandatory = $true)]
    [string]$SettingsPath,

    [int]$MaxFeeds = 15,

    [string]$FeedText = '',

    [ValidateSet('Add', 'Remove', 'Clear')]
    [string]$Mode = 'Add',

    [int[]]$Slots = @(),

    [switch]$Clear,

    [switch]$ConfirmClear
)

$ErrorActionPreference = 'Stop'

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

function Get-IncValue {
    param(
        [string[]]$Lines,
        [string]$Name,
        [string]$Default = ''
    )

    $pattern = '^' + [regex]::Escape($Name) + '=(.*)$'
    foreach ($line in $Lines) {
        if ($line -match $pattern) {
            return $Matches[1]
        }
    }
    return $Default
}

function Set-IncValue {
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

    if ($updated.Count -eq $insertAt) {
        return @($updated) + @($replacement)
    }

    return @($updated[0..($insertAt - 1)]) + @($replacement) + @($updated[$insertAt..($updated.Count - 1)])
}

function Get-LanguageCode {
    param([string[]]$Lines)

    $aliases = @{
        english = 'en'; anglais = 'en'; englisch = 'en'; inglese = 'en'; ingles = 'en'
        russian = 'ru'; russe = 'ru'; russisch = 'ru'; ruso = 'ru'; russo = 'ru'
        spanish = 'es'; espagnol = 'es'; spanisch = 'es'; spagnolo = 'es'; espanol = 'es'
        italian = 'it'; italien = 'it'; italienisch = 'it'; italiano = 'it'
        french = 'fr'; francais = 'fr'; français = 'fr'; franzosisch = 'fr'; französisch = 'fr'; francese = 'fr'
        german = 'de'; allemand = 'de'; deutsch = 'de'; tedesco = 'de'; aleman = 'de'
    }

    $candidates = @(
        (Get-IncValue -Lines $Lines -Name 'Language' -Default ''),
        (Get-IncValue -Lines $Lines -Name 'LanguageLabel' -Default '')
    )

    foreach ($candidate in $candidates) {
        $code = $candidate.Trim().ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($code)) {
            continue
        }
        $code = $code.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', ''
        if ($aliases.ContainsKey($code)) {
            $code = $aliases[$code]
        }
        if ($code -in @('en', 'ru', 'es', 'it', 'fr', 'de')) {
            return $code
        }
    }

    return 'en'
}

function Get-ImportLabels {
    param([string]$Code)

    $labels = @{
        en = @{
            InvalidGeneric = 'This does not look like an iCal feed link.'
            GooglePage = 'This looks like a Google Calendar page. Copy the Secret address in iCal format instead.'
            UrlNotIcal = 'This URL does not look like an iCal feed. Copy the Secret address in iCal format.'
            ClearPrompt = 'Click Clear All again to confirm.'
            ClearPromptSummary = 'Clear all needs confirmation'
            Cleared = 'Cleared all calendars at {0}'
            ClearedSummary = 'Calendars cleared'
            NoSlotSelected = 'No calendar slot was selected for removal.'
            NoCalendarsRemoved = 'No calendars removed'
            Removed = 'Removed calendar slot(s) {0} at {1}'
            RemovedSummary = 'Removed slot(s) {0}'
            ClipboardEmpty = 'Clipboard is empty. Copy one or more iCal links first.'
            NoIcalFound = 'No iCal links found'
            NoUsable = 'No usable iCal links were found.'
            PendingName = 'Feed {0} pending refresh'
            Pending = 'Pending'
            AddedPart = 'Added {0} calendar(s)'
            SkippedDuplicates = 'skipped {0} duplicate(s)'
            SkippedInvalid = 'skipped {0} non-iCal link(s)'
            DidNotFit = '{0} did not fit'
            AddedAt = '{0} at {1}'
            DuplicateOnly = 'No new calendars were added; duplicate link(s) skipped.'
            SlotsFull = 'All 15 calendar slots are full. Remove one before adding another.'
            NoNew = 'No new calendars were added.'
            SummaryAdded = 'Added {0}; refresh pending'
            SummaryNoAdded = 'No calendars added'
            SummaryDuplicates = 'duplicates {0}'
            SummaryInvalid = 'invalid {0}'
            SummaryFull = 'full {0}'
        }
        ru = @{
            InvalidGeneric = 'Eto ne pohozhe na ssylku iCal.'
            GooglePage = 'Eto stranitsa Google Calendar. Skopiruyte sekretniy adres v formate iCal.'
            UrlNotIcal = 'URL ne pohozh na iCal-lentu. Skopiruyte sekretniy adres iCal.'
            ClearPrompt = 'Nazhmite Ochistit vse eshche raz dlya podtverzhdeniya.'
            ClearPromptSummary = 'Ochistka trebuet podtverzhdeniya'
            Cleared = 'Vse kalendari ochischeny v {0}'
            ClearedSummary = 'Kalendari ochischeny'
            NoSlotSelected = 'Ne vybran slot kalendarya dlya udaleniya.'
            NoCalendarsRemoved = 'Kalendari ne udaleni'
            Removed = 'Udaleni sloty kalendarya {0} v {1}'
            RemovedSummary = 'Udaleni sloty {0}'
            ClipboardEmpty = 'Bufer pust. Skopiruyte odnu ili neskolko ssylok iCal.'
            NoIcalFound = 'Ssylki iCal ne naydeny'
            NoUsable = 'Podhodyaschie ssylki iCal ne naydeny.'
            PendingName = 'Lenta {0} zhdet obnovleniya'
            Pending = 'Ozhidaet'
            AddedPart = 'Dobavleno kalendarey: {0}'
            SkippedDuplicates = 'propuscheno dublikatov: {0}'
            SkippedInvalid = 'propuscheno ne-iCal ssylok: {0}'
            DidNotFit = 'ne pomestilos: {0}'
            AddedAt = '{0} v {1}'
            DuplicateOnly = 'Novye kalendari ne dobavleny; dublikaty propuscheny.'
            SlotsFull = 'Vse 15 slotov zanyaty. Udalite odin pered dobavleniem.'
            NoNew = 'Novye kalendari ne dobavleny.'
            SummaryAdded = 'Dobavleno {0}; nuzhno obnovit'
            SummaryNoAdded = 'Kalendari ne dobavleny'
            SummaryDuplicates = 'dublikatov {0}'
            SummaryInvalid = 'nevernyh {0}'
            SummaryFull = 'net mesta {0}'
        }
        es = @{
            InvalidGeneric = 'Esto no parece un enlace de fuente iCal.'
            GooglePage = 'Esto parece una página de Google Calendar. Copia la dirección secreta en formato iCal.'
            UrlNotIcal = 'Esta URL no parece una fuente iCal. Copia la dirección secreta en formato iCal.'
            ClearPrompt = 'Haz clic en Borrar todo otra vez para confirmar.'
            ClearPromptSummary = 'Borrar todo requiere confirmación'
            Cleared = 'Todos los calendarios se borraron a las {0}'
            ClearedSummary = 'Calendarios borrados'
            NoSlotSelected = 'No se seleccionó ningún calendario para quitar.'
            NoCalendarsRemoved = 'No se quitaron calendarios'
            Removed = 'Calendario(s) {0} quitado(s) a las {1}'
            RemovedSummary = 'Quitado(s) {0}'
            ClipboardEmpty = 'El portapapeles está vacío. Copia uno o más enlaces iCal primero.'
            NoIcalFound = 'No se encontraron enlaces iCal'
            NoUsable = 'No se encontraron enlaces iCal válidos.'
            PendingName = 'Fuente {0} pendiente de actualización'
            Pending = 'Pendiente'
            AddedPart = '{0} calendario(s) añadido(s)'
            SkippedDuplicates = '{0} duplicado(s) omitido(s)'
            SkippedInvalid = '{0} enlace(s) no iCal omitido(s)'
            DidNotFit = '{0} no cupieron'
            AddedAt = '{0} a las {1}'
            DuplicateOnly = 'No se añadieron calendarios nuevos; se omitieron enlaces duplicados.'
            SlotsFull = 'Los 15 espacios de calendario están llenos. Quita uno antes de añadir otro.'
            NoNew = 'No se añadieron calendarios nuevos.'
            SummaryAdded = 'Añadidos {0}; actualización pendiente'
            SummaryNoAdded = 'No se añadieron calendarios'
            SummaryDuplicates = 'duplicados {0}'
            SummaryInvalid = 'inválidos {0}'
            SummaryFull = 'llenos {0}'
        }
        it = @{
            InvalidGeneric = 'Questo non sembra un link feed iCal.'
            GooglePage = 'Sembra una pagina di Google Calendar. Copia l''indirizzo segreto in formato iCal.'
            UrlNotIcal = 'Questo URL non sembra un feed iCal. Copia l''indirizzo segreto in formato iCal.'
            ClearPrompt = 'Fai clic di nuovo su Cancella tutto per confermare.'
            ClearPromptSummary = 'Cancella tutto richiede conferma'
            Cleared = 'Tutti i calendari sono stati cancellati alle {0}'
            ClearedSummary = 'Calendari cancellati'
            NoSlotSelected = 'Nessun calendario selezionato per la rimozione.'
            NoCalendarsRemoved = 'Nessun calendario rimosso'
            Removed = 'Calendario/i {0} rimosso/i alle {1}'
            RemovedSummary = 'Rimosso/i {0}'
            ClipboardEmpty = 'Gli appunti sono vuoti. Copia prima uno o più link iCal.'
            NoIcalFound = 'Nessun link iCal trovato'
            NoUsable = 'Nessun link iCal utilizzabile trovato.'
            PendingName = 'Feed {0} in attesa di aggiornamento'
            Pending = 'In attesa'
            AddedPart = '{0} calendario/i aggiunto/i'
            SkippedDuplicates = '{0} duplicato/i saltato/i'
            SkippedInvalid = '{0} link non iCal saltato/i'
            DidNotFit = '{0} non inserito/i'
            AddedAt = '{0} alle {1}'
            DuplicateOnly = 'Nessun nuovo calendario aggiunto; link duplicati saltati.'
            SlotsFull = 'Tutti i 15 slot calendario sono pieni. Rimuovine uno prima di aggiungerne un altro.'
            NoNew = 'Nessun nuovo calendario aggiunto.'
            SummaryAdded = 'Aggiunti {0}; aggiornamento in sospeso'
            SummaryNoAdded = 'Nessun calendario aggiunto'
            SummaryDuplicates = 'duplicati {0}'
            SummaryInvalid = 'non validi {0}'
            SummaryFull = 'pieni {0}'
        }
        fr = @{
            InvalidGeneric = 'Cela ne ressemble pas à un lien de flux iCal.'
            GooglePage = 'Cela ressemble à une page Google Calendar. Copiez plutôt l''adresse secrète au format iCal.'
            UrlNotIcal = 'Cette URL ne ressemble pas à un flux iCal. Copiez l''adresse secrète au format iCal.'
            ClearPrompt = 'Cliquez encore sur Tout effacer pour confirmer.'
            ClearPromptSummary = 'Tout effacer demande confirmation'
            Cleared = 'Tous les calendriers ont été effacés à {0}'
            ClearedSummary = 'Calendriers effacés'
            NoSlotSelected = 'Aucun calendrier n''a été sélectionné pour suppression.'
            NoCalendarsRemoved = 'Aucun calendrier supprimé'
            Removed = 'Calendrier(s) {0} supprimé(s) à {1}'
            RemovedSummary = 'Supprimé(s) {0}'
            ClipboardEmpty = 'Le presse-papiers est vide. Copiez d''abord un ou plusieurs liens iCal.'
            NoIcalFound = 'Aucun lien iCal trouvé'
            NoUsable = 'Aucun lien iCal utilisable trouvé.'
            PendingName = 'Flux {0} en attente d''actualisation'
            Pending = 'En attente'
            AddedPart = '{0} calendrier(s) ajouté(s)'
            SkippedDuplicates = '{0} doublon(s) ignoré(s)'
            SkippedInvalid = '{0} lien(s) non iCal ignoré(s)'
            DidNotFit = '{0} sans place'
            AddedAt = '{0} à {1}'
            DuplicateOnly = 'Aucun nouveau calendrier ajouté ; les doublons ont été ignorés.'
            SlotsFull = 'Les 15 emplacements de calendrier sont pleins. Supprimez-en un avant d''en ajouter un autre.'
            NoNew = 'Aucun nouveau calendrier ajouté.'
            SummaryAdded = '{0} ajouté(s) ; actualisation en attente'
            SummaryNoAdded = 'Aucun calendrier ajouté'
            SummaryDuplicates = 'doublons {0}'
            SummaryInvalid = 'non valides {0}'
            SummaryFull = 'pleins {0}'
        }
        de = @{
            InvalidGeneric = 'Das sieht nicht wie ein iCal-Feed-Link aus.'
            GooglePage = 'Das sieht wie eine Google-Calendar-Seite aus. Kopieren Sie die geheime Adresse im iCal-Format.'
            UrlNotIcal = 'Diese URL sieht nicht wie ein iCal-Feed aus. Kopieren Sie die geheime Adresse im iCal-Format.'
            ClearPrompt = 'Klicken Sie erneut auf Alles löschen, um zu bestätigen.'
            ClearPromptSummary = 'Alles löschen erfordert Bestätigung'
            Cleared = 'Alle Kalender wurden um {0} gelöscht'
            ClearedSummary = 'Kalender gelöscht'
            NoSlotSelected = 'Es wurde kein Kalender zum Entfernen ausgewählt.'
            NoCalendarsRemoved = 'Keine Kalender entfernt'
            Removed = 'Kalender-Slot(s) {0} um {1} entfernt'
            RemovedSummary = 'Slot(s) {0} entfernt'
            ClipboardEmpty = 'Die Zwischenablage ist leer. Kopieren Sie zuerst einen oder mehrere iCal-Links.'
            NoIcalFound = 'Keine iCal-Links gefunden'
            NoUsable = 'Keine verwendbaren iCal-Links gefunden.'
            PendingName = 'Feed {0} wartet auf Aktualisierung'
            Pending = 'Ausstehend'
            AddedPart = '{0} Kalender hinzugefügt'
            SkippedDuplicates = '{0} Duplikat(e) übersprungen'
            SkippedInvalid = '{0} Nicht-iCal-Link(s) übersprungen'
            DidNotFit = '{0} ohne Platz'
            AddedAt = '{0} um {1}'
            DuplicateOnly = 'Keine neuen Kalender hinzugefügt; doppelte Links wurden übersprungen.'
            SlotsFull = 'Alle 15 Kalenderplätze sind voll. Entfernen Sie einen, bevor Sie einen weiteren hinzufügen.'
            NoNew = 'Keine neuen Kalender hinzugefügt.'
            SummaryAdded = '{0} hinzugefügt; Aktualisierung ausstehend'
            SummaryNoAdded = 'Keine Kalender hinzugefügt'
            SummaryDuplicates = 'Duplikate {0}'
            SummaryInvalid = 'ungültig {0}'
            SummaryFull = 'voll {0}'
        }
    }

    if (!$labels.ContainsKey($Code)) {
        return $labels.en
    }
    return $labels[$Code]
}

function Format-ImportText {
    param(
        [hashtable]$Labels,
        [string]$Key,
        [object[]]$FormatArgs = @()
    )

    $template = if ($Labels.ContainsKey($Key)) { $Labels[$Key] } else { $Key }
    if ($FormatArgs.Count -gt 0) {
        return ($template -f $FormatArgs)
    }
    return $template
}

function Get-FeedUrlKey {
    param([int]$Slot)
    if ($Slot -eq 1) {
        return 'CalendarUrl'
    }
    return "CalendarUrl$Slot"
}

function Normalize-FeedUrl {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $clean = $Text.Trim()
    $clean = $clean.Trim('"', "'", '<', '>')
    if ($clean -match '^webcal://') {
        $clean = $clean -replace '^webcal://', 'https://'
    }
    return $clean
}

function Test-FeedUrlShape {
    param([string]$Url)

    $result = @{
        IsUsable = $false
        MessageKey = 'InvalidGeneric'
    }

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $result
    }

    $uri = $null
    if (![Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) {
        return $result
    }

    if ($uri.Scheme -notin @('http', 'https', 'webcal')) {
        return $result
    }

    $full = $uri.AbsoluteUri.ToLowerInvariant()
    $uriHost = $uri.Host.ToLowerInvariant()
    $path = $uri.AbsolutePath.ToLowerInvariant()

    if ($uriHost -match '(^|\.)calendar\.google\.com$' -and $path -notmatch '/calendar/ical/') {
        $result.MessageKey = 'GooglePage'
        return $result
    }

    if ($full -match '\.ics($|[?#])' -or $path -match '/ical/' -or $path -match '/ics/' -or $full -match 'ical') {
        $result.IsUsable = $true
        $result.MessageKey = ''
        return $result
    }

    $result.MessageKey = 'UrlNotIcal'
    return $result
}

function Get-ExistingFeeds {
    param(
        [string[]]$Lines,
        [int]$Max
    )

    $feeds = @{}
    for ($i = 1; $i -le $Max; $i++) {
        $key = Get-FeedUrlKey -Slot $i
        $value = Get-IncValue -Lines $Lines -Name $key
        if ($i -eq 1 -and [string]::IsNullOrWhiteSpace($value)) {
            $value = Get-IncValue -Lines $Lines -Name 'CalendarUrl1'
        }
        $feeds[$i] = (Normalize-FeedUrl $value)
    }
    return $feeds
}

function Get-EmptyFeedSlots {
    param(
        [hashtable]$Feeds,
        [int]$Max
    )

    $slots = New-Object System.Collections.Generic.List[int]
    for ($i = 1; $i -le $Max; $i++) {
        if ([string]::IsNullOrWhiteSpace([string]$Feeds[$i])) {
            [void]$slots.Add($i)
        }
    }
    return @($slots)
}

function Clear-FeedSlot {
    param(
        [string[]]$Lines,
        [int]$Slot
    )

    $key = Get-FeedUrlKey -Slot $Slot
    $Lines = @(Set-IncValue -Lines $Lines -Name $key -Value '')
    if ($Slot -eq 1) {
        $Lines = @(Set-IncValue -Lines $Lines -Name 'CalendarUrl1' -Value '')
    }
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Name" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Result" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Count" -Value '')
    $Lines = @(Set-IncValue -Lines $Lines -Name "Feed${Slot}Color" -Value '255,255,255,0')
    return @($Lines)
}

function Set-Status {
    param(
        [string[]]$Lines,
        [string]$ImportStatus,
        [string]$Summary
    )

    $Lines = @(Set-IncValue -Lines $Lines -Name 'FeedImportStatus' -Value $ImportStatus)
    $Lines = @(Set-IncValue -Lines $Lines -Name 'FeedStatusSummary' -Value $Summary)
    return @($Lines)
}

$palette = @(
    '255,199,50,255',
    '104,170,255,245',
    '126,220,117,245',
    '238,120,150,245',
    '155,111,225,245',
    '24,163,214,245',
    '224,72,72,245',
    '234,191,48,245',
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

if ($Clear) {
    $Mode = 'Clear'
    $ConfirmClear = $true
}

$resolvedPath = [Environment]::ExpandEnvironmentVariables($SettingsPath)
if (!(Test-Path -LiteralPath $resolvedPath)) {
    throw "Settings file not found: $resolvedPath"
}

$max = [Math]::Max(1, [Math]::Min(15, $MaxFeeds))
$settingsEncoding = Get-RainmeterIncludeEncoding
$lines = @([System.IO.File]::ReadAllLines($resolvedPath, $settingsEncoding))
$languageCode = Get-LanguageCode -Lines $lines
$importLabels = Get-ImportLabels -Code $languageCode

if ($Mode -eq 'Clear') {
    if (!$ConfirmClear) {
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'ClearPrompt') -Summary (Format-ImportText -Labels $importLabels -Key 'ClearPromptSummary'))
        [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
        Write-Host (Format-ImportText -Labels $importLabels -Key 'ClearPromptSummary')
        exit 0
    }

    for ($i = 1; $i -le $max; $i++) {
        $lines = @(Clear-FeedSlot -Lines $lines -Slot $i)
    }

    $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '1')
    $lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'Cleared' -FormatArgs @((Get-Date -Format 'h:mm tt'))) -Summary (Format-ImportText -Labels $importLabels -Key 'ClearedSummary'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'ClearedSummary')
    exit 0
}

if ($Mode -eq 'Remove') {
    $validSlots = @($Slots | Where-Object { $_ -ge 1 -and $_ -le $max } | Select-Object -Unique)
    if ($validSlots.Count -eq 0) {
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'NoSlotSelected') -Summary (Format-ImportText -Labels $importLabels -Key 'NoCalendarsRemoved'))
    }
    else {
        foreach ($slot in $validSlots) {
            $lines = @(Clear-FeedSlot -Lines $lines -Slot $slot)
        }
        $remainingFeeds = Get-ExistingFeeds -Lines $lines -Max $max
        $remainingCount = @($remainingFeeds.Values | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) }).Count
        $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value $(if ($remainingCount -gt 0) { '0' } else { '1' }))
        $slotText = ($validSlots -join ', ')
        $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'Removed' -FormatArgs @($slotText, (Get-Date -Format 'h:mm tt'))) -Summary (Format-ImportText -Labels $importLabels -Key 'RemovedSummary' -FormatArgs @($slotText)))
    }

    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Get-IncValue -Lines $lines -Name 'FeedImportStatus' -Default (Format-ImportText -Labels $importLabels -Key 'NoCalendarsRemoved'))
    exit 0
}

$raw = $FeedText
if ([string]::IsNullOrWhiteSpace($raw)) {
    $raw = Get-Clipboard -Raw
}

if ([string]::IsNullOrWhiteSpace($raw)) {
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'ClipboardEmpty') -Summary (Format-ImportText -Labels $importLabels -Key 'NoIcalFound'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'ClipboardEmpty')
    exit 0
}

$candidates = @(
    $raw -split "\r?\n" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne '' -and $_ -notmatch '^\s*#' } |
        ForEach-Object { Normalize-FeedUrl $_ } |
        Where-Object { $_ -ne '' }
)

if ($candidates.Count -eq 0) {
    $lines = @(Set-Status -Lines $lines -ImportStatus (Format-ImportText -Labels $importLabels -Key 'NoUsable') -Summary (Format-ImportText -Labels $importLabels -Key 'NoIcalFound'))
    [System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)
    Write-Host (Format-ImportText -Labels $importLabels -Key 'NoUsable')
    exit 0
}

$existingFeeds = Get-ExistingFeeds -Lines $lines -Max $max
$existingLookup = @{}
foreach ($url in $existingFeeds.Values) {
    if (![string]::IsNullOrWhiteSpace([string]$url)) {
        $existingLookup[[string]$url] = $true
    }
}

$emptySlots = New-Object System.Collections.Queue
foreach ($slot in (Get-EmptyFeedSlots -Feeds $existingFeeds -Max $max)) {
    $emptySlots.Enqueue($slot)
}

$seenCandidates = @{}
$added = 0
$duplicates = 0
$invalid = 0
$notFit = 0
$firstInvalidMessage = ''

foreach ($candidate in $candidates) {
    if ($seenCandidates.ContainsKey($candidate) -or $existingLookup.ContainsKey($candidate)) {
        $duplicates++
        continue
    }
    $seenCandidates[$candidate] = $true

    $shape = Test-FeedUrlShape -Url $candidate
    if (!$shape.IsUsable) {
        $invalid++
        if ([string]::IsNullOrWhiteSpace($firstInvalidMessage)) {
            $firstInvalidMessage = Format-ImportText -Labels $importLabels -Key $shape.MessageKey
        }
        continue
    }

    if ($emptySlots.Count -le 0) {
        $notFit++
        continue
    }

    $slot = [int]$emptySlots.Dequeue()
    $key = Get-FeedUrlKey -Slot $slot
    $lines = @(Set-IncValue -Lines $lines -Name $key -Value $candidate)
    if ($slot -eq 1) {
        $lines = @(Set-IncValue -Lines $lines -Name 'CalendarUrl1' -Value $candidate)
    }

    $color = Get-IncValue -Lines $lines -Name "CalendarColor$slot"
    if ([string]::IsNullOrWhiteSpace($color)) {
        $color = $palette[($slot - 1) % $palette.Count]
        $lines = @(Set-IncValue -Lines $lines -Name "CalendarColor$slot" -Value $color)
    }

    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Name" -Value (Format-ImportText -Labels $importLabels -Key 'PendingName' -FormatArgs @($slot)))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Result" -Value (Format-ImportText -Labels $importLabels -Key 'Pending'))
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Count" -Value '')
    $lines = @(Set-IncValue -Lines $lines -Name "Feed${slot}Color" -Value $color)
    $added++
}

$parts = New-Object System.Collections.Generic.List[string]
if ($added -gt 0) {
    [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'AddedPart' -FormatArgs @($added)))
    if ($duplicates -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'SkippedDuplicates' -FormatArgs @($duplicates))) }
    if ($invalid -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'SkippedInvalid' -FormatArgs @($invalid))) }
    if ($notFit -gt 0) { [void]$parts.Add((Format-ImportText -Labels $importLabels -Key 'DidNotFit' -FormatArgs @($notFit))) }
}

if ($added -eq 0) {
    if (![string]::IsNullOrWhiteSpace($firstInvalidMessage)) {
        $status = $firstInvalidMessage
    }
    elseif ($duplicates -gt 0) {
        $status = Format-ImportText -Labels $importLabels -Key 'DuplicateOnly'
    }
    elseif ($emptySlots.Count -le 0) {
        $status = Format-ImportText -Labels $importLabels -Key 'SlotsFull'
    }
    else {
        $status = Format-ImportText -Labels $importLabels -Key 'NoNew'
    }
}
else {
    $status = Format-ImportText -Labels $importLabels -Key 'AddedAt' -FormatArgs @(($parts -join '; '), (Get-Date -Format 'h:mm tt'))
}

if ($added -gt 0) {
    $lines = @(Set-IncValue -Lines $lines -Name 'UseSample' -Value '0')
}
$lines = @(Set-IncValue -Lines $lines -Name 'CalendarSlots' -Value ([string]$max))
$summary = if ($added -gt 0) { Format-ImportText -Labels $importLabels -Key 'SummaryAdded' -FormatArgs @($added) } else { Format-ImportText -Labels $importLabels -Key 'SummaryNoAdded' }
if ($duplicates -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryDuplicates' -FormatArgs @($duplicates)) }
if ($invalid -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryInvalid' -FormatArgs @($invalid)) }
if ($notFit -gt 0) { $summary += '; ' + (Format-ImportText -Labels $importLabels -Key 'SummaryFull' -FormatArgs @($notFit)) }
$lines = @(Set-Status -Lines $lines -ImportStatus $status -Summary $summary)

[System.IO.File]::WriteAllLines($resolvedPath, $lines, $settingsEncoding)

Write-Host $status
