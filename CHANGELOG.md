# Blipline Changelog

## 0.3.0 Beta - 2026-05-10

First public beta release.

### Added

- Scrollable Rainmeter agenda timeline with a current/next event highlight.
- Side countdown tag that returns the timeline to the current event when clicked.
- Clipboard import for multiple private iCal calendar links, one per line.
- Up to eight calendar feeds in one merged agenda.
- Detected calendar names, per-feed colors, and a clickable color palette.
- Event detail toggles for calendar name, location, and notes.
- Six layout templates: Classic, Command, Ledger, Metro, Studio, and Daylight.
- Light-mode option through the Daylight template.
- Demo mode for trying Blipline without connecting a calendar.

### Improved

- Better handling for recurring events, birthdays, edited recurring-event instances, cancelled events, and busy multi-calendar schedules.
- Smoother scrolling and return-to-current behavior.
- Cleaner setup panel with a solid black background and clearer control spacing.
- Improved title/detail spacing and day separators for dense schedules.
- Template switching now keeps the same overall footprint as Classic.

## 0.2.0 Working Prototype - 2026-05-09

Working local MVP checkpoint.

- Renamed the project from the working placeholder to Blipline.
- Moved the timeline visual closer to the concept mockup.
- Added a settings panel with close, refresh, open, and demo controls.
- Added early multi-calendar support.
- Added calendar-name detection and basic recurrence support.
- Added private iCal setup notes and generated-cache safety rules.

## 0.1.0 Prototype - 2026-05-09

First local Rainmeter prototype.

- Main timeline skin with six visible event rows.
- Side countdown tag for the next/current event.
- Sample-data fallback when no calendar feed is set.
- PowerShell iCal/ICS fetch and parser script.
- Lua timeline updater for countdown and active-row shifting.
