# Blipline

Blipline is a Rainmeter agenda timeline for Google Calendar-style iCal feeds.

Basically, it takes your upcoming schedule and turns it into a clean desktop timeline so you can see what is coming up without constantly opening your calendar.

It includes current/next event focus, a side countdown, smooth scrolling, multi-calendar support, language and clock-format options, color controls, timeline scale controls in Settings, and several visual templates depending on the look you are going for.

![Blipline Classic timeline](docs/screenshots/blipline-classic.png)

## Download

Current beta: `v0.3.19-beta.1`

Get the `.rmskin` from the [latest GitHub release](https://github.com/PetersMinistry/rainmeter-blipline/releases/latest).

## What It Does

- Shows a timeline-style agenda with the current or next event highlighted.
- Keeps a side countdown tag visible so the next scheduled timed event is obvious, while all-day and long-running items still stay visible in the timeline.
- Scrolls through cached past and future events with the mouse wheel.
- Clicks the countdown tag to glide back to the current or next event.
- Uses a wider two-column Settings panel for display options, color selection, event details, scale, refresh interval, and template controls.
- Resizes from the Settings panel with minus, plus, `Reset 100%`, and custom percent entry.
- Adds one or many Google Calendar private iCal URLs from the Calendar Import panel without replacing existing calendars.
- Supports up to fifteen iCal feed slots.
- Lets you remove individual calendars from the Calendar Import panel.
- Merges multiple calendars into one readable agenda.
- Automatically expands scroll cache depth for larger multi-calendar setups.
- Auto-detects calendar names and iCal feed colors when the feed provides them.
- Lets you assign feed colors from a 24-color built-in palette when Google does not expose colors.
- Supports Settings-page language options for English, Russian, Spanish, Italian, French, and German.
- Supports 12-hour and 24-hour timeline clock formats.
- Applies language and clock changes immediately to Settings, the generated agenda cache, the countdown tag, and the timeline labels.
- Includes event detail toggles for calendar name, location, and notes.
- Keeps timeline dots, divider dots, connector dots, and the active-event glow centered on the timeline rule.
- Localizes countdown tag units, including day/hour split labels for long active events.
- Keeps long localized titles/details clipped with ellipsis so scaling does not push rows out of alignment.
- Handles daily, weekly, monthly, and yearly recurring events.
- Handles edited single instances of recurring events through `RECURRENCE-ID`.
- Keeps smaller calendars visible with per-calendar cache backfill.
- Preserves Unicode calendar text and normalizes unsupported inline emoji before Rainmeter display.
- Shows crisp event-type badges for common calendar markers such as Bible study, birthdays, meals, church events, flowers, candles, sparkles, hearts, and ministry events.
- Refreshes every 5 minutes by default, with Settings buttons for 1, 5, 10, or 15 minutes and a manual Refresh button.

## Templates

The beta includes seven layout templates. They share the same Classic footprint so switching templates does not make the skin jump wider or taller.

Templates:

| Classic | Command |
| --- | --- |
| ![Blipline Classic template](docs/screenshots/blipline-classic.png) | ![Blipline Command template](docs/screenshots/blipline-command.png) |

| Ledger | Metro |
| --- | --- |
| ![Blipline Ledger template](docs/screenshots/blipline-ledger.png) | ![Blipline Metro template](docs/screenshots/blipline-metro.png) |

| Studio | Daylight |
| --- | --- |
| ![Blipline Studio template](docs/screenshots/blipline-studio.png) | ![Blipline Daylight template](docs/screenshots/blipline-daylight.png) |

## Load Paths

After installing, load the setup panel first:

```text
Blipline\Control\Settings.ini
```

The timeline display is:

```text
Blipline\Timeline\Timeline.ini
```

The beta package opens the settings panel first so new users can import feeds, pick colors, and choose a template before loading the timeline.

![Blipline settings panel](docs/screenshots/blipline-settings.png)

## Google Calendar Setup

In Google Calendar, copy each calendar's Secret address in iCal format. In Blipline settings, click Add Calendars to open the Calendar Import panel, then copy one iCal link or several links to the clipboard and click Add iCal Link(s).

Adding links is additive: existing calendars stay in place, duplicate links are skipped, and new links fill the next open feed slots. Use the Remove buttons in the Calendar Import panel to remove individual calendars.

Private iCal URLs are secret read-only links. Anyone with one can read that calendar feed, so do not post them publicly.

Use Settings > Timeline scale to resize Blipline with minus, plus, `Reset 100%`, or a typed percent value. Use Settings > Refresh interval to choose how often Blipline checks calendar feeds.

Location and notes are read from each calendar event's Location and Description/Notes fields. Enabled details share one clipped timeline detail line, so very long calendar, location, or note text may be shortened with ellipsis.

Use Settings > Display settings to choose English, Russian, Spanish, Italian, French, or German, and to switch between 12-hour and 24-hour event times. Language and clock changes update the Settings panel and the timeline cache immediately, so the visible calendar should not need a feed refresh just to reformat labels.

## Language Packs

Blipline language text lives in `Skins/Blipline/@Resources/Locales/*.ini`. English is the reference pack; other packs must keep the same sections and keys. The shared `Localization.ps1` loader handles fallback, aliases, accents, and Rainmeter-safe output for Settings, Calendar Import, and Timeline labels.

Run `tools/Test-Localization.ps1` after editing or adding a language pack. It checks required keys, unexpected typo keys, UTF-8 BOM encoding, mojibake markers, and a few accent-sensitive labels.

## Privacy

- Your private iCal URLs stay in your local Rainmeter skin settings.
- Agenda cache files stay local because they can include event titles, locations, and notes.

## Requirements

- Rainmeter 4.5 or newer.
- Windows 10 or newer.
- Private iCal links from Google Calendar or another iCal/ICS-compatible calendar provider.

## Status

`v0.3.19-beta.1` is an early beta. It is usable, but still beta. OAuth/Google sign-in calendar selection is not included yet; the current setup path is private iCal import.

