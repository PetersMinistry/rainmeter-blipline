$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipPath = Join-Path $PSScriptRoot 'Blipline_0.3.23-beta.zip'
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)

try {
    $required = @(
        'RMSKIN.ini',
        'Skins/Blipline/Control/Settings.ini',
        'Skins/Blipline/Control/Import.ini',
        'Skins/Blipline/Timeline/Timeline.ini',
        'Skins/Blipline/@Resources/UserSettings.inc',
        'Skins/Blipline/@Resources/Scripts/Update-Agenda.ps1',
        'Skins/Blipline/@Resources/Scripts/Timeline.lua',
        'Skins/Blipline/@Resources/Scripts/Localization.ps1',
        'Skins/Blipline/@Resources/Scripts/Apply-DisplaySetting.vbs',
        'Skins/Blipline/@Resources/Scripts/Import-FeedList.ps1',
        'Skins/Blipline/@Resources/Scripts/Prompt-UiScale.ps1',
        'Skins/Blipline/@Resources/Locales/en.ini',
        'Skins/Blipline/@Resources/Locales/ru.ini',
        'Skins/Blipline/@Resources/Locales/es.ini',
        'Skins/Blipline/@Resources/Locales/it.ini',
        'Skins/Blipline/@Resources/Locales/fr.ini',
        'Skins/Blipline/@Resources/Locales/de.ini',
        'Skins/Blipline/@Resources/Images/Icons/birthday.png',
        'Skins/Blipline/@Resources/Images/Icons/blank.png',
        'Skins/Blipline/@Resources/Images/Icons/book.png',
        'Skins/Blipline/@Resources/Images/Icons/butterfly.png',
        'Skins/Blipline/@Resources/Images/Icons/candle.png',
        'Skins/Blipline/@Resources/Images/Icons/cross.png',
        'Skins/Blipline/@Resources/Images/Icons/fallback.png',
        'Skins/Blipline/@Resources/Images/Icons/flower.png',
        'Skins/Blipline/@Resources/Images/Icons/iron.png',
        'Skins/Blipline/@Resources/Images/Icons/meal.png',
        'Skins/Blipline/@Resources/Images/Icons/sun.png'
    )

    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    $missing = @($required | Where-Object { $_ -notin $names })
    if ($missing.Count) {
        throw ('Missing required package entries: ' + ($missing -join ', '))
    }

    $forbidden = @($names | Where-Object {
        $_ -match '(^|/)\.git' -or
        $_ -match 'HANDOFF' -or
        $_ -match 'dist/' -or
        $_ -match 'docs/' -or
        $_ -match 'tools/' -or
        $_ -match 'Agenda\.inc' -or
        $_ -match 'DebugAgenda\.inc' -or
        $_ -match '\.rmskin$' -or
        $_ -match '\.zip$' -or
        $_ -match '\.gitkeep$'
    })
    if ($forbidden.Count) {
        throw ('Forbidden entries: ' + ($forbidden -join ', '))
    }

    $patterns = @(
        'calendar\.google\.com/calendar/ical',
        '/private-[^/\s]+/',
        'C:\\Users\\Peter',
        'codex-runtimes',
        'Event\d+Title=',
        'BEGIN:VCALENDAR'
    )

    foreach ($entry in $zip.Entries) {
        if ($entry.Length -gt 0 -and $entry.FullName -match '\.(ini|inc|ps1|lua|md)$') {
            $reader = [System.IO.StreamReader]::new($entry.Open())
            $text = $reader.ReadToEnd()
            $reader.Dispose()
            foreach ($pattern in $patterns) {
                if ($text -match $pattern) {
                    throw "Sensitive pattern '$pattern' in $($entry.FullName)"
                }
            }
        }
    }

    "Package inspection passed. Entries=$($names.Count)"
}
finally {
    $zip.Dispose()
}
