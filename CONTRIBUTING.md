# Contributing to CalendarTask Manager

Thanks for your interest in improving CalendarTask Manager! This document covers
how to get a development build running and the conventions used in this repo.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.x (Dart SDK ^3.11.4)
- **macOS:** Xcode + command line tools
- **Windows:** Visual Studio with the "Desktop development with C++" workload

Verify your setup with:

```bash
flutter doctor
```

## Getting Started

```bash
git clone https://github.com/ankit2101/CalendarTask-Manager.git
cd CalendarTask-Manager
flutter pub get
flutter run -d macos      # or: flutter run -d windows
```

See [docs/FLUTTER_APP_SETUP.md](docs/FLUTTER_APP_SETUP.md) for detailed build
instructions.

## Project Layout

The codebase is organized under `lib/` (see the **Project Structure** section in
the [README](README.md)). The short version:

- `pages/` — top-level screens (dashboard, todos, notes, accounts, settings)
- `services/` — calendar (ICS + Outlook fallback), AI (Claude client), storage,
  auth
- `core/` — constants, timezone helpers, theme
- `models/` — data models

## Before You Submit

Run the analyzer, formatter, and tests:

```bash
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

CI runs the release build on tagged versions; please make sure `flutter analyze`
is clean before opening a PR.

## Pull Requests

1. Branch off `main`.
2. Keep changes focused — one logical change per PR.
3. Update [CHANGELOG.md](CHANGELOG.md) under a new "Unreleased" or version
   heading.
4. If you touch security-sensitive code (encryption, key handling, SSRF guards,
   ICS parsing), call it out explicitly in the PR description.
5. Reference any related issue number.

## Reporting Bugs & Requesting Features

Use the issue templates under
[`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE/). For **security**
vulnerabilities, do **not** open a public issue — follow
[SECURITY.md](SECURITY.md) instead.

## Code Style

- Follow the rules in [`analysis_options.yaml`](analysis_options.yaml)
  (`flutter_lints`).
- Match the surrounding code — naming, formatting, and comment density.
- State management uses Riverpod; navigation uses go_router. Stick to the
  existing patterns rather than introducing new ones.

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
