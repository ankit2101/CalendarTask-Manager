# Electron Development Guide

This guide covers building, running, and developing against the Electron React port of CalendarTask-Manager.

## Prerequisites
- **Node.js**: `v18` or `v20` recommended.
- **Package Manager**: Make sure you use standard `npm` to resolve dependencies.

## Setup
Install the necessary package.json dependencies:
```bash
npm install
```

## Running the Application
To start the application in development mode with HMR (Hot Module Replacement) enabled for React:

```bash
npm run start
```

*Note: Running `npm run start` launches Electron Forge with Webpack, which will bundle `src/main` and `src/renderer` outputs dynamically.*

## Architecture specifics
### IPC Communication
The React frontend (in `src/renderer`) cannot execute Node.js commands (like filesystem access, HTTP requests, or keychain access). Thus, anything that needs to use Node modules is implemented in `src/main/` and accessible via inter-process communication (IPC).

Ensure to configure changes in:
1. `src/shared/types/ipc-channels.ts`: define new channel constants.
2. `src/main/ipc/handlers.ts`: wire the channel listeners.
3. `src/preload.ts`: map the IPC invokes under `window.api`.

### Packaging for Release
To package the app into a macOS App bundle without creating distribution formats just yet:
```bash
npm run package
```

To create full distributor images (`.dmg`, `.zip`):
```bash
npm run make
```

Outputs will be stored in the `out/` folder at the root.

## Linter Tools
Run ESLint over the entire project:
```bash
npm run lint
```
