import { BrowserWindow } from 'electron';
import { NormalizedEvent } from '../../shared/types/calendar';
import { IpcChannel } from '../../shared/types/ipc-channels';

declare const MAIN_WINDOW_WEBPACK_ENTRY: string;
declare const MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY: string;

let quickNoteWindow: BrowserWindow | null = null;

export function openQuickNoteWindow(event?: NormalizedEvent): void {
  if (quickNoteWindow) {
    quickNoteWindow.focus();
    return;
  }

  quickNoteWindow = new BrowserWindow({
    width: 480,
    height: 400,
    alwaysOnTop: true,
    frame: false,
    resizable: false,
    skipTaskbar: true,
    vibrancy: 'under-window',
    visualEffectState: 'active',
    webPreferences: {
      preload: MAIN_WINDOW_PRELOAD_WEBPACK_ENTRY,
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  // Load the main app but with a hash route for quick note
  const url = new URL(MAIN_WINDOW_WEBPACK_ENTRY);
  url.hash = '/quick-note';
  quickNoteWindow.loadURL(url.toString());

  quickNoteWindow.center();

  quickNoteWindow.webContents.on('did-finish-load', () => {
    if (event && quickNoteWindow) {
      quickNoteWindow.webContents.send(IpcChannel.MEETING_ENDED, event);
    }
  });

  quickNoteWindow.on('closed', () => {
    quickNoteWindow = null;
  });

  quickNoteWindow.show();
}

export function closeQuickNoteWindow(): void {
  if (quickNoteWindow) {
    quickNoteWindow.close();
    quickNoteWindow = null;
  }
}

export function getQuickNoteWindow(): BrowserWindow | null {
  return quickNoteWindow;
}
