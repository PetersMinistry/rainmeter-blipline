param(
    [string]$SettingsPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

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
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match $pattern) {
            return $matches[1].Trim()
        }
    }

    return $Default
}

function Convert-IcsText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }

    return $Text.Replace('\n', ' ').Replace('\N', ' ').Replace('\,', ',').Replace('\;', ';').Replace('\\', '\').Trim()
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
        [bool]$AllDay,
        [string]$Color
    )

    [pscustomobject]@{
        Start = $Start
        End = $End
        Title = $Title
        Location = $Location
        AllDay = $AllDay
        Color = $Color
    }
}

function Get-SampleEvents {
    $now = Get-Date
    $base = Get-Date -Hour $now.Hour -Minute 0 -Second 0
    $next = $now.AddMinutes(15)

    @(
        New-EventObject -Start $base.AddHours(-2) -End $base.AddHours(-1).AddMinutes(-15) -Title 'Morning Focus' -Location '' -AllDay:$false -Color '205,214,224,230'
        New-EventObject -Start $base.AddHours(-1) -End $base.AddMinutes(-15) -Title 'Deep Work' -Location '' -AllDay:$false -Color '205,214,224,230'
        New-EventObject -Start $next -End $next.AddMinutes(45) -Title 'Team Sync' -Location 'Conference Room A' -AllDay:$false -Color '255,199,50,255'
        New-EventObject -Start $next.AddHours(1.5) -End $next.AddHours(2.25) -Title 'Lunch' -Location '' -AllDay:$false -Color '205,214,224,230'
        New-EventObject -Start $next.AddHours(3) -End $next.AddHours(4) -Title 'Design Review' -Location 'Studio call' -AllDay:$false -Color '104,170,255,245'
        New-EventObject -Start $next.AddHours(5) -End $next.AddHours(5.5) -Title 'Client Call' -Location '' -AllDay:$false -Color '126,220,117,245'
        New-EventObject -Start $next.AddHours(7.5) -End $next.AddHours(8) -Title 'Wrap Up' -Location '' -AllDay:$false -Color '205,214,224,230'
        New-EventObject -Start (Get-Date).Date.AddDays(1).AddHours(9) -End (Get-Date).Date.AddDays(1).AddHours(10) -Title 'Tomorrow Planning' -Location '' -AllDay:$false -Color '238,120,150,245'
    )
}

function Parse-IcsEvents {
    param([string]$Content)

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
            $start = Convert-IcsDate $current['DTSTART']
            $end = Convert-IcsDate $current['DTEND']
            if ($start) {
                $allDay = $current['DTSTART_ALLDAY'] -eq '1'
                if (!$end) {
                    $end = if ($allDay) { $start.AddDays(1) } else { $start.AddMinutes(30) }
                }
                $title = Convert-IcsText $current['SUMMARY']
                if (!$title) { $title = 'Calendar event' }
                $location = Convert-IcsText $current['LOCATION']
                $events.Add((New-EventObject -Start $start -End $end -Title $title -Location $location -AllDay:$allDay -Color '205,214,224,230'))
            }
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
        elseif ($name -eq 'SUMMARY' -or $name -eq 'LOCATION') {
            $current[$name] = $value
        }
    }

    return @($events)
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
    $daysAhead = [int](Get-SettingValue -Path $SettingsPath -Name 'DaysAhead' -Default '3')
    $windowEnd = $today.AddDays([Math]::Max(1, $daysAhead))
    $sorted = @($Events | Where-Object { $_.End -ge $today } | Sort-Object Start)
    $filtered = @($sorted | Where-Object { $_.Start -lt $windowEnd } | Select-Object -First 24)
    $nextFuture = @($sorted | Where-Object { $_.End -ge $now } | Select-Object -First 1)

    if ($filtered.Count -eq 0 -and $nextFuture.Count -gt 0) {
        $filtered = $nextFuture
    }
    elseif ($nextFuture.Count -gt 0 -and -not ($filtered | Where-Object { $_.Start -eq $nextFuture[0].Start -and $_.Title -eq $nextFuture[0].Title })) {
        $filtered = @($filtered + $nextFuture[0] | Sort-Object Start | Select-Object -First 24)
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('[Variables]')
    $lines.Add(('LastUpdated={0}' -f (Get-Date -Format 'h:mm tt')))
    $lines.Add(('SourceStatus={0}' -f $Status))
    $lines.Add(('EventCount={0}' -f $filtered.Count))

    $colors = @('205,214,224,230', '255,199,50,255', '104,170,255,245', '126,220,117,245', '238,120,150,245')
    for ($i = 0; $i -lt $filtered.Count; $i++) {
        $n = $i + 1
        $event = $filtered[$i]
        $color = if ($event.Color) { $event.Color } else { $colors[$i % $colors.Count] }
        $time = if ($event.AllDay) { 'All day' } else { $event.Start.ToString('h:mm tt') }
        $endTime = if ($event.AllDay) { '' } else { $event.End.ToString('h:mm tt') }
        $dateLabel = $event.Start.ToString('ddd  dd MMM').ToUpperInvariant()

        $lines.Add(("Event{0}Title={1}" -f $n, ($event.Title -replace '[\r\n=]', ' ')))
        $lines.Add(("Event{0}Location={1}" -f $n, ($event.Location -replace '[\r\n=]', ' ')))
        $lines.Add(("Event{0}Time={1}" -f $n, $time))
        $lines.Add(("Event{0}EndTime={1}" -f $n, $endTime))
        $lines.Add(("Event{0}Date={1}" -f $n, $dateLabel))
        $lines.Add(("Event{0}StartEpoch={1}" -f $n, (Get-UnixSeconds $event.Start)))
        $lines.Add(("Event{0}EndEpoch={1}" -f $n, (Get-UnixSeconds $event.End)))
        $lines.Add(("Event{0}AllDay={1}" -f $n, ($(if ($event.AllDay) { 1 } else { 0 }))))
        $lines.Add(("Event{0}Color={1}" -f $n, $color))
    }

    Set-Content -LiteralPath $Path -Value $lines -Encoding ASCII
}

try {
    $calendarUrl = Get-SettingValue -Path $SettingsPath -Name 'CalendarUrl'

    if ([string]::IsNullOrWhiteSpace($calendarUrl)) {
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Sample data'
        exit 0
    }

    $response = Invoke-WebRequest -Uri $calendarUrl -UseBasicParsing -TimeoutSec 25
    $events = Parse-IcsEvents -Content $response.Content
    Write-AgendaCache -Events $events -Path $OutputPath -Status 'Calendar updated'
}
catch {
    Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status ("Refresh failed - sample data")
    exit 1
}
