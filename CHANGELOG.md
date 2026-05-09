# Blipline Changelog

## Unreleased

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
