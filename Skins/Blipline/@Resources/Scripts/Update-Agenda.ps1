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

function New-ShiftedEvent {
    param(
        [object]$Event,
        [datetime]$Start
    )

    $duration = $Event.End - $Event.Start
    New-EventObject -Start $Start -End $Start.Add($duration) -Title $Event.Title -Location $Event.Location -AllDay:$Event.AllDay -Color $Event.Color -Calendar $Event.Calendar
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
    if ($freq -notin @('DAILY', 'WEEKLY', 'MONTHLY')) {
        return @($Event)
    }

    $interval = 1
    if ($rule.ContainsKey('INTERVAL')) {
        $interval = [Math]::Max(1, [int]$rule['INTERVAL'])
    }

    $countLimit = if ($rule.ContainsKey('COUNT')) { [int]$rule['COUNT'] } else { 0 }
    $until = if ($rule.ContainsKey('UNTIL')) { Convert-IcsDate $rule['UNTIL'] } else { $null }
    $byDay = if ($rule.ContainsKey('BYDAY')) { $rule['BYDAY'] } else { '' }
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
            $candidate = $candidate.AddMonths($interval)
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
        [bool]$AllDay,
        [string]$Color,
        [string]$Calendar
    )

    [pscustomobject]@{
        Start = $Start
        End = $End
        Title = $Title
        Location = $Location
        AllDay = $AllDay
        Color = $Color
        Calendar = $Calendar
    }
}

function Get-SampleEvents {
    $now = Get-Date
    $base = Get-Date -Hour $now.Hour -Minute 0 -Second 0
    $next = $now.AddMinutes(15)

    @(
        New-EventObject -Start $base.AddHours(-2) -End $base.AddHours(-1).AddMinutes(-15) -Title 'Morning Focus' -Location '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start $base.AddHours(-1) -End $base.AddMinutes(-15) -Title 'Deep Work' -Location '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start $next -End $next.AddMinutes(45) -Title 'Team Sync' -Location 'Conference Room A' -AllDay:$false -Color '255,199,50,255' -Calendar 'Work'
        New-EventObject -Start $next.AddHours(1.5) -End $next.AddHours(2.25) -Title 'Lunch' -Location '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Personal'
        New-EventObject -Start $next.AddHours(3) -End $next.AddHours(4) -Title 'Design Review' -Location 'Studio call' -AllDay:$false -Color '104,170,255,245' -Calendar 'Work'
        New-EventObject -Start $next.AddHours(5) -End $next.AddHours(5.5) -Title 'Client Call' -Location '' -AllDay:$false -Color '126,220,117,245' -Calendar 'Clients'
        New-EventObject -Start $next.AddHours(7.5) -End $next.AddHours(8) -Title 'Wrap Up' -Location '' -AllDay:$false -Color '205,214,224,230' -Calendar 'Focus'
        New-EventObject -Start (Get-Date).Date.AddDays(1).AddHours(9) -End (Get-Date).Date.AddDays(1).AddHours(10) -Title 'Tomorrow Planning' -Location '' -AllDay:$false -Color '238,120,150,245' -Calendar 'Planning'
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
            $status = ''
            if ($current.ContainsKey('STATUS')) {
                $status = $current['STATUS'].ToUpperInvariant()
            }
            if ($status -eq 'CANCELLED') {
                continue
            }

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
                $baseEvent = New-EventObject -Start $start -End $end -Title $title -Location $location -AllDay:$allDay -Color $Color -Calendar $CalendarName
                foreach ($event in (Expand-IcsEvent -Event $baseEvent -RuleText $current['RRULE'] -ExDates @($current['EXDATE']) -WindowStart $WindowStart -WindowEnd $WindowEnd)) {
                    $events.Add($event)
                }
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

function Get-CalendarFeeds {
    param([string]$Path)

    $feeds = @()
    for ($i = 1; $i -le 3; $i++) {
        $urlKey = if ($i -eq 1) { 'CalendarUrl' } else { "CalendarUrl$i" }
        $url = Get-SettingValue -Path $Path -Name $urlKey
        if ([string]::IsNullOrWhiteSpace($url)) { continue }

        $feeds += [pscustomobject]@{
            Url = $url
            Name = Get-SettingValue -Path $Path -Name "CalendarName$i"
            FallbackName = "Calendar $i"
            Color = Get-SettingValue -Path $Path -Name "CalendarColor$i" -Default '205,214,224,230'
        }
    }

    return $feeds
}

function Get-CalendarContent {
    param([string]$Source)

    if (Test-Path -LiteralPath $Source) {
        return Get-Content -LiteralPath $Source -Raw
    }

    $response = Invoke-WebRequest -Uri $Source -UseBasicParsing -TimeoutSec 25
    return $response.Content
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
        $lines.Add(("Event{0}Calendar={1}" -f $n, ($event.Calendar -replace '[\r\n=]', ' ')))
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
    $feeds = @(Get-CalendarFeeds -Path $SettingsPath)
    $today = (Get-Date).Date
    $daysAhead = [int](Get-SettingValue -Path $SettingsPath -Name 'DaysAhead' -Default '3')
    $parseWindowStart = $today.AddDays(-7)
    $parseWindowEnd = $today.AddDays([Math]::Max(31, $daysAhead + 7))

    if ($feeds.Count -eq 0) {
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Sample data'
        return
    }

    $allEvents = New-Object System.Collections.Generic.List[object]
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

            $events = Parse-IcsEvents -Content $content -CalendarName $calendarName -Color $feed.Color -WindowStart $parseWindowStart -WindowEnd $parseWindowEnd
            foreach ($event in $events) { $allEvents.Add($event) }
            $successCount++
        }
        catch {
            $failureCount++
        }
    }

    if ($successCount -eq 0) {
        Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status 'Refresh failed - sample data'
        return
    }

    $status = if ($failureCount -gt 0) {
        "Updated $successCount feed(s), $failureCount failed"
    }
    else {
        "Updated $successCount feed(s)"
    }
    Write-AgendaCache -Events $allEvents.ToArray() -Path $OutputPath -Status $status
}
catch {
    Write-AgendaCache -Events (Get-SampleEvents) -Path $OutputPath -Status ("Refresh failed - sample data")
    return
}
