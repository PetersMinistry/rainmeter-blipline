param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Read-CacheVars {
    param([string]$Path)

    $vars = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^([^=]+)=(.*)$') {
            $vars[$matches[1]] = $matches[2]
        }
    }
    return $vars
}

$scriptPath = Join-Path $ProjectRoot 'Skins\Blipline\@Resources\Scripts\Update-Agenda.ps1'
$tempRoot = Join-Path $env:TEMP ('BliplineTest-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    $sampleSettings = Join-Path $tempRoot 'sample-settings.inc'
    $sampleOutput = Join-Path $tempRoot 'sample-agenda.inc'
    Set-Content -LiteralPath $sampleSettings -Encoding ASCII -Value @(
        '[Variables]'
        'CalendarUrl='
        'CalendarUrl2='
        'CalendarUrl3='
        'DaysAhead=3'
    )

    & $scriptPath -SettingsPath $sampleSettings -OutputPath $sampleOutput
    $sampleVars = Read-CacheVars -Path $sampleOutput
    Assert-True ($sampleVars['SourceStatus'] -eq 'Sample data') 'Sample mode did not report Sample data.'
    Assert-True ([int]$sampleVars['EventCount'] -ge 6) 'Sample mode produced too few events.'

    $today = (Get-Date).Date
    $tomorrow = $today.AddDays(1)
    $dailyStart = $tomorrow.AddHours(9)
    $dailyEnd = $tomorrow.AddHours(9).AddMinutes(30)
    $excluded = $dailyStart.AddDays(1).ToString("yyyyMMdd'T'HHmmss")
    $singleStart = $tomorrow.AddHours(13)
    $singleEnd = $tomorrow.AddHours(14)
    $allDay = $tomorrow.AddDays(2).ToString('yyyyMMdd')

    $fixturePath = Join-Path $tempRoot 'fixture.ics'
    Set-Content -LiteralPath $fixturePath -Encoding ASCII -Value @(
        'BEGIN:VCALENDAR'
        'VERSION:2.0'
        'PRODID:-//PetersMinistry//Blipline Test//EN'
        'X-WR-CALNAME:Fixture Work'
        'BEGIN:VEVENT'
        'UID:daily-1@example.test'
        ('DTSTART:{0}' -f $dailyStart.ToString("yyyyMMdd'T'HHmmss"))
        ('DTEND:{0}' -f $dailyEnd.ToString("yyyyMMdd'T'HHmmss"))
        'RRULE:FREQ=DAILY;COUNT=3'
        ('EXDATE:{0}' -f $excluded)
        'SUMMARY:Daily Standup'
        'LOCATION:Studio A'
        'END:VEVENT'
        'BEGIN:VEVENT'
        'UID:unicode-1@example.test'
        ('DTSTART:{0}' -f $tomorrow.AddHours(11).ToString("yyyyMMdd'T'HHmmss"))
        ('DTEND:{0}' -f $tomorrow.AddHours(12).ToString("yyyyMMdd'T'HHmmss"))
        'SUMMARY:Coffee & Grace'
        'LOCATION:Cafe'
        'END:VEVENT'
        'BEGIN:VEVENT'
        'UID:single-1@example.test'
        ('DTSTART:{0}' -f $singleStart.ToString("yyyyMMdd'T'HHmmss"))
        ('DTEND:{0}' -f $singleEnd.ToString("yyyyMMdd'T'HHmmss"))
        'SUMMARY:Client Review'
        'LOCATION:Conference Room'
        'END:VEVENT'
        'BEGIN:VEVENT'
        'UID:all-day-1@example.test'
        ('DTSTART;VALUE=DATE:{0}' -f $allDay)
        ('DTEND;VALUE=DATE:{0}' -f $tomorrow.AddDays(3).ToString('yyyyMMdd'))
        'SUMMARY:All Day Planning'
        'END:VEVENT'
        'BEGIN:VEVENT'
        'UID:cancelled-1@example.test'
        ('DTSTART:{0}' -f $tomorrow.AddHours(15).ToString("yyyyMMdd'T'HHmmss"))
        ('DTEND:{0}' -f $tomorrow.AddHours(16).ToString("yyyyMMdd'T'HHmmss"))
        'STATUS:CANCELLED'
        'SUMMARY:Cancelled Meeting'
        'END:VEVENT'
        'BEGIN:VEVENT'
        'UID:cancelled-title-1@example.test'
        ('DTSTART:{0}' -f $tomorrow.AddHours(17).ToString("yyyyMMdd'T'HHmmss"))
        ('DTEND:{0}' -f $tomorrow.AddHours(18).ToString("yyyyMMdd'T'HHmmss"))
        'SUMMARY:Cancelled - Old Sync'
        'END:VEVENT'
        'END:VCALENDAR'
    )

    $feedSettings = Join-Path $tempRoot 'feed-settings.inc'
    $feedOutput = Join-Path $tempRoot 'feed-agenda.inc'
    Set-Content -LiteralPath $feedSettings -Encoding ASCII -Value @(
        '[Variables]'
        ('CalendarUrl={0}' -f $fixturePath)
        'CalendarUrl2='
        'CalendarUrl3='
        'CalendarName1='
        'CalendarColor1=255,199,50,255'
        'DaysAhead=7'
    )

    & $scriptPath -SettingsPath $feedSettings -OutputPath $feedOutput
    $feedText = Get-Content -LiteralPath $feedOutput -Raw
    $feedVars = Read-CacheVars -Path $feedOutput
    Assert-True ($feedVars['SourceStatus'] -eq 'Updated 1 feed(s)') 'Fixture feed did not refresh successfully.'
    Assert-True ($feedText -match 'Event\d+Calendar=Fixture Work') 'Calendar name was not auto-detected.'
    Assert-True ($feedText -match 'Daily Standup') 'Recurring daily event was not expanded.'
    Assert-True ($feedText -match 'Coffee & Grace') 'Special characters were not preserved.'
    Assert-True ($feedText -match 'Client Review') 'Single event was not imported.'
    Assert-True ($feedText -match 'All Day Planning') 'All-day event was not imported.'
    Assert-True ($feedText -notmatch 'Cancelled Meeting') 'Cancelled event was imported.'
    Assert-True ($feedText -notmatch 'Old Sync') 'Title-level cancelled event was imported.'
    Assert-True ($feedText -notmatch [regex]::Escape($excluded)) 'Excluded recurring date still appeared.'

    Write-Host 'Blipline agenda pipeline tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
