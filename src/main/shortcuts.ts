import { globalShortcut, app, systemPreferences } from 'electron';

let registeredShortcuts: string[] = [];

export function registerShortcuts(
  quickNoteShortcut: string,
  toggleAppShortcut: string,
  onQuickNote: () => void,
  onToggleMain: () => void
): void {
  // Unregister any previously registered shortcuts
  unregisterShortcuts();

  try {
    if (globalShortcut.register(quickNoteShortcut, onQuickNote)) {
      registeredShortcuts.push(quickNoteShortcut);
    } else {
      console.warn(`Failed to register shortcut: ${quickNoteShortcut}`);
    }
  } catch (e) {
    console.error(`Error registering shortcut ${quickNoteShortcut}:`, e);
  }

  try {
    if (globalShortcut.register(toggleAppShortcut, onToggleMain)) {
      registeredShortcuts.push(toggleAppShortcut);
    } else {
      console.warn(`Failed to register shortcut: ${toggleAppShortcut}`);
    }
  } catch (e) {
    console.error(`Error registering shortcut ${toggleAppShortcut}:`, e);
  }

  app.on('will-quit', unregisterShortcuts);
}

export function unregisterShortcuts(): void {
  for (const shortcut of registeredShortcuts) {
    try {
      globalShortcut.unregister(shortcut);
    } catch (_) {
      // ignore
    }
  }
  registeredShortcuts = [];
}

export function checkAccessibilityPermission(): boolean {
  if (process.platform !== 'darwin') return true;
  return systemPreferences.isTrustedAccessibilityClient(false);
}

export function requestAccessibilityPermission(): void {
  if (process.platform !== 'darwin') return;
  systemPreferences.isTrustedAccessibilityClient(true);
}
