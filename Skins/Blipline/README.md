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

Click a feed dot in settings, then choose from the 24-color palette to assign that feed's timeline color.

Location and notes come from the calendar event Location and Description/Notes fields. Enabled details share one clipped timeline detail line, so very long text may shorten with ellipsis. Unsupported inline emoji are normalized before display, while common visual markers can still become Blipline event badges. Use Settings > Timeline scale for minus, plus, `Reset 100%`, or typed percent resizing. For 24-hour times, set `TimeFormat=24` in `@Resources\UserSettings.inc`; `AllDayLabel` controls the all-day text.

Leave feeds blank to preview Blipline with sample events.

Private iCal URLs and generated agenda caches should stay local to the installed skin.
