# Blipline

Blipline is a Rainmeter agenda timeline for Google Calendar-style iCal feeds.

Basically, it takes your upcoming schedule and turns it into a clean desktop timeline so you can see what is coming up without constantly opening your calendar.

It includes current/next event focus, a side countdown, smooth scrolling, multi-calendar support, color controls, timeline scale controls in Settings, and several visual templates depending on the look you are going for.

![Blipline Classic timeline](docs/screenshots/blipline-classic.png)

## Download

Current beta: `v0.3.16-beta.1`

Get the `.rmskin` from the [latest GitHub release](https://github.com/PetersMinistry/rainmeter-blipline/releases/latest).

## What It Does

- Shows a timeline-style agenda with the current or next event highlighted.
- Keeps a side countdown tag visible so the next thing is always obvious.
- Scrolls through cached past and future events with the mouse wheel.
- Clicks the countdown tag to glide back to the current or next event.
- Resizes from the Settings panel with minus, plus, `Reset 100%`, and custom percent entry.
- Imports multiple Google Calendar private iCal URLs from the clipboard, one per line.
- Supports up to fifteen iCal feed slots.
- Merges multiple calendars into one readable agenda.
- Automatically expands scroll cache depth for larger multi-calendar setups.
- Auto-detects calendar names and iCal feed colors when the feed provides them.
- Lets you assign feed colors from a 24-color built-in palette when Google does not expose colors.
- Supports optional 24-hour event times and a custom all-day label through `UserSettings.inc`.
- Includes event detail toggles for calendar name, location, and notes.
- Keeps long localized titles/details clipped with ellipsis so scaling does not push rows out of alignment.
- Handles daily, weekly, monthly, and yearly recurring events.
- Handles edited single instances of recurring events through `RECURRENCE-ID`.
- Keeps smaller calendars visible with per-calendar cache backfill.
- Preserves Unicode calendar text and normalizes unsupported inline emoji before Rainmeter display.
- Shows crisp event-type badges for common calendar markers such as Bible study, birthdays, meals, church events, flowers, candles, sparkles, hearts, and ministry events.
- Refreshes every 5 minutes, with a manual Refresh button in settings.

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

In Google Calendar, copy each calendar private iCal URL. In Blipline settings, place each URL on its own clipboard line, then click Import Clipboard.

Private iCal URLs are secret read-only links. Anyone with one can read that calendar feed, so do not post them publicly.

Use Settings > Timeline scale to resize Blipline with minus, plus, `Reset 100%`, or a typed percent value.

Location and notes are read from each calendar event's Location and Description/Notes fields. Enabled details share one clipped timeline detail line, so very long calendar, location, or note text may be shortened with ellipsis. To localize time display, set `TimeFormat=24` and update `AllDayLabel` in `Blipline\@Resources\UserSettings.inc`.

## Privacy

- Your private iCal URLs stay in your local Rainmeter skin settings.
- Agenda cache files stay local because they can include event titles, locations, and notes.

## Requirements

- Rainmeter 4.5 or newer.
- Windows 10 or newer.
- Private iCal links from Google Calendar or another iCal/ICS-compatible calendar provider.

## Status

`v0.3.16-beta.1` is an early beta. It is usable, but still beta. OAuth/Google sign-in calendar selection is not included yet; the current setup path is private iCal import.

