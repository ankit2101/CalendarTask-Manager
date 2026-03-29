# CalendarTask Manager

A native macOS app (Flutter) that connects your calendars, captures meeting notes with AI-extracted action items, and keeps your to-do list in one place.

---

## Download

Grab the latest `.dmg` from [Releases](https://github.com/ankit2101/CalendarTask-Manager/releases).

1. Open the DMG and drag **CalendarTask Manager** to your Applications folder
2. First launch: **right-click → Open** to bypass Gatekeeper
3. If macOS blocks it entirely, run: `xattr -cr /Applications/calendar_task_manager.app`

---

## Features

### 📅 Calendar
- Connect **Google Calendar**, **Microsoft Outlook**, and **ICS / Webcal feeds**
- View events across all accounts in a single daily view
- Navigate forward and backward through dates
- Live **IN PROGRESS** badge on meetings happening right now
- Leave/OOO events (PTO, vacation, out of office) are automatically hidden
- Private appointments shown with a 🔒 lock icon

### ✏️ Meeting Notes
- **+ Add Notes** button on every past meeting
- **+ Live Notes** button on meetings happening right now
- Edit saved notes at any time from the **Notes** tab
- Claude AI extracts action items from your notes automatically
- Review, edit, add, or delete action items before saving
- Re-extract action items after editing a note

### ✅ To-Do Board
- Three states: **To-Do → In Progress → Completed**
- Edit task title, description, and priority inline
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

- macOS 10.13+
- A [Claude API key](https://console.anthropic.com/)

---

## Setup

### 1. Install the app

Download `CalendarTaskManager.dmg` from [Releases](https://github.com/ankit2101/CalendarTask-Manager/releases) and drag to Applications.

### 2. Add your Claude API key

Open the app → **Settings** → paste your API key → **Save**.

### 3. Connect your calendar

Go to **Accounts** and choose one of the options below.

---

## Connecting Calendars

### Option A — ICS Feed (easiest, no OAuth needed)

Both Google Calendar and Outlook support a private ICS URL that works without any OAuth setup.

#### Google Calendar ICS

1. Open [calendar.google.com](https://calendar.google.com)
2. Click the **⚙ Settings** gear → **Settings**
3. In the left sidebar, click the calendar you want (under "Settings for my calendars")
4. Scroll down to **Secret address in iCal format**
5. Copy the URL (starts with `https://calendar.google.com/calendar/ical/...`)
6. In the app → **Accounts** → **ICS / Webcal** section → paste the URL → **Add**

#### Microsoft Outlook / Office 365 ICS

1. Open [outlook.office.com](https://outlook.office.com) or Outlook desktop
2. Click the **Calendar** icon
3. Click **Settings** (⚙) → **View all Outlook settings** → **Calendar** → **Shared calendars**
4. Under **Publish a calendar**, select your calendar and permission level → **Publish**
5. Copy the **ICS** link
6. In the app → **Accounts** → **ICS / Webcal** section → paste the URL → **Add**

> **iCloud Calendar ICS**
> 1. Open the Calendar app on Mac
> 2. Right-click a calendar → **Get Info** → check **Public Calendar**
> 3. Copy the URL shown → paste into the ICS section of the app

---

### Option B — Google OAuth (shows private events)

Requires a one-time Google Cloud setup.

1. Go to [console.cloud.google.com](https://console.cloud.google.com) → create a new project
2. **APIs & Services** → **Library** → search **Google Calendar API** → **Enable**
3. **APIs & Services** → **Credentials** → **+ Create Credentials** → **OAuth client ID**
4. Configure the OAuth consent screen if prompted (External, add your email as test user)
5. Application type: **macOS** (or Desktop app) → **Create**
6. Download the credentials → save as `GoogleService-Info.plist`
7. Place the file in `macos/Runner/` and add the reversed client ID URL scheme to `macos/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

8. Rebuild: `flutter run -d macos`
9. In the app → **Accounts** → **Add Google Account**

---

### Option C — Microsoft OAuth (shows private events)

1. Go to [portal.azure.com](https://portal.azure.com) → **Azure Active Directory** → **App registrations** → **New registration**
2. Platform: **Mobile and desktop applications**
3. Redirect URI: `msauth.com.example.calendartaskmanager://auth`
4. Under **API permissions** → add: `Calendars.Read`, `User.Read`
5. Copy the **Application (client) ID**
6. Paste it into `lib/services/calendar/microsoft_calendar_service.dart` at the `_microsoftClientId` constant
7. Rebuild: `flutter run -d macos`
8. In the app → **Accounts** → **Add Microsoft Account**

---

## Building from Source

### Prerequisites

```bash
# Install Flutter
brew install flutter

# Install CocoaPods
brew install cocoapods
```

### Run in development

```bash
git clone https://github.com/ankit2101/CalendarTask-Manager.git
cd CalendarTask-Manager
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos
```

### Build a release DMG

```bash
flutter build macos --release
brew install create-dmg
create-dmg \
  --volname "CalendarTask Manager" \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "calendar_task_manager.app" 150 185 \
  --app-drop-link 450 185 \
  "dist/CalendarTaskManager.dmg" \
  "build/macos/Build/Products/Release/"
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Dart / Flutter |
| State management | Riverpod |
| Persistence | SharedPreferences |
| AI | Anthropic Claude API |
| Google auth | google_sign_in |
| Microsoft auth | MSAL (via http) |
| ICS parsing | ical_parser |
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
│   ├── accounts_page.dart          # Calendar account management
│   └── settings_page.dart          # API key + model selector
├── providers/
│   └── app_providers.dart          # Riverpod providers
├── services/
│   ├── ai/claude_client.dart       # Anthropic API client
│   ├── auth/token_store.dart       # API key persistence
│   ├── calendar/
│   │   ├── calendar_manager.dart   # Aggregates all calendar sources
│   │   ├── google_calendar_service.dart
│   │   ├── microsoft_calendar_service.dart
│   │   └── ics_calendar_service.dart
│   ├── meeting_poller.dart         # Live meeting detection
│   └── storage/app_database.dart   # Local data persistence
├── widgets/
│   ├── app_scaffold.dart           # Sidebar + navigation
│   └── quick_note_dialog.dart      # Meeting note capture dialog
└── core/
    ├── constants.dart              # Claude model list
    └── theme/                      # Catppuccin Mocha theme
```

---

## Data Storage

All data is stored locally in `~/Library/Application Support/com.caltask.calendar_task_manager/` via SharedPreferences. No data is sent to any server except the Claude API when extracting action items.

---

## License

MIT
