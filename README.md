# CalendarTask Manager

A cross-platform desktop app built with Flutter that connects your calendars via ICS/Webcal feeds, captures meeting notes with AI-extracted action items, and keeps your to-do list in one place. Available on **macOS** and **Windows**.

---

## Download

Grab the latest release from [**Releases**](https://github.com/ankit2101/CalendarTask-Manager/releases).

### macOS Installation

> The app is ad-hoc signed but not notarized. macOS may show **"app can't be opened"** on first launch — use one of the options below.

**Option A — Install Helper (easiest)**
1. Download and open `CalendarTask.Manager.dmg`
2. Double-click **"Install CalendarTask Manager.command"** inside the DMG
3. Enter your password if prompted — the helper copies the app to /Applications and clears the Gatekeeper flag automatically

**Option B — Manual**
1. Open the DMG → drag **CalendarTask Manager** into **Applications**
2. Open **Terminal** and run:
   ```
   xattr -cr "/Applications/CalendarTask Manager.app"
   ```
3. Open the app normally

**Option C — System Settings**
1. Drag the app to Applications and try to open it
2. Go to **System Settings → Privacy & Security → scroll down → "Open Anyway"**

### Windows Installation

1. Download `CalendarTaskManager-windows.zip`
2. Extract and run `calendar_task_manager.exe`
3. If Windows Defender prompts — click **More info → Run anyway**

---

## Features

### 📅 Calendar

- Connect any calendar via **ICS / Webcal feeds** (Google, Outlook, iCloud, and more)
- View events across all feeds in a single **daily view**
- Navigate forward and backward through dates
- Live **IN PROGRESS** badge on meetings happening right now
- Leave/OOO events (PTO, vacation, out of office) are automatically hidden
- Private appointments shown with a 🔒 lock icon
- **Auto-refresh** every 15 minutes — no manual action needed
- **Dismiss** past meeting reminders with the × button
- **Dual timezone display** — event cards show the original source timezone (e.g. "8:30 AM – 9:00 AM MST") alongside your local time (e.g. "9:30 PM IST"), so you always know when a meeting was scheduled in its home timezone
- **Edit meeting time** — tap the ✏️ pencil icon on any event to correct the start/end time if it was captured in the wrong timezone; an **edited** badge marks overridden events and a reset button restores the original

### ✏️ Meeting Notes

- **+ Add Notes** button on every past meeting
- **+ Live Notes** button on meetings happening right now
- Edit saved notes at any time from the **Notes** tab
- **Claude AI** extracts action items from your notes automatically
- One-time **privacy consent dialog** before Claude is called — your data stays in your control
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
- Attendee email addresses are stripped from prompts before sending to the API

### 🔒 Security & Privacy

- **Encrypted data file** — all local data is protected with **AES-256-GCM** authenticated encryption; any on-disk tampering is detected and rejected
- **Secure credential storage** — your Claude API key lives in the OS keychain (**macOS Keychain** / **Windows Credential Manager**), never in a plaintext file
- **SSRF protection** — calendar URLs are validated to block private-network addresses (localhost, RFC 1918 ranges, link-local)
- **Request limits** — ICS feeds are capped at 10 MB; HTTP connections time out at 10 s; recurring event expansion is capped to prevent CPU abuse
- **AI consent** — a one-time dialog informs you before any meeting content is sent to Claude

---

## Requirements

- **macOS** 10.13+ (Apple Silicon and Intel)
- **Windows** 10+ (64-bit)
- A [Claude API key](https://console.anthropic.com/) for AI features (optional — the rest of the app works without one)

---

## Setup

### 1. Install the app

Download the latest release from [Releases](https://github.com/ankit2101/CalendarTask-Manager/releases) and follow the platform instructions above.

### 2. Add your Claude API key *(optional)*

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
5. Copy the URL (starts with `https://calendar.google.com/calendar/ical/…`)
6. In the app → **Accounts** → paste the URL → **Add**

### Microsoft Outlook / Office 365

1. Open [outlook.office.com](https://outlook.office.com)
2. Click the **Calendar** icon
3. Go to **Settings (⚙) → View all Outlook settings → Calendar → Shared calendars**
4. Under **Publish a calendar**, select your calendar and permission level → **Publish**
5. Copy the **ICS** link
6. In the app → **Accounts** → paste the URL → **Add**

### iCloud Calendar

1. Open the **Calendar** app on Mac
2. Right-click a calendar → **Get Info** → check **Public Calendar**
3. Copy the URL shown → paste into the app

---

## Data Storage

All data is stored locally in a single encrypted file (`calendartask_data.json`). Default locations:

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/com.caltask.calendar_task_manager/` |
| Windows | `%APPDATA%\com.caltask.calendar_task_manager\` |

**Cloud sync:** Move the file to any folder (OneDrive, iCloud Drive, Dropbox) via **Settings → Change Data Location**. On macOS, a security-scoped bookmark is saved so the sandbox can re-open the file on every future launch without prompting.

**Encryption:** The file is encrypted with AES-256-GCM. The encryption key is stored in the OS keychain and never touches disk in plaintext.

**API keys:** Stored exclusively in the OS keychain — not in the data file, not in SharedPreferences.

**No cloud:** No data is sent to any external server except the Claude API when extracting action items (and only after you approve the one-time consent dialog).

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Dart / Flutter |
| Platforms | macOS, Windows |
| State management | Riverpod |
| Navigation | go_router |
| Data persistence | AES-256-GCM encrypted JSON file |
| Credential storage | OS Keychain (macOS) / Credential Manager (Windows) via flutter_secure_storage |
| AI | Anthropic Claude API |
| ICS parsing | Custom RFC 5545 parser with full TZID, RRULE, EXDATE support |
| Timezones | IANA tz database (`timezone` package) + Windows↔IANA map |
| HTTP | Dio (with timeouts + response size cap) |
| Encryption | `encrypt` package — AES-256-GCM |
| Theme | Catppuccin Mocha |

---

## Project Structure

```
lib/
├── app.dart                        # Root widget + router
├── main.dart                       # App entry point
├── models/                         # Data models (account, event, task, settings)
├── pages/
│   ├── dashboard_page.dart         # Daily calendar view with dual-timezone cards
│   ├── todos_page.dart             # To-do board (To-Do / In Progress / Done)
│   ├── notes_page.dart             # Saved meeting notes + edit
│   ├── accounts_page.dart          # Calendar account management + SSRF guard
│   └── settings_page.dart          # API key + model selector
├── providers/
│   └── app_providers.dart          # Riverpod providers
├── services/
│   ├── ai/claude_client.dart       # Anthropic API client (timeouts, email scrub)
│   ├── auth/token_store.dart       # Secure credential storage (Keychain + fallback)
│   ├── calendar/
│   │   ├── calendar_manager.dart   # Aggregates ICS feeds + deduplication
│   │   └── ics_calendar_service.dart  # RFC 5545 parser (TZID, RRULE, EXDATE)
│   ├── meeting_poller.dart         # Live meeting detection
│   └── storage/app_database.dart   # AES-256-GCM encrypted local JSON store
├── widgets/
│   ├── app_scaffold.dart           # Sidebar + navigation
│   ├── quick_note_dialog.dart      # Meeting note capture + AI consent dialog
│   └── timezone_picker_dialog.dart # Meeting time correction dialog
└── core/
    ├── constants.dart              # Claude model list
    ├── time_utils.dart             # Timezone helpers + Windows↔IANA map
    └── theme/                      # Catppuccin Mocha theme
```

---

## Documentation & Development

See the `docs/` directory for build and development instructions:

- [Flutter App Setup & Build](docs/FLUTTER_APP_SETUP.md)

---

## License

MIT
