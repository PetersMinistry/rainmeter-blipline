# Blipline

Rainmeter agenda timeline for Google Calendar-style private iCal feeds.

## Load

Setup panel:

```text
Blipline\Control\Settings.ini
```

Timeline:

```text
Blipline\Timeline\Timeline.ini
```

## Setup

Copy one or more private iCal URLs to the clipboard, one per line, then click Import Clipboard in the settings panel. Up to fifteen feeds are supported.

Click a feed dot in settings, then choose from the 24-swatch palette to assign that feed's timeline color.

Location and notes come from the calendar event Location and Description/Notes fields. For 24-hour times, set `TimeFormat=24` in `@Resources\UserSettings.inc`; `AllDayLabel` controls the all-day text.

Leave feeds blank to preview Blipline with sample events.

Resize the timeline from the lower-right corner. Scroll on the corner for small size changes, or right-click it to reset.

Private iCal URLs and generated agenda caches should stay local to the installed skin.
