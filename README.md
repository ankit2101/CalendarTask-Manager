# CalendarTask Manager

A macOS menu bar app that connects your calendars, captures meeting notes with AI-extracted action items, and keeps your to-do list in one place.

---

## Features

### 📅 Calendar
- Connect **Google Calendar**, **Microsoft Outlook**, and **ICS feeds**
- View events across all accounts in a single daily view
- Navigate forward and backward through dates
- Each calendar account gets a distinct color
- Leave/OOO events (PTO, vacation, out of office, etc.) are automatically hidden
- Refresh pulls the latest events from all connected accounts

### ✏️ Meeting Notes
- **Add Notes** button on every past meeting — works even if the app wasn't running when the meeting ended
- Claude AI extracts action items from your notes automatically
- Review and edit extracted items before saving (set priority, due date)
- Meetings missing notes are highlighted in amber so nothing slips through
- Notes are searchable from the **Notes** tab

### ✅ To-Do Board
- Three buckets: **Pending**, **In Progress**, **Completed**
- Priority scale 1–5 (default 3); tasks older than 2 days auto-escalate in priority
- Set priority manually to lock it and stop auto-escalation
- Action items extracted from meeting notes are added automatically as Pending tasks, tagged with the meeting name and date

### 💾 Backup & Restore
- Configure a local folder in Settings
- Backup file (`caltask-backup.json`) is created immediately and updated automatically on every change
- One-click restore from backup if something goes wrong

### 🗂 Microsoft Planner Integration
- Push extracted action items directly to a Planner plan/bucket
- Requires a Microsoft Azure app registration (see setup below)

---

## Requirements

- macOS
- Node.js 18+
- A [Claude API key](https://console.anthropic.com/) for AI note extraction

---

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Start in development mode

```bash
npm start
```

### 3. Configure credentials (Settings tab)

| Field | Where to get it |
|---|---|
| **Claude API Key** | [console.anthropic.com](https://console.anthropic.com/) |
| **Google OAuth Client ID / Secret** | [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials → OAuth 2.0 Client (Desktop app). Enable the **Google Calendar API**. |
| **Microsoft Azure Client ID** | [portal.azure.com](https://portal.azure.com) → Azure Active Directory → App registrations → New registration. Add redirect URI `http://localhost` (Mobile/Desktop). Grant permissions: `Calendars.Read`, `Tasks.ReadWrite`, `User.Read`. |

### 4. Add calendar accounts

Go to the **Accounts** tab and connect your Google or Microsoft accounts. ICS feeds can be added with a public `.ics` URL.

---

## Building

```bash
# Package the app
npm run package

# Create a distributable (.dmg, .zip)
npm run make
```

---

## Data Storage

All data is stored locally using `electron-store` (in `~/Library/Application Support/calendar-task-manager/`). You can configure an additional backup folder in **Settings → Data Storage & Backup** — the app writes `caltask-backup.json` there automatically after every change.

### Backup format

```json
{
  "version": 1,
  "exportedAt": "2026-03-26T14:00:00.000Z",
  "meetingHistory": [...],
  "todoTasks": [...]
}
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Shell | Electron 41 |
| UI | React 19, React Router 7 |
| Language | TypeScript 5 |
| Bundler | Webpack (via Electron Forge) |
| Persistence | electron-store |
| Secrets | macOS Keychain (keytar) |
| AI | Anthropic Claude (`claude-opus-4-5`) |
| Google auth | googleapis + OAuth 2.0 |
| Microsoft auth | @azure/msal-node |
| ICS parsing | node-ical |
| Theme | Catppuccin Mocha |

---

## Project Structure

```
src/
├── main/                  # Electron main process
│   ├── ipc/handlers.ts    # All IPC channel handlers
│   ├── services/
│   │   ├── ai/            # Claude API integration
│   │   ├── auth/          # Google + Microsoft OAuth
│   │   ├── calendar/      # Calendar fetching (Google, Outlook, ICS)
│   │   ├── meeting/       # Meeting end detection
│   │   └── planner/       # Microsoft Planner task creation
│   ├── store/             # electron-store persistence + auto-export
│   └── windows/           # Main window + Quick Note window
├── renderer/              # React frontend
│   ├── pages/
│   │   ├── Dashboard.tsx  # Daily calendar view
│   │   ├── Todos.tsx      # To-do board
│   │   ├── History.tsx    # Meeting notes
│   │   ├── Accounts.tsx   # Account management
│   │   ├── Settings.tsx   # App settings + backup
│   │   └── QuickNote.tsx  # Floating note capture window
│   └── components/
│       └── Layout.tsx     # Sidebar navigation
├── shared/
│   └── types/             # Shared TypeScript types
└── preload.ts             # Context-bridged IPC API
```

---

## License

MIT
