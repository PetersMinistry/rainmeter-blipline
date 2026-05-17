# Blipline Changelog

## 0.3.6 Beta - 2026-05-17

Recurrence accuracy patch for alternating weekly events.

### Fixed

- Biweekly calendar events that use `INTERVAL=2` with `BYDAY` now stay on their correct week instead of appearing every week.

## 0.3.5 Beta - 2026-05-14

Layout polish update for timeline separators and resize behavior.

### Fixed

- Date separator chips now keep clear of the previous event's detail line when the visible list crosses into a new day.
- Resize helper launch now uses Rainmeter's own program path, improving reliability across machines and install locations.

### Improved

- Resize handle is easier to target, with scroll/right-click sizing actions routed through the timeline script and a local resize status message saved after use.

## 0.3.4 Beta - 2026-05-12

Reliability update for calendar refresh timing.

### Fixed

- Timeline auto-refresh now explicitly runs the calendar fetch on the configured interval.
- Default refresh cadence is now 5 minutes instead of 15 minutes.

## 0.3.3 Beta - 2026-05-11

Security and privacy patch for calendar feed fetching and release hygiene.

### Security

- Removed TLS certificate-verification bypasses from private iCal fetch fallbacks.
- Python helper fetches now use default verified TLS instead of an unverified SSL context.

### Improved

- Release privacy validation now catches insecure TLS bypass patterns and private-looking screenshot artifacts in the local release-adjacent `dist` folder.
- Removed private contact-sheet screenshot artifacts from local release-adjacent build output.

## 0.3.2 Beta - 2026-05-11

Icon polish beta update for clearer event badges.

### Added

- Crisp PNG event glyphs for meals, sunrise/morning events, Bible study, cross/church events, birthdays, flowers, ministry/swords, butterflies, candles, and fallback events.

### Improved

- Event badges now use a stronger Rainmeter shape background with a dedicated image glyph, making them easier to read at the native timeline size.
- Emoji marker detection is preserved before title cleanup, so supported Google Calendar emoji markers can drive Blipline badges without leaving stray emoji in the displayed title.

## 0.3.1 Beta - 2026-05-10

Feature beta update for timeline resizing.

### Added

- Lower-right timeline resize handle.
- Persistent `UiScale` setting with 70% to 145% bounds.
- Mouse-wheel fine tuning on the resize handle.
- Right-click reset on the resize handle to return the timeline to 100%.

### Improved

- Timeline geometry, row spacing, typography, countdown tag, dots, and handle position now scale together from the same setting.
- Live resize testing preserves local private calendar feed settings.

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
