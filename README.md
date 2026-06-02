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
- **Per-calendar colour** — pick a colour for each feed; events inherit it on the day view
- **Inline rename** — edit a calendar account's display name directly in the Accounts tab
- **Auto-refresh** every 10 minutes — no manual action needed
- **Outlook for Mac fallback** — on corporate laptops where a security agent (e.g. Microsoft Defender for Endpoint) blocks anonymous ICS requests, the app automatically reads events from the locally installed Outlook app instead; no configuration needed
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

- Four states: **To-Do → In Progress → On Hold → Done**
- **On Hold** tasks accept an optional **resume date** — they automatically return to To-Do when the date arrives
- Edit task title, description, priority, and **due date** inline
- New tasks default to a due date **2 days from creation**
- Due dates are colour-coded: orange when due today, red when overdue
- Each task card shows the **source meeting name** and **created date**
- Action items from meeting notes land here automatically

### 🤖 Claude AI

- Choose your Claude model in **Settings**:
  - `claude-opus-4-8` (Claude Opus 4.8 — most capable)
  - `claude-sonnet-4-6` (Claude Sonnet 4.6 — **default**)
  - `claude-haiku-4-5-20251001` (Claude Haiku 4.5 — fastest)
  - `claude-opus-4-7` (Claude Opus 4.7 — legacy)
  - `claude-opus-4-6` (Claude Opus 4.6 — legacy)
  - `claude-sonnet-4-5-20250929` (Claude Sonnet 4.5 — legacy)
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

> **On corporate laptops (Defender for Endpoint / Zscaler / etc.):** Enterprise security agents route all traffic through a proxy, which causes Exchange Online to reject anonymous ICS requests with HTTP 400 — even with a freshly generated URL. The app detects this automatically and falls back to reading events from the **locally installed Outlook for Mac app** via AppleScript. macOS will show a one-time permission prompt — click **OK** — and your calendar will load normally from then on. The ICS URL should still be added in Accounts; the fallback activates only when the feed fails.

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

**Cloud sync:** Move the data folder to OneDrive, iCloud Drive, or Dropbox via **Settings → Change Data Location**. On macOS, a security-scoped bookmark is saved so the sandbox can re-open the folder on every future launch without prompting.

Two files live in the folder:
- `calendartask_data.json` — your encrypted data
- `calendartask_key.b64` — the shared encryption key (written automatically when you set a sync folder)

Both files must be present in the same folder on every machine. Once the key file syncs, any machine that opens the app from that folder can read the data.

**Encryption:** The data file is encrypted with AES-256-GCM. In a local-only setup the key lives in the OS keychain; in a shared sync folder it is stored in `calendartask_key.b64` alongside the data file.

**API keys:** Stored exclusively in the OS keychain — not in the data file, not in SharedPreferences.

**No cloud:** No data is sent to any external server except the Claude API when extracting action items (and only after you approve the one-time consent dialog).

**Recovery tools:** If you ever need to recover or re-encrypt data manually, see the scripts in the [`tools/`](tools/) directory (`recover_data.dart`, `reencrypt_data.dart`).

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
| Outlook fallback | NSAppleScript via Flutter method channel (`OutlookBridge.swift`) |
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
│   ├── todos_page.dart             # To-do board (To-Do / In Progress / On Hold / Done)
│   ├── notes_page.dart             # Saved meeting notes + edit
│   ├── accounts_page.dart          # Calendar account management + colour picker + SSRF guard
│   └── settings_page.dart          # API key + model selector + sync folder
├── providers/
│   └── app_providers.dart          # Riverpod providers
├── services/
│   ├── ai/claude_client.dart       # Anthropic API client (timeouts, email scrub)
│   ├── auth/token_store.dart       # Secure credential storage (Keychain + fallback)
│   ├── calendar/
│   │   ├── calendar_manager.dart   # Aggregates ICS feeds + Outlook fallback + deduplication
│   │   ├── ics_calendar_service.dart  # RFC 5545 parser (TZID, RRULE, EXDATE)
│   │   └── outlook_calendar_service.dart  # Outlook for Mac fallback via method channel
│   ├── meeting_poller.dart         # Live meeting detection
│   └── storage/app_database.dart   # AES-256-GCM encrypted local JSON store + key file
├── widgets/
│   ├── app_scaffold.dart           # Sidebar + navigation
│   ├── quick_note_dialog.dart      # Meeting note capture + AI consent dialog
│   └── timezone_picker_dialog.dart # Meeting time correction dialog
├── core/
│   ├── constants.dart              # App-wide constants (sync interval, leave keywords)
│   ├── time_utils.dart             # Timezone helpers + Windows↔IANA map
│   └── theme/                      # Catppuccin Mocha theme
macos/Runner/
├── OutlookBridge.swift             # NSAppleScript method channel (Outlook fallback)
└── MainFlutterWindow.swift         # Registers OutlookBridge on startup
tools/
├── recover_data.dart               # CLI tool to decrypt and inspect the data file
└── reencrypt_data.dart             # CLI tool to re-encrypt the data file with a new key
```

---

## Documentation & Development

See the `docs/` directory for build and development instructions:

- [Flutter App Setup & Build](docs/FLUTTER_APP_SETUP.md)

---

## License

MIT
