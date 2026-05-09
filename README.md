# Blipline

A Rainmeter agenda timeline for Google Calendar-style iCal feeds.

## Purpose

Blipline is a practical desktop schedule skin. It shows calendar items in a scrollable timeline, keeps a next-event countdown visible, and starts centered around the current or next event.

## Features

- Timeline-style agenda display with a highlighted current or next event.
- Side countdown tag for the next event or the active event end time.
- Mouse-wheel scrolling through cached past and future events.
- Countdown tag stays clamped within the timeline while pointing at the current/next event position.
- Sample-data mode when no calendar feed is connected.
- Safe Demo mode for sample data without deleting saved calendar feed URLs.
- Settings panel with refresh, open, demo, visual style, and up to three private iCal URL entries.
- Google Calendar private iCal / ICS feed support.
- Merged agenda view across multiple calendar feeds.
- Calendar names are auto-detected from iCal feeds when available.
- Basic recurring event expansion for daily, weekly, and monthly iCal rules.
- Timed events sort ahead of all-day entries on the same date to keep appointment-style schedules readable.
- 15-minute automatic refresh with manual refresh in settings.
- Visual style presets currently include Glass, Dense, and Focus.

If no Google Calendar iCal URL is set, the skin generates sample events around the current time so the layout can be tested immediately.

## Load Paths

```text
Blipline\Timeline\Timeline.ini
Blipline\Control\Settings.ini
```

## Google Calendar Setup

Open the settings panel and paste a Google Calendar private iCal URL into one of the calendar feed fields. Blipline currently supports up to three feeds.

The raw setting lives here:

```text
Skins\Blipline\@Resources\UserSettings.inc
```

Set:

```ini
CalendarUrl=https://calendar.google.com/calendar/ical/...
```

Optional display tuning:

```ini
MaxRows=6
CacheLimit=240
CachePastDays=14
CacheFutureDays=90
ScrollStep=1
TimelineStyle=Glass
```

Treat that URL as private. Anyone with the secret iCal URL can read that calendar feed.

Use the Demo button to preview sample data without removing saved feed URLs. Use Refresh to return to live calendar data.

## Privacy Notes

- Private iCal URLs are not committed to this repo.
- Generated agenda cache files are ignored because they may contain event names, locations, and meeting details.
- The committed `UserSettings.inc` uses blank calendar URLs for safe packaging.
- If you connect a real calendar in the live Rainmeter skin, avoid copying the repo default `UserSettings.inc` over your live one.
- `FetchHelperPath` can point to a local Python executable if Windows PowerShell cannot fetch Google Calendar over HTTPS on a specific machine. Leave it blank for packaging.

## Local Verification

Run the agenda pipeline test from the repo root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AgendaPipeline.ps1
```

The test uses temporary fake calendar data only. It does not require or expose a real calendar URL.

## Status

Working local prototype. Not packaged for release yet.
