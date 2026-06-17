# CalendarTask Manager

> A Flutter desktop app that unifies your calendars, records and transcribes meetings on-device, captures notes, and turns action items into tasks — with Claude AI built in.

**Platform:** macOS · Windows &nbsp;|&nbsp; **Version:** 4.0.0 &nbsp;|&nbsp; **License:** MIT

[![Release](https://img.shields.io/github/v/release/ankit2101/CalendarTask-Manager)](https://github.com/ankit2101/CalendarTask-Manager/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-blue)](https://github.com/ankit2101/CalendarTask-Manager/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What is this?

**The problem.** Back-to-back meetings scatter your day across calendars you can't see in one place, and the decisions and follow-ups made in those meetings evaporate the moment they end — leaving you to reconstruct action items from memory. The tools that promise to fix this (AI notetakers, meeting-bot transcribers) ship your conversations to someone else's cloud, which is a non-starter for confidential or regulated work and usually comes with a per-seat subscription.

**The solution.** CalendarTask Manager is a **native desktop app** for macOS and Windows that pulls all your calendars into a single daily view, **records and transcribes your meetings entirely on-device with Whisper**, and uses the **Anthropic Claude API** to summarize each conversation and turn it into tracked action items — then manages those tasks to completion. Everything is stored **locally and encrypted**; the recording never leaves your machine, and only the text you explicitly approve is ever sent to Claude.

**The benefit.** You walk out of every meeting with an accurate transcript, a summary, and a to-do list already populated — without trusting a third-party bot, paying a subscription, or wiring up OAuth. **No subscription. No cloud sync required. No meeting bots.** Just paste an ICS URL and go.

---

## Download

Grab the latest release from [**Releases →**](https://github.com/ankit2101/CalendarTask-Manager/releases)

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

- Connect any calendar via **ICS / Webcal feeds** — works with Google Calendar, Microsoft Outlook, iCloud, Fastmail, Proton Calendar, and any RFC 5545-compliant feed
- View events across all feeds in a single **daily view**
- Navigate forward and backward through dates
- Live **IN PROGRESS** badge on meetings happening right now
- Leave/OOO events (PTO, vacation, out of office) are automatically hidden
- Private appointments shown with a 🔒 lock icon
- **Per-calendar colour** — pick a colour for each feed; events inherit it on the day view
- **Inline rename** — edit a calendar account's display name directly in the Accounts tab
- **Auto-refresh** every 10 minutes (configurable in Settings) — no manual action needed
- **Resilient refresh** — if a feed is slow or temporarily unreachable, the last successfully-fetched events stay visible instead of the calendar going blank
- **Dual timezone display** — event cards show the original source timezone (e.g. "8:30 AM – 9:00 AM MST") alongside your local time (e.g. "9:30 PM IST")
- **Edit meeting time** — tap the ✏️ pencil icon on any event to correct the start/end time if it was captured in the wrong timezone; an **edited** badge marks overridden events and a reset button restores the original
- **Outlook for Mac fallback** — on corporate laptops where a security agent (e.g. Microsoft Defender for Endpoint, Zscaler) blocks anonymous ICS requests, the app automatically reads events from the locally installed Outlook app instead via AppleScript; no configuration needed
- **Dismiss** past meeting reminders with the × button

### 🎙️ Meeting Recording & On-Device Transcription

- **Record** button on active and upcoming meeting cards (and inside the note dialog) with a live elapsed timer and pulsing indicator
- **Captures both sides of the conversation** — your microphone (AVAudioEngine) **and** system audio from the meeting app (ScreenCaptureKit on macOS 13+), mixed into a single track
- **Fully on-device transcription** via a bundled **Whisper** (`whisper.cpp`) engine — no external binary, no network call, **audio never leaves your machine**
- **Choose your model** in Settings — Tiny, Base, Small, Medium, or Large-v3; models download once from Hugging Face and run locally thereafter
- **Auto-summary** — when transcription finishes, Claude generates a concise meeting summary and extracts action items
- **Mic-only fallback** — if system-audio capture is unavailable (permission denied or macOS < 13), recording continues with the microphone alone
- Transcript and summary are saved with the meeting and editable before saving
- Audio files are deleted after transcription by default (keep them via **Settings → Recording**)

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

### 🤖 Claude AI Integration

Uses the [Anthropic Claude API](https://console.anthropic.com/) to summarize meetings and extract action items from your transcript, AI summary, and notes combined.

Choose your Claude model in **Settings**:

| Model | ID | Notes |
|---|---|---|
| Claude Fable 5 | `claude-fable-5` | Newest |
| Claude Opus 4.8 | `claude-opus-4-8` | Most capable |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | **Default** |
| Claude Haiku 4.5 | `claude-haiku-4-5-20251001` | Fastest |
| Claude Opus 4.7 | `claude-opus-4-7` | Legacy |
| Claude Opus 4.6 | `claude-opus-4-6` | Legacy |
| Claude Sonnet 4.5 | `claude-sonnet-4-5-20250929` | Legacy |

- Model change takes effect immediately — no restart needed
- Attendee email addresses are stripped from prompts before sending to the API
- A Claude API key is **optional** — all calendar and task features work without one

### 🔒 Security & Privacy

- **Encrypted data file** — all local data is protected with **AES-256-GCM** authenticated encryption; any on-disk tampering is detected and rejected
- **Secure credential storage** — your Claude API key lives in the OS keychain (**macOS Keychain** / **Windows Credential Manager**), never in a plaintext file
- **SSRF protection** — calendar URLs are validated to block private-network addresses (localhost, RFC 1918 ranges, link-local)
- **Request limits** — ICS feeds are capped at 10 MB; HTTP connections time out at 15 s connect / 60 s receive; recurring event expansion is capped to prevent CPU abuse
- **On-device transcription** — meeting audio is transcribed locally with bundled Whisper; the recording itself **never leaves your machine** and is deleted after transcription by default
- **AI consent** — a one-time dialog informs you before any meeting content (transcript, summary, or notes) is sent to Claude
- **No telemetry** — no analytics, no crash reporting, no data leaves the device except Claude API calls you explicitly trigger

---

## Requirements

- **macOS** 10.13+ (Apple Silicon and Intel) — system-audio capture during recording requires **macOS 13+** (ScreenCaptureKit); older versions fall back to microphone-only
- **Windows** 10+ (64-bit)
- A [Claude API key](https://console.anthropic.com/) for AI features (optional — calendar, recording, and transcription all work without one)
- ~150 MB–3 GB free disk for the Whisper model you choose (downloaded once, on demand)

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
>
> **Large or slow Outlook feeds:** If your published ICS feed is large (~2 MB is common for busy Outlook calendars), the app uses a 60 s receive timeout to ensure the full download completes on corporate-managed networks. If a refresh still fails, the last successfully-fetched events are kept visible — the calendar never goes blank.

### iCloud Calendar

1. Open the **Calendar** app on Mac
2. Right-click a calendar → **Get Info** → check **Public Calendar**
3. Copy the URL shown → paste into the app

---

## Data Storage & Sync

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
| AI | Anthropic Claude API (Opus 4.8 / Sonnet 4.6 / Haiku 4.5) |
| Transcription | On-device **Whisper** (`whisper.cpp` via bundled `whisper.xcframework`) |
| Audio capture | AVAudioEngine (microphone) + ScreenCaptureKit (system audio, macOS 13+) via `RecordingBridge.swift` |
| ICS parsing | Custom RFC 5545 parser with full TZID, RRULE, EXDATE support |
| Outlook fallback | NSAppleScript via Flutter method channel (`OutlookBridge.swift`) |
| Timezones | IANA tz database (`timezone` package) + Windows↔IANA map |
| HTTP | Dio (15 s connect / 60 s receive, 10 MB response cap, retry with backoff) |
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
│   ├── ai/claude_client.dart       # Anthropic API client (summary + action items, email scrub)
│   ├── ai/whisper_service.dart     # Whisper model download/management + transcription
│   ├── recording/recording_service.dart  # Method-channel wrapper around RecordingBridge
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
├── RecordingBridge.swift           # Mic + system-audio capture, mixing, Whisper transcription
└── MainFlutterWindow.swift         # Registers Outlook + Recording bridges on startup
macos/whisper.xcframework/          # Bundled on-device Whisper engine (macOS universal slice)
tools/
├── recover_data.dart               # CLI tool to decrypt and inspect the data file
└── reencrypt_data.dart             # CLI tool to re-encrypt the data file with a new key
```

---

## Documentation & Development

See the `docs/` directory for build and development instructions:

- [Flutter App Setup & Build](docs/FLUTTER_APP_SETUP.md)

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

**Latest (v4.0.0):**
- **Meeting recording** — capture microphone + system audio (ScreenCaptureKit on macOS 13+) directly from meeting cards
- **On-device Whisper transcription** — bundled `whisper.xcframework` transcribes locally; audio never leaves your machine
- **Whisper model management** — download/delete Tiny → Large-v3 models from Settings → Recording
- **Auto-summary** — Claude summarizes the transcript and extracts action items automatically
- **Richer action-item extraction** — combines transcript, summary, and notes

**v3.3.5:**
- Claude API key now persists reliably across debug and ad-hoc release builds — no more silent key loss when switching build types

**v3.3.4:**
- Added **Claude Fable 5** to the model picker
- Automatic weekly model sync — model list updates from the API on startup

---

## License

MIT
