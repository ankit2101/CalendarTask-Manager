import { app } from 'electron';
import { registerIpcHandlers, setupMeetingEventForwarding } from './main/ipc/handlers';
import { initTray } from './main/tray';
import { registerShortcuts } from './main/shortcuts';
import { createMainWindow, showMainWindow } from './main/windows/main-window';
import { openQuickNoteWindow } from './main/windows/quick-note-window';
import { getMeetingDetector } from './main/services/meeting/meeting-detector';
import { appStore } from './main/store/app-store';
import { initMicrosoftAuth } from './main/services/auth/microsoft-auth';
import { getGoogleAuth } from './main/services/auth/google-auth';
import { tokenStore } from './main/services/auth/token-store';

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
