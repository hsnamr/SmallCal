# SmallCal

A calendar application for GNUStep (Objective-C) that uses [SmallStepLib](../SmallStepLib) for the application lifecycle, menus, window style, and file dialogs. It supports:

- **.ics calendar files** – Open and save iCalendar (RFC 5545) files; view and add VEVENTs.
- **CalDAV** – Open a calendar by URL (with optional username/password), fetch events via REPORT calendar-query, and refresh.

## Building

1. Build and install SmallStepLib first:
   ```bash
   cd ../SmallStepLib && make && make install
   ```
2. Build SmallCal:
   ```bash
   cd ../SmallCal
   export GNUSTEP_MAKEFILES=/usr/share/GNUstep/Makefiles   # if not already set
   make
   ```

## Usage

- **File → Open .ics…** – Load events from a local `.ics` file.
- **File → Open CalDAV…** – Enter calendar URL (e.g. `https://server/caldav/user/calendar/`) and optional credentials; events for the next year are fetched.
- **File → Save / Save As…** – Save the current event list to an `.ics` file.
- **File → Add Event…** – Add a new event (summary, start, end).
- **Refresh** – Re-fetch events from the current CalDAV calendar (enabled when a CalDAV URL is set).

The main window shows an event list (summary and start date) and a detail area for the selected event.
