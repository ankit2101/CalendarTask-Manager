# Changelog

All notable changes to CalendarTask Manager are documented here.

---

## [3.3.1] — 2026-06-03

### Fixed
- **Outlook/Office365 calendars no longer go blank on refresh** — large, slow Exchange Online feeds (e.g. a ~2 MB published `.ics`) frequently exceeded the 30s receive timeout on corporate-managed networks, and a failed fetch silently overwrote the cache, dropping all of that account's events. The receive timeout is now 60s (connect 15s), and each account **retains its last successfully-fetched events** when a refresh fails — so a slow or flaky feed no longer empties the calendar.
- **Refresh keeps showing events while fetching** — a manual or auto refresh no longer blanks the list to a spinner when events are already loaded; the existing events stay visible until new data arrives, and a transient failure is no longer surfaced as a full-screen error when cached events exist.

### Changed
- **Smarter retry on transient failures** — ICS fetches now retry HTTP 429 (throttling, honouring `Retry-After`), 5xx, and connection errors with backoff, while receive/send timeouts fail fast to the retained events instead of multiplying the wait. The local Outlook fallback now also triggers on throttle/transient errors, not just auth rejections.
- Added per-attempt diagnostic logging (`[ICS] fetch attempt …`) recording HTTP status, error type, and `Retry-After` for easier field diagnosis.

---

## [3.2.0] — 2026-06-02

### Added
- **Outlook for Mac fallback** — when an Outlook ICS feed returns an auth error (HTTP 400/401/403), the app now automatically reads events from the locally installed Microsoft Outlook app via AppleScript. This fixes calendars that silently stop loading on corporate laptops where Microsoft Defender for Endpoint routes all traffic through Azure, causing Exchange Online to reject anonymous ICS requests. On first use, macOS will ask permission to control Outlook — click OK.
- **Claude model list updated to current Anthropic lineup** — replaced the old model IDs with the current generation:
  - Claude Opus 4.8 (newest, most capable)
  - Claude Sonnet 4.6 (default)
  - Claude Haiku 4.5 (fastest)
  - Claude Opus 4.7, 4.6, Sonnet 4.5 (legacy, still available)
  - Removed deprecated Claude Sonnet 4 (`claude-sonnet-4-20250514`, retiring June 2026) and the wrong Sonnet 4.5 date (`20251115` → corrected to `20250929`)
- **Default model changed** from deprecated Claude Sonnet 4 to Claude Sonnet 4.6

### Changed
- Per-calendar colour picker and inline account rename are now documented in the README
- Auto-refresh interval corrected in README (10 min, not 15)
- README sync section now explains the two-file setup (`calendartask_data.json` + `calendartask_key.b64`) required for cross-machine sync

---

## [3.1.8] — 2026-06-01

### Fixed
- **Backward-compatible cross-machine sync for pre–key-file encrypted data** — when no encryption key is found for an existing `v2:` data file (e.g. the file was created before the shared-key-file feature, so its key only exists in the original machine's Keychain), the app now preserves the file and shows empty state rather than silently generating a **wrong** random key and writing it to `calendartask_key.b64`. Previously this poisoned the key file in the shared folder, preventing the original machine from ever writing the correct key and making the data permanently inaccessible on all machines.
- **Plaintext-migration data loss** — if saving the encrypted version of a legacy plaintext file failed (e.g. an I/O error mid-write), the outer catch block previously wiped `_data = {}`, losing data that had already been decoded. The save is now isolated in its own try/catch so a failed write only skips the migration — data remains accessible in the current session.
- **External-reload key generation** — file-watcher reloads triggered by another machine writing to the sync folder no longer generate a new random key when the file cannot be decrypted, preventing the same key-file poisoning via the watcher path.

---

## [3.1.7] — 2026-05-27

### Fixed
- **Data file no longer overwritten on key mismatch** — when choosing a sync folder whose data file cannot be decrypted yet (e.g. the shared key file has not finished syncing from OneDrive/iCloud/Dropbox), the app now preserves the existing file and shows empty data until the key file arrives. Previously, a failed decryption would trigger a migration that silently overwrote the shared file with empty data.
- **Clearer sync folder feedback** — the confirmation message after choosing a folder now distinguishes between "Loaded existing data file from …" (existing file adopted) and "Created new data file at …" (new file written).

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
