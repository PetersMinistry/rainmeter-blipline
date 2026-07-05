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

The wider Settings panel includes feed import, detected calendar colors, a 24-color palette, event detail toggles, timeline scale controls, and layout templates.

Location and notes come from the calendar event Location and Description/Notes fields. Enabled details share one clipped timeline detail line, so very long text may shorten with ellipsis. Unsupported inline emoji are normalized before display, while common visual markers can still become Blipline event badges.

Use Settings > Display settings to choose English, Russian, Spanish, Italian, French, or German, and to switch between 12-hour and 24-hour clock formats. Language and clock changes update Settings and the generated timeline cache immediately, including timeline labels and the countdown tag.

Use Settings > Timeline scale for minus, plus, `Reset 100%`, or typed percent resizing. Timeline event dots, divider dots, connector dots, and active-event glow are centered on the timeline rule.

Leave feeds blank to preview Blipline with sample events.

Private iCal URLs and generated agenda caches should stay local to the installed skin.
