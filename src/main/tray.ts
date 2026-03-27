import { Tray, Menu, nativeImage, app } from 'electron';
import * as path from 'path';
import { NormalizedEvent } from '../shared/types/calendar';

let tray: Tray | null = null;
let onShowMain: (() => void) | null = null;
let onQuickNote: (() => void) | null = null;

function formatTime(isoString: string): string {
  return new Date(isoString).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export function initTray(
  showMain: () => void,
  quickNote: () => void
): void {
  onShowMain = showMain;
  onQuickNote = quickNote;

  // Use a simple default icon (16x16 template image for macOS)
  const icon = nativeImage.createEmpty();
  tray = new Tray(icon);
  tray.setToolTip('Calendar Task Manager');

  // macOS: left click should show context menu (since we're a menu bar app)
  tray.on('click', () => {
    tray?.popUpContextMenu();
  });

  updateTray([]);
}

export function updateTray(upcomingEvents: NormalizedEvent[]): void {
  if (!tray) return;

  const now = new Date();
  const next3 = upcomingEvents
    .filter(e => new Date(e.start) > now)
    .sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime())
    .slice(0, 3);

  const activeEvents = upcomingEvents.filter(
    e => new Date(e.start) <= now && new Date(e.end) >= now
  );

  const eventMenuItems: Electron.MenuItemConstructorOptions[] = [];

  if (activeEvents.length > 0) {
    eventMenuItems.push({ label: '● In Meeting', enabled: false });
    for (const e of activeEvents) {
      eventMenuItems.push({
        label: `  ${e.title} (ends ${formatTime(e.end)})`,
        enabled: false,
      });
    }
    eventMenuItems.push({ type: 'separator' });
  }

  if (next3.length > 0) {
    eventMenuItems.push({ label: 'Upcoming', enabled: false });
    for (const e of next3) {
      eventMenuItems.push({
        label: `  ${formatTime(e.start)}  ${e.title}`,
        enabled: false,
      });
    }
  } else if (activeEvents.length === 0) {
    eventMenuItems.push({ label: 'No upcoming meetings', enabled: false });
  }

  const menu = Menu.buildFromTemplate([
    ...eventMenuItems,
    { type: 'separator' },
    {
      label: 'Open Calendar Task Manager',
      click: () => onShowMain?.(),
    },
    {
      label: 'Quick Note',
      accelerator: 'CmdOrCtrl+Shift+Space',
      click: () => onQuickNote?.(),
    },
    { type: 'separator' },
    { label: 'Quit', click: () => app.quit() },
  ]);

  tray.setContextMenu(menu);

  // Update title with active meeting indicator
  if (process.platform === 'darwin') {
    tray.setTitle(activeEvents.length > 0 ? '●' : '');
  }
}

export function destroyTray(): void {
  tray?.destroy();
  tray = null;
}
