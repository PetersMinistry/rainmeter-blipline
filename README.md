# Blipline

A Rainmeter agenda timeline for Google Calendar-style iCal feeds.

## Purpose

Blipline is a practical desktop schedule skin. It shows upcoming agenda items, keeps a next-event countdown visible, and automatically shifts the visible timeline as the day progresses.

## Features

- Timeline-style agenda display with a highlighted current or next event.
- Side countdown tag for the next event or the active event end time.
- Today, 3 Days, and Week range options.
- Sample-data mode when no calendar feed is connected.
- Settings panel with refresh, sample reset, and up to three private iCal URL entries.
- Google Calendar private iCal / ICS feed support.
- Merged agenda view across multiple calendar feeds.
- Calendar names are auto-detected from iCal feeds when available.
- 15-minute automatic refresh with manual refresh in settings.

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

Treat that URL as private. Anyone with the secret iCal URL can read that calendar feed.

Use the Sample button to clear all feed URLs and return to demo data.

## Privacy Notes

- Private iCal URLs are not committed to this repo.
- Generated agenda cache files are ignored because they may contain event names, locations, and meeting details.
- The committed `UserSettings.inc` uses blank calendar URLs for safe packaging.
- If you connect a real calendar in the live Rainmeter skin, avoid copying the repo default `UserSettings.inc` over your live one.

## Status

Early beta prototype. Not packaged for release yet.
