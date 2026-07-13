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

Click Add Calendars in the settings panel to open the localized Calendar Import panel. Copy one or more private iCal URLs to the clipboard, one per line, then click Add iCal Link(s). Up to fifteen feeds are supported.

Adding links does not replace existing calendars. Duplicate links are skipped, new links fill the next open slot, and individual calendars can be removed from the Calendar Import panel.

Click a feed dot in settings, then choose from the 24-color palette to assign that feed's timeline color.

The wider Settings panel includes display options, detected calendar colors, a 24-color palette, event detail toggles, timeline scale controls, refresh interval controls, and layout templates.

Location and notes come from the calendar event Location and Description/Notes fields. Enabled details share one clipped timeline detail line, so very long text may shorten with ellipsis. Unsupported inline emoji are normalized before display, while common visual markers can still become Blipline event badges.

Timed events retain their real start and end times when they cross midnight. True multi-day all-day events remain visible as daily all-day rows. Feed downloads use a bounded request and save results per calendar so one unavailable feed cannot leave every imported calendar pending indefinitely.

Use Settings > Display settings to choose English, Russian, Spanish, Italian, French, or German, and to switch between 12-hour and 24-hour clock formats. Language and clock changes update Settings and the generated timeline cache immediately, including timeline labels and the countdown tag.

Use Settings > Timeline scale for minus, plus, `Reset 100%`, or typed percent resizing. Use Settings > Refresh interval to choose 1, 5, 10, or 15 minute refresh checks. Timeline event dots, divider dots, connector dots, and active-event glow are centered on the timeline rule.

Leave feeds blank to preview Blipline with sample events.

Private iCal URLs and generated agenda caches should stay local to the installed skin.
