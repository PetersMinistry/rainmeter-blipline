param(
    [string]$SettingsPath,
    [string]$OutputPath,
    [string]$Name,
    [string]$Value,
    [string]$Label = '',
    [string]$RefreshConfigs = ''
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

function Get-LanguageLabel {
    param([string]$Code)

    switch ($Code.ToLowerInvariant()) {
        'en' { return 'English' }
        'ru' { return 'Russian' }
        'es' { return 'Spanish' }
        'it' { return 'Italian' }
        'fr' { return 'French' }
        'de' { return 'German' }
        default { return 'English' }
    }
}

function Get-LanguageIndex {
    param([string]$Code)

    switch ($Code.ToLowerInvariant()) {
        'en' { return 1 }
        'ru' { return 2 }
        'es' { return 3 }
        'it' { return 4 }
        'fr' { return 5 }
        'de' { return 6 }
        default { return 1 }
    }
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
    return ((Remove-RainmeterUnsafeUnicode $Text) -replace '[\r\n=]', ' ').Trim()
}

function Get-SettingsLabels {
    param([string]$Code)

    $labels = @{
        en = @{
            UiSubtitle = 'Google Calendar / iCal agenda timeline'
            UiRefresh = 'Refresh'
            UiOpen = 'Open'
            UiDemo = 'Demo'
            UiFeedImport = 'Calendar feed import'
            UiImportClipboard = 'Import Clipboard'
            UiResetFeeds = 'Reset Feeds'
            UiImportHelp = 'Copy private iCal URLs one per line, then import them together. Reset clears saved feed URLs and returns to demo data.'
            UiImportHelp1 = 'Copy private iCal URLs one per line, then import them together.'
            UiImportHelp2 = 'Reset clears saved feed URLs and returns to demo data.'
            UiAddCalendars = 'Add Calendars'
            UiCalendarImportTitle = 'Add Calendars'
            UiCalendarImportHelp1 = 'Copy the Secret address in iCal format from Google Calendar.'
            UiCalendarImportHelp2 = 'You can copy one link or several links, one per line.'
            UiAddIcalLinks = 'Add iCal Link(s)'
            UiConnectedCalendars = 'Connected calendars'
            UiRemove = 'Remove'
            UiClearAllCalendars = 'Clear All'
            UiConfirmClear = 'Confirm Clear'
            UiOpenGoogleCalendar = 'Open Google Calendar'
            UiBackSettings = 'Settings'
            UiDetectedCalendars = 'Detected calendars'
            UiFeedPalette = 'Feed color palette (24)'
            UiSelectedFeed = 'Selected feed'
            UiDisplaySettings = 'Display settings'
            UiLanguagePrefix = 'Language'
            UiLangEnglish = 'English'
            UiLangRussian = 'Russian'
            UiLangSpanish = 'Spanish'
            UiLangItalian = 'Italian'
            UiLangFrench = 'French'
            UiLangGerman = 'German'
            UiClockFormat = 'Clock format'
            UiTime12 = '12-hour'
            UiTime24 = '24-hour'
            UiEventDetails = 'Event details'
            UiCalendar = 'Calendar'
            UiLocation = 'Location'
            UiNotes = 'Notes'
            UiTimelineScale = 'Timeline scale'
            UiResetScale = 'Reset 100%'
            UiRefreshInterval = 'Refresh interval'
            UiRefresh1 = '1 min'
            UiRefresh5 = '5 min'
            UiRefresh10 = '10 min'
            UiRefresh15 = '15 min'
            UiLayoutTemplate = 'Layout template'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'Sync status'
            UiStatusText = 'Blipline refreshes automatically. Use Refresh after changing feeds.'
            UiPrivacyNote = 'Click a feed dot, choose a swatch, and Blipline writes that calendar color. Daylight is light-mode. Phantom is transparent.'
        }
        ru = @{
            UiSubtitle = 'Google Calendar / iCal liniya'
            UiRefresh = 'Obnovit'
            UiOpen = 'Otkryt'
            UiDemo = 'Demo'
            UiFeedImport = 'Import kalendarey'
            UiImportClipboard = 'Import iz bufera'
            UiResetFeeds = 'Sbrosit lenty'
            UiImportHelp = 'Skopiruyte lichnye iCal URL po odnomu v stroke i importiruyte ih vmeste. Sbros ochischaet lenty i vklyuchaet demo.'
            UiImportHelp1 = 'Skopiruyte lichnye iCal URL po odnomu v stroke.'
            UiImportHelp2 = 'Importiruyte ih vmeste. Sbros vklyuchaet demo.'
            UiAddCalendars = 'Dobavit kalendari'
            UiCalendarImportTitle = 'Dobavit kalendari'
            UiCalendarImportHelp1 = 'Skopiruyte sekretniy iCal-adres iz Google Calendar.'
            UiCalendarImportHelp2 = 'Mozhno skopirovat odnu ssylku ili neskolko, po odnoi v stroke.'
            UiAddIcalLinks = 'Dobavit iCal ssylki'
            UiConnectedCalendars = 'Podklyuchennye kalendari'
            UiRemove = 'Udalit'
            UiClearAllCalendars = 'Ochistit vse'
            UiConfirmClear = 'Podtverdit'
            UiOpenGoogleCalendar = 'Otkryt Google Calendar'
            UiBackSettings = 'Nastroyki'
            UiDetectedCalendars = 'Naydennye kalendari'
            UiFeedPalette = 'Palitra lent (24)'
            UiSelectedFeed = 'Vybrana lenta'
            UiDisplaySettings = 'Nastroyki otobrazheniya'
            UiLanguagePrefix = 'Yazyk'
            UiLangEnglish = 'English'
            UiLangRussian = 'Russian'
            UiLangSpanish = 'Spanish'
            UiLangItalian = 'Italian'
            UiLangFrench = 'French'
            UiLangGerman = 'German'
            UiClockFormat = 'Format vremeni'
            UiTime12 = '12 chasov'
            UiTime24 = '24 chasa'
            UiEventDetails = 'Detali sobytiy'
            UiCalendar = 'Kalendar'
            UiLocation = 'Mesto'
            UiNotes = 'Zametki'
            UiTimelineScale = 'Masshtab'
            UiResetScale = 'Sbros 100%'
            UiRefreshInterval = 'Interval obnovleniya'
            UiRefresh1 = '1 min'
            UiRefresh5 = '5 min'
            UiRefresh10 = '10 min'
            UiRefresh15 = '15 min'
            UiLayoutTemplate = 'Shablon'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'Sinhronizatsiya'
            UiStatusText = 'Blipline obnovlyaetsya avtomaticheski. Posle izmeneniya lent nazhmite Obnovit.'
            UiPrivacyNote = 'Nazhmite tochku lenty i vyberite tsvet. Daylight - svetlaya tema. Phantom - prozrachnaya.'
        }
        es = @{
            UiSubtitle = 'Línea de agenda de Google Calendar / iCal'
            UiRefresh = 'Actualizar'
            UiOpen = 'Abrir'
            UiDemo = 'Demo'
            UiFeedImport = 'Importar calendarios'
            UiImportClipboard = 'Importar portapapeles'
            UiResetFeeds = 'Restablecer fuentes'
            UiImportHelp = 'Copia las URLs privadas de iCal, una por línea, e impórtalas juntas. Restablecer borra las fuentes guardadas y vuelve a la demo.'
            UiImportHelp1 = 'Copia las URLs privadas de iCal, una por línea.'
            UiImportHelp2 = 'Impórtalas juntas. Restablecer vuelve a la demo.'
            UiAddCalendars = 'Añadir calendarios'
            UiCalendarImportTitle = 'Añadir calendarios'
            UiCalendarImportHelp1 = 'Copia la dirección secreta en formato iCal desde Google Calendar.'
            UiCalendarImportHelp2 = 'Puedes copiar un enlace o varios, uno por línea.'
            UiAddIcalLinks = 'Añadir enlace(s) iCal'
            UiConnectedCalendars = 'Calendarios conectados'
            UiRemove = 'Quitar'
            UiClearAllCalendars = 'Borrar todo'
            UiConfirmClear = 'Confirmar borrado'
            UiOpenGoogleCalendar = 'Abrir Google Calendar'
            UiBackSettings = 'Ajustes'
            UiDetectedCalendars = 'Calendarios detectados'
            UiFeedPalette = 'Paleta de fuentes (24)'
            UiSelectedFeed = 'Fuente seleccionada'
            UiDisplaySettings = 'Opciones de pantalla'
            UiLanguagePrefix = 'Idioma'
            UiLangEnglish = 'Inglés'
            UiLangRussian = 'Ruso'
            UiLangSpanish = 'Español'
            UiLangItalian = 'Italiano'
            UiLangFrench = 'Francés'
            UiLangGerman = 'Alemán'
            UiClockFormat = 'Formato de hora'
            UiTime12 = '12 horas'
            UiTime24 = '24 horas'
            UiEventDetails = 'Detalles'
            UiCalendar = 'Calendario'
            UiLocation = 'Lugar'
            UiNotes = 'Notas'
            UiTimelineScale = 'Escala'
            UiResetScale = 'Restablecer 100%'
            UiRefreshInterval = 'Intervalo de actualización'
            UiRefresh1 = '1 min'
            UiRefresh5 = '5 min'
            UiRefresh10 = '10 min'
            UiRefresh15 = '15 min'
            UiLayoutTemplate = 'Plantilla'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'Estado de sincronización'
            UiStatusText = 'Blipline se actualiza automaticamente. Usa Actualizar despues de cambiar fuentes.'
            UiPrivacyNote = 'Haz clic en un punto de fuente y elige un color. Daylight es modo claro. Phantom es transparente.'
        }
        it = @{
            UiSubtitle = 'Timeline agenda Google Calendar / iCal'
            UiRefresh = 'Aggiorna'
            UiOpen = 'Apri'
            UiDemo = 'Demo'
            UiFeedImport = 'Importa calendari'
            UiImportClipboard = 'Importa appunti'
            UiResetFeeds = 'Reimposta feed'
            UiImportHelp = 'Copia gli URL iCal privati, uno per riga, poi importali insieme. Reimposta cancella i feed salvati e torna alla demo.'
            UiImportHelp1 = 'Copia gli URL iCal privati, uno per riga.'
            UiImportHelp2 = 'Importali insieme. Reimposta torna alla demo.'
            UiAddCalendars = 'Aggiungi calendari'
            UiCalendarImportTitle = 'Aggiungi calendari'
            UiCalendarImportHelp1 = 'Copia l''indirizzo segreto in formato iCal da Google Calendar.'
            UiCalendarImportHelp2 = 'Puoi copiare uno o più link, uno per riga.'
            UiAddIcalLinks = 'Aggiungi link iCal'
            UiConnectedCalendars = 'Calendari collegati'
            UiRemove = 'Rimuovi'
            UiClearAllCalendars = 'Cancella tutto'
            UiConfirmClear = 'Conferma'
            UiOpenGoogleCalendar = 'Apri Google Calendar'
            UiBackSettings = 'Impostazioni'
            UiDetectedCalendars = 'Calendari rilevati'
            UiFeedPalette = 'Palette feed (24)'
            UiSelectedFeed = 'Feed selezionato'
            UiDisplaySettings = 'Impostazioni display'
            UiLanguagePrefix = 'Lingua'
            UiLangEnglish = 'Inglese'
            UiLangRussian = 'Russo'
            UiLangSpanish = 'Spagnolo'
            UiLangItalian = 'Italiano'
            UiLangFrench = 'Francese'
            UiLangGerman = 'Tedesco'
            UiClockFormat = 'Formato ora'
            UiTime12 = '12 ore'
            UiTime24 = '24 ore'
            UiEventDetails = 'Dettagli eventi'
            UiCalendar = 'Calendario'
            UiLocation = 'Luogo'
            UiNotes = 'Note'
            UiTimelineScale = 'Scala'
            UiResetScale = 'Ripristina 100%'
            UiRefreshInterval = 'Intervallo aggiornamento'
            UiRefresh1 = '1 min'
            UiRefresh5 = '5 min'
            UiRefresh10 = '10 min'
            UiRefresh15 = '15 min'
            UiLayoutTemplate = 'Modello'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'Stato sync'
            UiStatusText = 'Blipline si aggiorna automaticamente. Usa Aggiorna dopo aver cambiato feed.'
            UiPrivacyNote = 'Clicca un punto feed e scegli un colore. Daylight è modalità chiara. Phantom è trasparente.'
        }
        fr = @{
            UiSubtitle = 'Chronologie Google Calendar / iCal'
            UiRefresh = 'Actualiser'
            UiOpen = 'Ouvrir'
            UiDemo = 'Démo'
            UiFeedImport = 'Importer des calendriers'
            UiImportClipboard = 'Importer le presse-papiers'
            UiResetFeeds = 'Réinitialiser les flux'
            UiImportHelp = 'Copiez les URL iCal privées, une par ligne, puis importez-les ensemble. Réinitialiser efface les flux et revient à la démo.'
            UiImportHelp1 = 'Copiez les URL iCal privées, une par ligne.'
            UiImportHelp2 = 'Importez-les ensemble. Réinitialiser revient à la démo.'
            UiAddCalendars = 'Ajouter des calendriers'
            UiCalendarImportTitle = 'Ajouter des calendriers'
            UiCalendarImportHelp1 = 'Copiez l''adresse secrète au format iCal depuis Google Calendar.'
            UiCalendarImportHelp2 = 'Vous pouvez copier un lien ou plusieurs, un par ligne.'
            UiAddIcalLinks = 'Ajouter lien(s) iCal'
            UiConnectedCalendars = 'Calendriers connectés'
            UiRemove = 'Supprimer'
            UiClearAllCalendars = 'Tout effacer'
            UiConfirmClear = 'Confirmer'
            UiOpenGoogleCalendar = 'Ouvrir Google Calendar'
            UiBackSettings = 'Paramètres'
            UiDetectedCalendars = 'Calendriers détectés'
            UiFeedPalette = 'Palette des flux (24)'
            UiSelectedFeed = 'Flux sélectionné'
            UiDisplaySettings = 'Paramètres d''affichage'
            UiLanguagePrefix = 'Langue'
            UiLangEnglish = 'Anglais'
            UiLangRussian = 'Russe'
            UiLangSpanish = 'Espagnol'
            UiLangItalian = 'Italien'
            UiLangFrench = 'Français'
            UiLangGerman = 'Allemand'
            UiClockFormat = 'Format horaire'
            UiTime12 = '12 h'
            UiTime24 = '24 h'
            UiEventDetails = 'Détails'
            UiCalendar = 'Calendrier'
            UiLocation = 'Lieu'
            UiNotes = 'Notes'
            UiTimelineScale = 'Échelle'
            UiResetScale = 'Réinit. 100%'
            UiRefreshInterval = 'Intervalle d''actualisation'
            UiRefresh1 = '1 min'
            UiRefresh5 = '5 min'
            UiRefresh10 = '10 min'
            UiRefresh15 = '15 min'
            UiLayoutTemplate = 'Modèle'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'État de synchro'
            UiStatusText = 'Blipline s''actualise automatiquement. Utilisez Actualiser après modification des flux.'
            UiPrivacyNote = 'Cliquez un point de flux et choisissez une couleur. Daylight est clair. Phantom est transparent.'
        }
        de = @{
            UiSubtitle = 'Google Calendar / iCal Agenda-Zeitleiste'
            UiRefresh = 'Aktualisieren'
            UiOpen = 'Öffnen'
            UiDemo = 'Demo'
            UiFeedImport = 'Kalender importieren'
            UiImportClipboard = 'Zwischenablage importieren'
            UiResetFeeds = 'Feeds zurücksetzen'
            UiImportHelp = 'Private iCal-URLs je eine pro Zeile kopieren und gemeinsam importieren. Zurücksetzen löscht gespeicherte Feeds und zeigt Demo-Daten.'
            UiImportHelp1 = 'Private iCal-URLs je eine pro Zeile kopieren.'
            UiImportHelp2 = 'Gemeinsam importieren. Zurücksetzen zeigt Demo-Daten.'
            UiAddCalendars = 'Kalender hinzufügen'
            UiCalendarImportTitle = 'Kalender hinzufügen'
            UiCalendarImportHelp1 = 'Geheime Adresse im iCal-Format aus Google Calendar kopieren.'
            UiCalendarImportHelp2 = 'Ein Link oder mehrere Links, je einer pro Zeile.'
            UiAddIcalLinks = 'iCal-Link(s) hinzufügen'
            UiConnectedCalendars = 'Verbundene Kalender'
            UiRemove = 'Entfernen'
            UiClearAllCalendars = 'Alle löschen'
            UiConfirmClear = 'Bestätigen'
            UiOpenGoogleCalendar = 'Google Calendar öffnen'
            UiBackSettings = 'Einstellungen'
            UiDetectedCalendars = 'Erkannte Kalender'
            UiFeedPalette = 'Feed-Farbpalette (24)'
            UiSelectedFeed = 'Gewählter Feed'
            UiDisplaySettings = 'Anzeigeoptionen'
            UiLanguagePrefix = 'Sprache'
            UiLangEnglish = 'Englisch'
            UiLangRussian = 'Russisch'
            UiLangSpanish = 'Spanisch'
            UiLangItalian = 'Italienisch'
            UiLangFrench = 'Französisch'
            UiLangGerman = 'Deutsch'
            UiClockFormat = 'Zeitformat'
            UiTime12 = '12 Std.'
            UiTime24 = '24 Std.'
            UiEventDetails = 'Ereignisdetails'
            UiCalendar = 'Kalender'
            UiLocation = 'Ort'
            UiNotes = 'Notizen'
            UiTimelineScale = 'Skalierung'
            UiResetScale = '100% zurück'
            UiRefreshInterval = 'Aktualisierungsintervall'
            UiRefresh1 = '1 Min.'
            UiRefresh5 = '5 Min.'
            UiRefresh10 = '10 Min.'
            UiRefresh15 = '15 Min.'
            UiLayoutTemplate = 'Vorlage'
            UiTemplateClassic = 'Classic'
            UiTemplateCommand = 'Command'
            UiTemplateLedger = 'Ledger'
            UiTemplateMetro = 'Metro'
            UiTemplateStudio = 'Studio'
            UiTemplateDaylight = 'Daylight'
            UiTemplatePhantom = 'Phantom'
            UiSyncStatus = 'Sync-Status'
            UiStatusText = 'Blipline aktualisiert automatisch. Nach Feed-Aenderungen Aktualisieren nutzen.'
            UiPrivacyNote = 'Feed-Punkt anklicken und Farbe wählen. Daylight ist hell. Phantom ist transparent.'
        }
    }

    if (!$labels.ContainsKey($Code)) {
        return $labels.en
    }

    return $labels[$Code]
}

if ([string]::IsNullOrWhiteSpace($SettingsPath) -or !(Test-Path -LiteralPath $SettingsPath)) {
    exit 1
}

$nameClean = $Name.Trim()
$valueClean = $Value.Trim()
$settingsEncoding = Get-RainmeterIncludeEncoding
$lines = @([System.IO.File]::ReadAllLines($SettingsPath, $settingsEncoding))

if ($nameClean -eq 'Language') {
    $allowed = @('en', 'ru', 'es', 'it', 'fr', 'de')
    $code = $valueClean.ToLowerInvariant()
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
