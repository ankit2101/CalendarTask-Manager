import { app, BrowserWindow } from 'electron';
import { registerIpcHandlers, setupMeetingEventForwarding } from './main/ipc/handlers';
import { initTray } from './main/tray';
import { registerShortcuts } from './main/shortcuts';
import { createMainWindow, showMainWindow } from './main/windows/main-window';
import { openQuickNoteWindow } from './main/windows/quick-note-window';
import { getMeetingDetector } from './main/services/meeting/meeting-detector';
import { getCalendarManager } from './main/services/calendar/calendar-manager';
import { appStore } from './main/store/app-store';
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
  const hasAccounts = appStore.getICSAccounts().length > 0;

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
