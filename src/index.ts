import { app, BrowserWindow } from 'electron';
import * as path from 'path';
import Module from 'module';

// Patch Node's module resolution so that external packages (node-ical, keytar)
// can be found when the webpack bundle runs from .webpack/main/ inside an asar.
// Without this, require('node-ical') fails because Node only searches upward
// from .webpack/main/ and doesn't find the root-level node_modules.
const appRoot = app.isPackaged
  ? app.getAppPath()                         // e.g. /path/to/app.asar
  : path.resolve(__dirname, '..', '..');     // dev: project root
const extraModulePath = path.join(appRoot, 'node_modules');
if (!((Module as any)._nodeModulePaths('') as string[]).includes(extraModulePath)) {
  (Module as any).globalPaths.push(extraModulePath);
}

import { registerIpcHandlers, setupMeetingEventForwarding } from './main/ipc/handlers';
import { initTray } from './main/tray';
import { registerShortcuts } from './main/shortcuts';
import { createMainWindow, showMainWindow } from './main/windows/main-window';
import { openQuickNoteWindow } from './main/windows/quick-note-window';
import { getMeetingDetector } from './main/services/meeting/meeting-detector';
import { getCalendarManager } from './main/services/calendar/calendar-manager';
import { appStore } from './main/store/app-store';
import { initMicrosoftAuth } from './main/services/auth/microsoft-auth';
import { getGoogleAuth } from './main/services/auth/google-auth';
import { tokenStore } from './main/services/auth/token-store';
import { IpcChannel } from './shared/types/ipc-channels';

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) {
  app.quit();
}

async function initializeApp(): Promise<void> {
  const settings = appStore.getSettings();

  // macOS: run as menu bar app (no dock icon by default)
  if (process.platform === 'darwin' && !settings.showDockIcon) {
    app.dock?.hide();
  }

  // Initialize Microsoft auth if clientId is stored
  const msClientId = await tokenStore.loadSecret('ms-client-id');
  if (msClientId) {
    initMicrosoftAuth(msClientId);
  }

  // Initialize Google auth credentials if stored
  const googleClientId = await tokenStore.loadSecret('google-client-id');
  const googleClientSecret = await tokenStore.loadSecret('google-client-secret');
  if (googleClientId && googleClientSecret) {
    const googleAuth = getGoogleAuth();
    googleAuth.setCredentials({ clientId: googleClientId, clientSecret: googleClientSecret });

    // Restore existing Google accounts
    const googleAccounts = appStore.getGoogleAccounts();
    for (const account of googleAccounts) {
      try {
        await googleAuth.restoreAccount(account.id);
      } catch (e) {
        console.warn(`Failed to restore Google account ${account.email}:`, e);
      }
    }
  }

  // Register IPC handlers
  registerIpcHandlers();

  // Set up tray
  initTray(showMainWindow, () => openQuickNoteWindow());

  // Register global shortcuts
  registerShortcuts(
    settings.globalShortcutQuickNote,
    settings.globalShortcutToggleApp,
    () => openQuickNoteWindow(),
    showMainWindow
  );

  // Set launch at login
  app.setLoginItemSettings({ openAtLogin: settings.launchAtLogin });

  // Start meeting detector (only if we have accounts)
  const hasAccounts =
    appStore.getMicrosoftAccounts().length > 0 ||
    appStore.getGoogleAccounts().length > 0;

  if (hasAccounts) {
    setupMeetingEventForwarding();
    getMeetingDetector().start();
  }

  // Show main window on first launch (no accounts configured)
  if (!hasAccounts) {
    createMainWindow();
  }

  // Background calendar sync every 10 minutes
  const SYNC_INTERVAL_MS = 10 * 60 * 1000;
  setInterval(async () => {
    try {
      const events = await getCalendarManager().fetchAllEvents();
      BrowserWindow.getAllWindows().forEach(win => {
        if (!win.isDestroyed()) {
          win.webContents.send(IpcChannel.CALENDAR_SYNCED, events);
        }
      });
    } catch (e) {
      console.error('[bg-sync] Calendar sync failed:', e);
    }
  }, SYNC_INTERVAL_MS);
}

app.on('ready', () => {
  initializeApp().catch(err => {
    console.error('App initialization failed:', err);
  });
});

// On macOS, keep app running even when all windows are closed (it lives in menu bar)
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  // Re-show main window on dock icon click (if dock is shown)
  showMainWindow();
});
