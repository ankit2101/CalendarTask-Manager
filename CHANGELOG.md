# Changelog

All notable changes to CalendarTask Manager are documented here.

---

## [3.1.6] — 2026-04-23

### Added
- **Cross-machine sync via OneDrive / iCloud / Dropbox** — when you point the app to a shared cloud folder, a companion key file (`calendartask_key.b64`) is written alongside the data file. All machines using that folder share the same encryption key, so each machine can read data written by the other. The sync folder setting is now available on both macOS and Windows.

---

## [3.1.5] — 2026-04-23

### Changed
- **Model list updated** — removed retired Claude 3 and 3.5 models (`claude-3-5-sonnet-20241022`, `claude-3-5-haiku-20241022`, `claude-3-haiku-20240307`) that returned "Model not found" errors; replaced with current Claude 4.x models: Opus 4.7, Sonnet 4.6, and Haiku 4.5
- Users with a retired model saved in settings automatically fall back to the default (Claude Sonnet 4)

---

## [3.1.4] — 2026-04-16

### Added
- **On Hold status** — tasks can be put on hold with a resume date and time; escalation is paused while on hold
- **Auto-resume** — on-hold tasks automatically move back to Pending when the hold period expires (checked on every app launch)
- **Hold-until display** — task cards show "Resumes MMM d, yyyy – h:mm a" while on hold
- **On Hold filter chip** — filter task list to show only on-hold tasks
- Sort order updated: In Progress → Pending → On Hold → Done

---

## [3.1.3] — 2026-04-16

### Added
- **Task status picker** — tapping the status icon now opens a popup menu to directly select any status (To Do / In Progress / Done), replacing the forward-only cycle; current status is highlighted with a checkmark

---

## [3.1.2] — 2026-04-16

### Changed
- No functional changes; version bump to trigger clean CI release build

---

## [3.1.1] — 2026-04-16

### Added
- **Account rename** — tap the edit icon on any account tile to rename its display name inline, consistent with the existing colour picker interaction

### Fixed
- **Colour picker black bug** — `colorToHex` now correctly multiplies normalised r/g/b channels by 255 before hex encoding; selecting black no longer produced wrong colours
- **Per-calendar colour on event cards** — event cards now show the correct account colour as a left border

---

## [3.0.9] — 2026-04-15

### Fixed
- **macOS "app can't be opened" error** — The app is now ad-hoc signed with `codesign` in CI so macOS Gatekeeper accepts it without an Apple Developer certificate
- Bundled **"Install CalendarTask Manager.command"** helper script inside the DMG — double-clicking it installs the app to /Applications and clears the quarantine flag automatically (no Terminal required)
- Improved macOS installation instructions in release notes with three clear options: helper script, Terminal `xattr -cr`, and System Settings → Open Anyway

---

## [3.0.8] — 2026-04-15

### Fixed
- **macOS crash on launch** (`PlatformException Code: -34018 errSecMissingEntitlement`) — added missing `keychain-access-groups` entitlement to both `DebugProfile.entitlements` and `Release.entitlements` so the sandboxed app can access macOS Keychain
- Added graceful Keychain availability probe in `TokenStore` and `AppDatabase`: if the entitlement is absent (e.g. ad-hoc signed builds without a real Apple Team ID), the app falls back to SharedPreferences instead of crashing on startup
- Existing API keys and encrypted data survive the upgrade — migration path from SharedPreferences → Keychain is preserved

---

## [3.0.7] — 2026-04-14

### Security (Critical & High)

- **AES-256-GCM encryption** — local data file (`calendartask_data.json`) is now encrypted with authenticated AES-256-GCM instead of unencrypted JSON. Detects any on-disk tampering. Legacy AES-CBC files are transparently migrated to GCM on first load (versioned `v2:` format prefix)
- **Keychain credential storage** — Claude API key moved from SharedPreferences (world-readable plist) to the OS keychain (macOS Keychain / Windows Credential Manager). Existing keys are migrated automatically on first launch
- **SSRF protection** — calendar feed URLs are now validated before fetching; private-network addresses (localhost, 127.x, 10.x, 172.16–31.x, 192.168.x, 169.254.x, ::1) are blocked
- **AI privacy consent** — a one-time dialog informs users before any meeting content is sent to the Claude API; calling Claude without consent is silently skipped
- **Attendee email scrubbing** — attendee email addresses are stripped from Claude prompts; only display names are sent
- **ICS fetch limits** — Dio HTTP client now enforces 10 s connect timeout, 30 s receive timeout, and a 10 MB response size cap to prevent resource exhaustion
- **RRULE INTERVAL clamp** — `INTERVAL=0` in recurring rules (which caused infinite loops) is now clamped to the range `[1, 366]`
- **EXDATE cap** — exception date lists are capped at 2,000 entries to prevent memory exhaustion from malformed feeds
- **Import validation** — each record in an imported data file is individually validated via `fromJson()` in a try/catch; a single malformed entry can no longer crash the app or corrupt the store

---

## [3.0.6] — 2026-04-13

### Fixed
- **ICS timezone parsing bug** — `DTSTART;TZID=America/Denver:...` was silently ignoring the `TZID` parameter because the property key lookup found the bare `DTSTART` key before the parametrized `DTSTART;TZID=...` key. Fixed by searching for the parametrized form first
- Timezone abbreviations with surrounding quotes (e.g. `"PST"`) are now stripped before Windows↔IANA lookup

---

## [3.0.5] — 2026-04-12

### Added
- **Dual timezone display** on calendar event cards — when a calendar event specifies a source timezone different from your local system timezone, the card shows both times:
  - Source timezone time in subdued text (e.g. "8:30 AM – 9:00 AM MST")
  - Local system time in normal text (e.g. "9:30 PM – 10:00 PM IST")
- Full IANA timezone support via the `timezone` package and a Windows↔IANA name translation map

---

## [3.0.4] and earlier

Initial releases with core calendar, notes, and to-do functionality.
