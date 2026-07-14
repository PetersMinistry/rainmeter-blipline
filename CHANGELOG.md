# Blipline Changelog

## Unreleased

No unreleased changes.

## 0.3.23 Beta - 2026-07-14

Calendar loading reliability fix.

### Fixed

- Waits for calendar loading to finish before refreshing the Settings or Add Calendars window. Previously, Blipline could stop a refresh too early and leave feeds stuck at `pending refresh`, especially with larger calendars.

## 0.3.22 Beta - 2026-07-13

Overnight event and calendar refresh reliability fix.

### Fixed

- Keeps timed events timed when they cross midnight, so an event from 8:30 PM to 5:30 AM retains those times instead of becoming an all-day row.
- Restricts daily all-day expansion to true `VALUE=DATE` events, correcting the 0.3.21 behavior that converted every cross-date timed event into all-day slices and could multiply work on large recurring feeds.
- Replaces the unbounded first feed download with a single 25-second HTTP request that handles redirects, compression, response validation, and calendar text decoding.
- Saves feed results after each calendar finishes so completed feeds retain `OK` or `Failed` status even when a later private feed is slow or unavailable.
- Removes the temporary Python fetch-helper path from calendar refreshes.

## 0.3.21 Beta - 2026-07-08

Multi-day event display fix.

### Fixed

- Expands any event that spans more than one calendar day into daily display slices, not just `VALUE=DATE` all-day events. Previously a multi-day event with real start/end times (e.g. a vacation from 2:30pm one day to 3:00pm weeks later) rendered once at the top and never repeated on the days it covered.
- Each daily slice is treated as a background all-day event, so the countdown tag still points at the next real scheduled timed appointment instead of locking onto the long event's end.
- Adds a regression test (`Timed Vacation` fixture) to `tools/Test-AgendaPipeline.ps1` covering timed multi-day expansion.
- Writes the generated agenda cache as Rainmeter-safe BOM-free ANSI/cp1252 so French and Spanish all-day labels render correctly (`Toute la journée`, `Todo el día`) instead of mojibake such as `Toute la journÃ©e` / `Todo el dÃa`.

## 0.3.20 Beta - 2026-07-07

Localization architecture hardening and Settings click fixes.

### Added

- Adds UTF-8 language pack files under `@Resources/Locales` for English, Russian, Spanish, Italian, French, and German.
- Adds a shared `Localization.ps1` loader for Settings, Calendar Import, and Timeline strings.
- Adds `tools/Test-Localization.ps1` to catch missing translation keys, unexpected typo keys, mojibake markers, and locale file encoding mistakes.

### Changed

- Moves Settings labels, Calendar Import status text, and Timeline/countdown labels out of embedded script tables and into the locale packs.
- Resolves available language codes from locale files so future language packs can be added with less script churn.

### Fixed

- Applies language, clock format, and refresh interval Settings clicks through a hidden launcher so no terminal window flashes on each option click.
- Fixes a corrupted localization parser marker that could stop language and clock clicks before settings were saved.
- Translates persisted Calendar Import status messages when changing languages, including legacy timestamped messages such as `Cleared feeds at 9:05`.
- Keeps the Calendar Import panel from showing stale English validation text after switching to another language.

## 0.3.19 Beta - 2026-07-06

Countdown focus and localization review fixes.

### Fixed

- Keeps all-day and long-running events visible in the timeline while preventing them from taking over the left countdown tag when a real scheduled timed event is coming up.
- Treats midnight-start, day-length calendar items as background for countdown focus so the tag can point to the next meaningful appointment instead of stopping at midnight.
- Localizes Calendar Import status messages such as empty clipboard, invalid Google Calendar page links, duplicates, full slots, removed feeds, and added feed counts.
- Shows the selected language with the same orange active state used by the other Settings buttons.
- Carries the selected language index through Settings writes so language highlighting stays synchronized after refreshes.

## 0.3.18 Beta - 2026-07-06

Calendar import management and localization hardening.

### Added

- Adds a dedicated Calendar Import panel opened from Settings.
- Adds iCal links additively so importing new links no longer replaces existing calendars.
- Adds per-calendar Remove buttons plus a two-step Clear All flow for feed management.
- Adds Settings-page refresh interval buttons for 1, 5, 10, and 15 minute refresh checks.
- Adds localized Calendar Import panel labels for the existing English, Russian, Spanish, Italian, French, and German language options.

### Fixed

- Fixes Spanish, French, and German Settings labels rendering as mojibake such as `LÃ­nea`, `AÃ±adir`, and `EspaÃ±ol`.
- Keeps `UserSettings.inc` BOM-free for Rainmeter parsing while preserving accented Settings labels when language, import, or refresh actions rewrite the file.
- Splits the import help copy into two lines so localized instructions with accents fit the Settings panel cleanly.
- Keeps the Calendar Import panel synchronized with the selected language after changing Settings language.
- Skips duplicate iCal URLs and keeps existing feeds in place when adding additional calendars.

## 0.3.17 Beta - 2026-07-05

Display options and timeline alignment pass.

### Added

- Adds Settings-page language options for English, Russian, Spanish, Italian, French, and German.
- Adds Settings-page 12-hour and 24-hour clock buttons backed by the existing `TimeFormat` cache generation.
- Generates localized timeline labels through the agenda cache so future language additions can be made from the central locale table.

### Fixed

- Reflows the Settings page into a wider two-column panel so the new display controls do not make the window overly tall.
- Applies language and clock changes through a hidden settings writer so clicks do not flash a terminal window.
- Re-formats the existing agenda cache immediately for language and clock changes instead of waiting on a calendar feed refresh first.
- Localizes Settings page labels along with the generated timeline labels when the language changes.
- Keeps Settings and Timeline in the same language/time format by updating `UserSettings.inc` and `Agenda.inc` together.
- Localizes countdown tag unit spacing and adds plural day labels plus day/hour split output for long active events.
- Sanitizes Rainmeter-facing language text to prevent mojibake, removes leaked status variables, and strips HTML tags from event details.
- Centers event, divider, connector, and active glow circles on the timeline rule using Rainmeter ellipse center/radius geometry.

## 0.3.16 Beta - 2026-07-03

Settings include hotfix for the 0.3.15 beta release.

### Fixed

- Writes `UserSettings.inc` as UTF-8 without BOM so Rainmeter Settings can parse included variables after refresh/import instead of showing raw `#FeedName#`, `#UiScale#`, and toggle placeholders.

## 0.3.15 Beta - 2026-07-03

Multi-day all-day event and visual marker cleanup.

### Fixed

- Expands multi-day all-day events into daily display slices so week-long events move through the timeline instead of staying anchored to the first day.
- Normalizes unsupported inline emoji and symbol markers before Rainmeter display to avoid mojibake such as `ðŸ` or `âœ`.
- Maps common visual markers such as sparkles, hearts, books, meals, birthdays, candles, and dates to Blipline event badges where possible.

## 0.3.14 Beta - 2026-07-02

Layout hardening for scaled and localized timelines.

### Changed

- Scales row time widths, row text heights, icon image sizes, date divider chips, and row offsets together with `UiScale`.
- Centers date divider chips and divider dots from shared anchors so divider labels, lines, and dots stay aligned while scaled.
- Keeps the countdown tab number and unit centered and capped so they remain readable at larger timeline scales.
- Shows enabled notes in the normal event detail line instead of limiting notes to the dense style path.
- Uses clipped detail/title text with ellipsis for long calendar, location, and note strings.
- Adds Settings-panel timeline scale controls with minus, plus, reset, and numeric percent entry.
- Removes the unreliable corner resize control and makes Settings the resize path.
- Saves manually entered scale settings through the Settings panel.

## 0.3.13 Beta - 2026-07-01

Multi-calendar scroll-depth update for larger feed sets.

### Changed

- Automatically expands the timeline cache for configured multi-calendar setups: 1-5 feeds keep the base cache, 6-10 feeds get double depth, and 11-15 feeds get triple depth up to a conservative default cap.
- Keeps smaller setups at the same scroll depth and performance profile while allowing 15-feed setups to scroll farther into the future.

## 0.3.12 Beta - 2026-06-30

Issue #2 hotfix for international text and timeline start position.

### Fixed

- Preserved UTF-8 accented calendar text in generated agenda variables instead of stripping or corrupting characters such as `Frühstück`, `Rücken`, and `Café`.
- Wrote the generated agenda cache as UTF-8 to avoid Windows default-codepage replacement characters.
- Started the default timeline view at the current or next event instead of placing two cached past events above it.
- Applied the 15-feed cap consistently when matching event colors to detected calendar names.

## 0.3.11 Beta - 2026-06-30

Settings and localization update requested by early users.

### Added

- Expanded the feed color palette from 12 to 24 swatches.
- Added `TimeFormat=24` support for 24-hour event times.
- Added `AllDayLabel` so the all-day text can be translated in `UserSettings.inc`.

### Fixed

- Hid timeline rows that would be pushed below the scroll viewport by stacked date separators, preventing clipped bottom rows at some scales.

## 0.3.10 Beta - 2026-06-28

Feed capacity update for larger planner sets.

### Added

- Increased supported iCal feed slots from 8 to 15.
- Added setup-panel status rows and color selection targets for feeds 9 through 15.
- Added `CalendarUrl1` compatibility for users who manually number the first feed URL.

### Fixed

- Restored the missing monthly `BYDAY` recurrence brace in the packaged source script.

## 0.3.9 Beta - 2026-06-15

Recurrence accuracy patch for monthly BYDAY calendar events, plus color display fixes.

### Fixed

- Monthly recurring events that use `BYDAY` (e.g., 3rd Saturday, last Monday, 2nd Tuesday) now land on the correct date instead of the same day-of-month as the base event.
- Negative BYDAY ordinals (`-2MO`, `-3MO`) now correctly resolve to Nth-from-last weekdays.
- Months where the requested ordinal does not exist (e.g., `BYDAY=5MO` in a 4-Monday month) are now skipped instead of producing fabricated dates.
- Settings palette colors now take priority over feed-detected colors (`X-WR-CALCOLOR`) so user-assigned colors always show on the timeline.
- Active/current event dot now uses the event's assigned feed color instead of being overridden with the yellow accent color.

## 0.3.8 Beta - 2026-06-02

Performance update introducing 60fps smooth scroll and encoding fixes.

### Improved
- Fixed UTF-8 BOM encoding bug in `Timeline.ini` to restore Rainmeter's ability to parse the `[Rainmeter]` section and activate the fast `Update=50` (50ms refresh cycle).
- Added recenter window optimization of `6.0` rows (one full viewport height) to instantly teleport within scrolling distance when resetting, enabling a gorgeous, sweeping visual glide back home.
- Restored smooth asymptotic ease-out curve (`delta * 0.15`) with a tight `0.15` rows snap threshold for an elegant 1.1s glide.
- Removed redundant overlapping mouse click actions on the countdown text/unit meters to prevent triple-execution on single clicks.

## 0.3.7 Beta - 2026-06-01

Layout update introducing the transparent Phantom template.

### Added
- Added the transparent **"Phantom"** layout template with a completely transparent panel background, faint white glass border framing, translucent separator lines, and high-visibility typography.
- Integrated the new **Phantom** layout button on Row 3 inside the setup panel (`Settings.ini`).
- Resized the setup panel to `800px` height to cleanly support the expanded 7th layout button option.

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

