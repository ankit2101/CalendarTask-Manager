# CalendarTask Manager

A cross-platform desktop app that connects your calendars via ICS/Webcal feeds, captures meeting notes with AI-extracted action items, and keeps your to-do list in one place. Available as a native **Flutter app on macOS** and an **Electron app on Windows**.

---

## Download

Grab the latest release from [Releases](https://github.com/ankit2101/CalendarTask-Manager/releases).

### macOS

Download the `.dmg` file.

1. Open the DMG and drag **CalendarTask Manager** to your Applications folder
2. First launch: **right-click → Open** to bypass Gatekeeper
3. If macOS blocks it entirely, run: `xattr -cr /Applications/calendar_task_manager.app`

### Windows

Download the `CalendarTaskManager-Setup.exe` file.

1. Run the installer — it will install the app and create a Start Menu shortcut
2. Launch **CalendarTask Manager** from the Start Menu

---

## Features

### 📅 Calendar
- Connect any calendar via **ICS / Webcal feeds** (Google, Outlook, iCloud, and more)
- View events across all feeds in a single daily view
- Navigate forward and backward through dates
- Live **IN PROGRESS** badge on meetings happening right now
- Leave/OOO events (PTO, vacation, out of office) are automatically hidden
- Private appointments shown with a 🔒 lock icon
- **Auto-refresh** every 15 minutes — no manual action needed
- **Dismiss** past meeting reminders with the × button
- **Timezone Preservation** — Explicitly captures and displays the event's original source timezone (e.g. PST, EST) instead of homogenizing exclusively to your system's local offset.
- **Edit meeting time** — tap the ✏️ pencil icon on any event to correct the start/end time if it was captured in the wrong timezone. An **edited** badge marks overridden events; the reset button restores the original time

### ✏️ Meeting Notes
- **+ Add Notes** button on every past meeting
- **+ Live Notes** button on meetings happening right now
- Edit saved notes at any time from the **Notes** tab
- Claude AI extracts action items from your notes automatically
- Review, edit, add, or delete action items before saving
- Re-extract action items after editing a note

### ✅ To-Do Board
- Three states: **To-Do → In Progress → Completed**
- Edit task title, description, priority, and **due date** inline
- New tasks default to a due date **2 days from creation**
- Due dates are colour-coded: orange when due today, red when overdue
- Each task card shows the **source meeting name** and **created date**
- Action items from meeting notes land here automatically

### 🤖 Claude AI
- Choose your Claude model in **Settings**:
  - `claude-opus-4-20250514`
  - `claude-sonnet-4-20250514`
  - `claude-3-5-sonnet-20241022`
  - `claude-3-5-haiku-20241022`
  - `claude-3-haiku-20240307`
- Model change takes effect immediately — no restart needed

---

## Requirements

- **macOS** 10.13+ (Flutter app)
- **Windows** 10+ (Electron app)
- A [Claude API key](https://console.anthropic.com/)

---

## Setup

### 1. Install the app

Download `CalendarTaskManager.dmg` from [Releases](https://github.com/ankit2101/CalendarTask-Manager/releases) and drag to Applications.

### 2. Add your Claude API key

Open the app → **Settings** → paste your API key → **Save**.

### 3. Connect your calendars

Go to **Accounts** → paste an ICS/Webcal URL → **Add**.

---

## Connecting Calendars

All calendars are connected via a private ICS URL — no OAuth or third-party sign-in required.

### Google Calendar

1. Open [calendar.google.com](https://calendar.google.com)
2. Click the **⚙ Settings** gear → **Settings**
3. In the left sidebar, click the calendar you want (under "Settings for my calendars")
4. Scroll down to **Secret address in iCal format**
5. Copy the URL (starts with `https://calendar.google.com/calendar/ical/...`)
6. In the app → **Accounts** → paste the URL → **Add**

### Microsoft Outlook / Office 365

1. Open [outlook.office.com](https://outlook.office.com)
2. Click the **Calendar** icon
3. Go to **Settings** (⚙) → **View all Outlook settings** → **Calendar** → **Shared calendars**
4. Under **Publish a calendar**, select your calendar and permission level → **Publish**
5. Copy the **ICS** link
6. In the app → **Accounts** → paste the URL → **Add**

### iCloud Calendar

1. Open the **Calendar** app on Mac
2. Right-click a calendar → **Get Info** → check **Public Calendar**
3. Copy the URL shown → paste into the app

---

## Documentation & Development

This repository contains two parallel implementations: a native **Flutter macOS app** and an **Electron React app** (Windows, with macOS support in progress).

Please see the `docs/` directory for detailed architecture and development instructions:

- [Workspace Architecture](docs/ARCHITECTURE.md)
- [Flutter App Setup & Build](docs/FLUTTER_APP_SETUP.md)
- [Electron App Setup & Build](docs/ELECTRON_APP_SETUP.md)

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Dart / Flutter |
| State management | Riverpod |
| Persistence | JSON file (data) + macOS Keychain (secrets) |
| AI | Anthropic Claude API |
| ICS parsing | Custom RFC 5545 parser |
| Timezones | IANA tz database (timezone package) |
| HTTP | Dio |
| Theme | Catppuccin Mocha |

---

## Project Structure

```
lib/
├── app.dart                        # Root widget + router
├── main.dart                       # App entry point
├── models/                         # Data models (account, event, task, settings)
├── pages/
│   ├── dashboard_page.dart         # Daily calendar view
│   ├── todos_page.dart             # To-do board (To-Do / In Progress / Done)
│   ├── notes_page.dart             # Saved meeting notes + edit
│   ├── accounts_page.dart          # Calendar account management (ICS/Webcal)
│   └── settings_page.dart          # API key + model selector
├── providers/
│   └── app_providers.dart          # Riverpod providers
├── services/
│   ├── ai/claude_client.dart       # Anthropic API client
│   ├── auth/token_store.dart       # Secure credential storage (Keychain)
│   ├── calendar/
│   │   ├── calendar_manager.dart   # Aggregates ICS feeds + deduplication
│   │   └── ics_calendar_service.dart  # RFC 5545 ICS parser
│   ├── meeting_poller.dart         # Live meeting detection
│   └── storage/app_database.dart   # Local JSON data persistence
├── widgets/
│   ├── app_scaffold.dart           # Sidebar + navigation
│   ├── quick_note_dialog.dart      # Meeting note capture dialog
│   └── timezone_picker_dialog.dart # Meeting time correction dialog
└── core/
    ├── constants.dart              # Claude model list
    ├── time_utils.dart             # Timezone helpers + Windows↔IANA map
    └── theme/                      # Catppuccin Mocha theme
```

---

## Data Storage

All data is stored locally in a single JSON file (`calendartask_data.json`). The default location is `~/Library/Application Support/com.caltask.calendar_task_manager/`, but you can move it anywhere — including a cloud folder like **OneDrive or iCloud Drive** — via **Settings → Change Data Location**.

When you choose a folder outside the app sandbox (e.g. `~/Library/CloudStorage/`), the app saves a macOS **security-scoped bookmark** so it can re-open the file automatically on every future launch without prompting.

Sensitive credentials (Claude API key) are stored in the **macOS Keychain**, not in the data file.

No data is sent to any server except the Claude API when extracting action items.

---

## License

MIT
