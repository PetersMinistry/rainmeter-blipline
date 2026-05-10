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
- Settings panel with refresh, open, demo, clipboard feed import, layout templates, event-detail toggles, and per-feed color palette controls.
- Google Calendar private iCal / ICS feed support.
- Up to eight iCal feed slots are supported in `UserSettings.inc`; the setup panel imports multiple feed URLs from the clipboard.
- Merged agenda view across multiple calendar feeds.
- Calendar names are auto-detected from iCal feeds when available.
- Calendar colors are auto-detected when a feed publishes color metadata, otherwise Blipline uses the configured feed colors.
- Basic recurring event expansion for daily, weekly, and monthly iCal rules.
- Event descriptions/notes are imported for richer Dense display.
- Unicode and emoji in event titles/details are preserved.
- Timed events sort ahead of all-day entries on the same date to keep appointment-style schedules readable.
- 15-minute automatic refresh with manual refresh in settings.
- Layout templates currently include Classic, Command, Ledger, Metro, Studio, and Daylight.

If no Google Calendar iCal URL is set, the skin generates sample events around the current time so the layout can be tested immediately.

## Load Paths

```text
Blipline\Timeline\Timeline.ini
Blipline\Control\Settings.ini
```

## Google Calendar Setup

Open the settings panel, copy one or more Google Calendar private iCal URLs to the clipboard, one per line, then click Import Clipboard. Blipline currently supports up to eight feed slots.

The raw setting lives here:

```text
Skins\Blipline\@Resources\UserSettings.inc
```

The committed release defaults keep all feed URL values blank:

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
CalendarSlots=8
CalendarColor1=255,199,50,255
```

Treat that URL as private. Anyone with the secret iCal URL can read that calendar feed.

Use the Demo button to preview sample data without removing saved feed URLs. Use Refresh to return to live calendar data.

## Privacy Notes

- Private iCal URLs are not committed to this repo.
- Generated agenda cache files are ignored because they may contain event names, locations, and meeting details.
- The committed `UserSettings.inc` uses blank calendar URLs for safe packaging.
- Build release packages from the Git-tracked source tree, not from the live Rainmeter install folder, because the live folder contains personal feed URLs, cache files, and machine-local helper paths.
- If you connect a real calendar in the live Rainmeter skin, avoid copying the repo default `UserSettings.inc` over your live one.
- `FetchHelperPath` can point to a local Python executable if Windows PowerShell cannot fetch Google Calendar over HTTPS on a specific machine. Leave it blank for packaging.

## Local Verification

Run the agenda pipeline test from the repo root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AgendaPipeline.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-ReleasePrivacy.ps1
```

The agenda test uses temporary fake calendar data only. The release privacy test verifies blank feed URLs, blank helper paths, empty runtime feed status values, and no generated cache files in the source package folder.

## Status

Working local prototype. Not packaged for release yet.
