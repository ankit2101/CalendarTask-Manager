# Workspace Architecture

This document describes the high-level architecture of CalendarTask-Manager. The workspace is currently a "hybrid" monorepo that contains two parallel implementations:
1. A **Flutter-based macOS native application**.
2. An **Electron-based React desktop application**.

The features across both apps handle: ICS Calendar Syncing, Tasks / To-Do management, Meeting Notes, and Claude AI API extraction.

---

## 1. Flutter Application (Original Application)

The Flutter application resides primarily in:
- `lib/`: The main Dart application code.
- `macos/`: The macOS specific deployment & capability configurations.

### Key Technologies:
* **State Management:** Riverpod (`flutter_riverpod`)
* **Local Storage / Persistence:** Local JSON file storage (`sqflite`/`path_provider`) and Keychain via `flutter_secure_storage` or `macos_secure_bookmarks`.
* **Network & API:** Dio HTTP client (`dio`).
* **Design / Theme:** Custom Catppuccin Mocha.

### Implementation Structure
* `lib/models/`: Dart data models representing Calendars, Events, Tasks, and Settings.
* `lib/services/`: Core logic:
    * `ai/claude_client.dart`: Wraps the Anthropic API.
    * `calendar/`: Custom ICS parsing using `rfc5545`.
* `lib/pages/`: UI screens (Dashboard, Todos, Notes, Accounts, Settings).
* `lib/providers/`: Global Riverpod state containers binding services to UI.

---

## 2. Electron + React Application (New Port)

The new web-technologies based app was introduced explicitly for wider desktop compatibility and potential React-centric features.
It resides in:
- `src/`: The TypeScript frontend and backend code.
- `package.json` & `forge.config.ts`: Configuration.

### Key Technologies:
* **Framework:** Electron + React (`react`, `react-dom`).
* **Routing:** React Router (`react-router-dom`), using a HashRouter to avoid file protocol path issues.
* **Build System:** Electron Forge with Webpack templates (`@electron-forge/*`).
* **AI & Calendar Syncing:** `@anthropic-ai/sdk`, `node-ical`.
* **State & Local Storage:** `electron-store`, `keytar` for secret keys.

### Implementation Structure
* `src/main/`: Core Electron "Backend"
    * `main-window.ts`, `quick-note-window.ts`: BrowserWindow managers.
    * `services/`: Calendar-syncing, app state, and meeting-detection loops.
    * `ipc/handlers.ts`: Bridges renderer queries with Main process functionality.
* `src/renderer/`: Core React "Frontend"
    * `App.tsx`: Contains routing configurations pointing to layout and respective pages.
    * `pages/`: Includes exact analogs to the Flutter implementations (Dashboard, Todos, History, Accounts, Settings).
* `src/shared/`: Shared TypeScript types and IPC channels between the main process and the renderer.

---

## Data Consistency

Both versions (when running locally) interact with the same underlying AI infrastructure (Claude API) and are designed to solve the exact same workspace organization problems. Currently, their internal file-persistence (`calendartask_data.json` vs `electron-store`) is partitioned unless explicitly configured otherwise via shared folder states.
