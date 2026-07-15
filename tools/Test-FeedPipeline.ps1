$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$updateScript = Join-Path $projectRoot 'Skins\Blipline\@Resources\Scripts\Update-Agenda.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('BliplineFeedPipeline-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($testRoot)

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-FeedCase {
    param(
        [string]$Name,
        [string]$Ics,
        [string]$ExpectedResult
    )

    $feedPath = Join-Path $testRoot "$Name.ics"
    $settingsPath = Join-Path $testRoot "$Name.inc"
    $outputPath = Join-Path $testRoot "$Name-agenda.inc"
    Write-Utf8File -Path $feedPath -Content $Ics
    Write-Utf8File -Path $settingsPath -Content "[Variables]`r`nCalendarSlots=3`r`nCalendarUrl=$feedPath`r`nUseSample=0`r`nCachePastDays=14`r`nCacheFutureDays=90`r`n"

    & $updateScript -SettingsPath $settingsPath -OutputPath $outputPath
    $actual = @(Get-Content -LiteralPath $settingsPath | Where-Object { $_ -like 'Feed1Result=*' } | Select-Object -First 1)[0]
    if ($actual -ne "Feed1Result=$ExpectedResult") {
        throw "$Name returned '$actual'; expected 'Feed1Result=$ExpectedResult'."
    }
}

try {
    $header = "BEGIN:VCALENDAR`r`nVERSION:2.0`r`n"
    $footer = "END:VCALENDAR`r`n"
    Invoke-FeedCase -Name 'monthly-weekdays' -ExpectedResult 'OK' -Ics ($header + @"
BEGIN:VEVENT
UID:monthly-weekdays@test
DTSTART:20260715T090000
DTEND:20260715T093000
RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1
SUMMARY:Last weekday
END:VEVENT
"@ + "`r`n" + $footer)

    Invoke-FeedCase -Name 'monthly-fifth' -ExpectedResult 'OK' -Ics ($header + @"
BEGIN:VEVENT
UID:monthly-fifth@test
DTSTART:20260729T090000
DTEND:20260729T093000
RRULE:FREQ=MONTHLY;BYDAY=5WE
SUMMARY:Fifth Wednesday
END:VEVENT
"@ + "`r`n" + $footer)

    Invoke-FeedCase -Name 'bad-rule' -ExpectedResult 'Failed: calendar data error' -Ics ($header + @"
BEGIN:VEVENT
UID:bad-rule@test
DTSTART:20260715T090000
DTEND:20260715T093000
RRULE:FREQ=DAILY;COUNT=abc
SUMMARY:Bad recurrence
END:VEVENT
"@ + "`r`n" + $footer)

    Write-Output 'Blipline feed pipeline tests passed.'
}
finally {
    if (([System.IO.Path]::GetFullPath($testRoot)).StartsWith([System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
