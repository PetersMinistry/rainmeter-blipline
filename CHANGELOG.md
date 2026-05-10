# Blipline Changelog

## Unreleased

- Made the settings panel opaque black and expanded it for the richer setup controls.
- Added layout template selection with six visual treatments: Classic, Command, Ledger, Metro, Studio, and Daylight light mode.
- Reworked layout templates so they now drive the actual timeline geometry: panel size/placement, countdown tag position, connector, axis, row columns, day separators, scroll hotspot, and header placement.
- Added a clickable feed color palette: select a feed dot, then choose from twelve swatches instead of typing RGBA values.
- Reduced the setup palette swatch size so the event-detail controls below it are readable.
- Added event-detail visibility toggles for calendar name, location, and notes.
- Widened and reorganized the setup panel so feed status, palette swatches, template buttons, and notes have clearer lanes.
- Expanded Classic vertically and increased day-separator breathing room to reduce title/detail/date-chip overlap.
- Removed the hard-coded inner rule from the side countdown tag and made the tag glow follow the selected template color.
- Returned all layout templates to Classic's shared footprint so alternate designs do not become wider or taller than the original skin shape.
- Capped stacked day-separator offsets so heavily mixed multi-day calendars do not push the bottom rows out of the panel.
- Added yearly `RRULE` expansion so birthday/anniversary calendars imported from Google Calendar appear in the visible agenda window instead of staying pinned to their original old dates.
- Added `RECURRENCE-ID` override handling so one-off edits inside weekly recurring events, including edited cancelled notices, replace the generated master occurrence.
- Added per-calendar cache backfill with `CachePerCalendarMinimum` so smaller calendars remain visible alongside very busy recurring feeds.
- Increased the generated agenda cache beyond the six visible rows so dense calendars have enough upcoming events for paging.
- Added lightweight auto-paging in the timeline when more events are cached than fit in the visible space.
- Sorted timed events ahead of all-day entries on the same date so renewal-style all-day items do not crowd out scheduled appointments.
- Sanitized non-ASCII calendar text before it reaches Rainmeter to avoid mojibake characters in event titles and details.
- Added `CacheLimit`, `CachePastDays`, `CacheFutureDays`, and `ScrollStep` settings for controlling timeline depth and wheel navigation.
- Reworked the agenda model toward a scrollable timeline: the cache now keeps past and future events, and the timeline responds to mouse-wheel scrolling.
- Replaced Today / 3 Days / Week range controls with Glass / Dense / Focus timeline style presets.
- Changed Sample into a safer Demo mode that does not clear saved calendar feed URLs.
- Added a middle-click recenter action on the timeline scroll area to jump back to the current/next event.
- Expanded feed parsing to support up to eight configured iCal feed slots, with default color slots for each.
- Added clickable color dots in settings for the visible feed rows so calendar colors can be edited without changing URLs.
- Added iCal calendar-color detection for feeds that publish `COLOR`, `X-APPLE-CALENDAR-COLOR`, or `X-WR-CALCOLOR`.
- Preserved Unicode and emoji text in event titles/details and imported event `DESCRIPTION` text for richer Dense rows.
- Widened the timeline panel and row text area so longer titles, addresses, and notes have more breathing room.
- Refined the side countdown tag so hour/minute values render as a clean two-line time instead of crowding the tag.
- Refined Dense layout with a wider timeline panel, more row text width, smaller settings color swatches, and Rainmeter-safe symbol fallbacks for emoji/smart punctuation to avoid mojibake.
- Moved emoji/emote cues out of titles into small color-backed event badges, keeping titles clean while preserving visual shorthand.
- Made the countdown tag clickable so it glides the timeline back to the current/next event, and hid empty event-badge outlines.
- Increased the timeline visual tick to 20fps during animation, throttled idle redraws, and replaced text badges with small drawn icon-style badges.
- Added subtle day separators with date chips and hairlines between visible event groups, replacing repeated day prefixes in the time column.
- Added an Import Clipboard flow for calendar feeds: copy multiple private iCal URLs one per line, then import them into the configured feed slots in one action.
- Simplified feed setup around Import Clipboard, removed individual URL entry boxes, added Reset Feeds, and surfaced import/reset confirmation text.
- Added detected calendar status rows in settings, including safe per-slot name, OK/failed state, event count, and color dot; import now assigns a distinct color palette across feed slots.

## 0.2.0 Working Prototype - 2026-05-09

Working local MVP checkpoint.

Renamed the project from the working placeholder to Blipline.
Moved the timeline visual closer to the concept mockup: translucent dark panel, yellow countdown emphasis, dotted connector, active event glow, wider row spacing, and no extra title label above the skin.
Expanded the settings panel with a close button, calendar URL paste field, sample-mode reset, refresh/timeline controls, and Today / 3 Days / Week agenda range buttons.
Adjusted agenda caching so Blipline keeps the next future event available even when it falls outside the selected range.
Added MVP multi-calendar support for up to three private iCal feeds, including per-feed colors and calendar labels in the timeline detail row.
Expanded the settings panel to show three feed paste fields while keeping Sample as a one-click reset back to demo data.
Made the refresh interval explicit for Rainmeter and added refresh cadence text to the settings panel.
Added compact day labels on timeline rows when a visible event is outside the active header date.
Documented private calendar URL and generated-cache safety rules.
Added automatic calendar-name detection from iCal `X-WR-CALNAME` values, with per-feed fallback labels.
Added basic iCal recurrence expansion for daily, weekly, and monthly rules, plus cancelled-event and EXDATE handling.
Added `tools\Test-AgendaPipeline.ps1` to verify sample mode and safe fake iCal ingestion without a private calendar URL.
Switched generated agenda cache output to UTF-8 and filtered title-level cancelled events.
Added optional `FetchHelperPath` support so a local Python helper can fetch Google iCal feeds when Windows PowerShell HTTPS fails.

## 0.1.0 Prototype - 2026-05-09

First local Rainmeter prototype.

### Added

- Main scrolling-style timeline skin with six visible event rows.
- Side countdown tag for the next/current event.
- Sample-data fallback when no Google Calendar iCal URL is set.
- PowerShell iCal/ICS fetch and parser script.
- Lua timeline updater for countdown and active-row shifting.
- Basic setup/help panel with manual refresh.

### Prototype Notes

- No real Google Calendar feed has been connected yet.
- The current auto-scroll behavior recenters the visible row window around the next/current event, rather than using smooth animated scrolling.
- The private iCal URL setup flow still needs a more user-friendly UI.
