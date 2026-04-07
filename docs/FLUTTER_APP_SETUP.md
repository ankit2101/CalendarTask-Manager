# Flutter Development Guide

This guide details configuring and running the Flutter based macOS native version of CalendarTask-Manager.

## Prerequisites
Requires a macOS build environment:
- **Flutter SDK**: `^3.11.4` (Ensure this aligns via `flutter doctor`).
- **CocoaPods**: Required to link macOS proprietary APIs.

You can install the dependencies via Homebrew:
```bash
brew install flutter
brew install cocoapods
```

## Setup & Running

**1. Clone and fetch dependencies**
```bash
flutter pub get
```

**2. Link macOS dependencies via Pods**
```bash
cd macos
pod install
cd ..
```

**3. Run the development build**
```bash
flutter run -d macos
```

## Project Boundaries

### State Management
State is managed using `Riverpod`.
Changes generally flow as such:
1. `Provider` exposes an interface to state/data (found in `lib/providers`).
2. Data logic runs from asynchronous APIs (`lib/services`).
3. UI widgets (`ConsumerWidget` via `flutter_riverpod`) observe providers and react immediately without manual `setState`.

### macOS Specifics
CalendarTask-Manager interacts securely with macOS by utilizing:
- `flutter_secure_storage` which hooks into the standard **Apple Keychain**.
- `macos_secure_bookmarks` which persists user-given read/write permissions for specific disk locations over subsequent app executions (vital for App Sandbox policies).

## Building a Production release

To cut a `.app` macOS binary and package it into a `.dmg`.

**1. Create the optimized application build**
```bash
flutter build macos --release
```
*(The binary drops in `build/macos/Build/Products/Release/calendar_task_manager.app`)*

**2. Package the app image**
Use the `create-dmg` tool (available from `brew`):
```bash
brew install create-dmg

create-dmg \
  --volname "CalendarTaskManager" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "calendar_task_manager.app" 180 170 \
  --hide-extension "calendar_task_manager.app" \
  --app-drop-link 480 170 \
  "CalendarTaskManager.dmg" \
  "build/macos/Build/Products/Release/calendar_task_manager.app"
```
