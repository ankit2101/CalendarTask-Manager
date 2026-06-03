# Security Policy

CalendarTask Manager is built with security as a first-class concern. Local data
is encrypted with AES-256-GCM, API keys are stored in the OS keychain, and
calendar feed URLs are validated against SSRF. If you find a way to break any of
these guarantees, please report it.

## Supported Versions

Only the latest release receives security fixes.

| Version | Supported |
|---------|-----------|
| 3.2.x   | ✅        |
| < 3.2   | ❌        |

## Reporting a Vulnerability

**Please do not open a public issue for security vulnerabilities.**

Instead, report privately via one of:

- **GitHub Private Vulnerability Reporting** — go to the
  [Security tab](https://github.com/ankit2101/CalendarTask-Manager/security/advisories/new)
  and open a draft advisory (preferred).
- **Email** — ankit17.ag@gmail.com with the subject line
  `[CalendarTask Security]`.

Please include:

- A description of the vulnerability and its impact
- Steps to reproduce (proof of concept if possible)
- The app version and platform (macOS / Windows)

## What to Expect

- Acknowledgement within **5 business days**.
- An assessment and remediation plan once the report is triaged.
- Credit in the release notes when the fix ships, unless you prefer to remain
  anonymous.

## Scope

In scope:

- Data-at-rest encryption (`calendartask_data.json`, key handling)
- Credential storage (Claude API key in Keychain / Credential Manager)
- SSRF protections on calendar feed fetching
- ICS parsing (resource exhaustion, injection)
- The Outlook AppleScript bridge

Out of scope:

- Vulnerabilities in third-party dependencies (report those upstream, though a
  heads-up is appreciated)
- Issues requiring a compromised OS account or physical device access
- The Anthropic Claude API itself
