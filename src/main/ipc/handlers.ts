import { ipcMain, BrowserWindow } from 'electron';
import { IpcChannel } from '../../shared/types/ipc-channels';
import { appStore } from '../store/app-store';
import { getICSEvents } from '../services/calendar/ics-calendar';
import { getMicrosoftAuth, initMicrosoftAuth } from '../services/auth/microsoft-auth';
import { getGoogleAuth } from '../services/auth/google-auth';
import { getCalendarManager } from '../services/calendar/calendar-manager';
import { getMeetingDetector } from '../services/meeting/meeting-detector';
import { extractActionItems, resetClaudeClient } from '../services/ai/claude-client';
import { getPlansForAccount, getBuckets, createPlannerTask } from '../services/planner/planner-client';
import { tokenStore } from '../services/auth/token-store';
import { checkAccessibilityPermission, requestAccessibilityPermission } from '../shortcuts';
import { ActionItem, MeetingRecord, NormalizedEvent } from '../../shared/types/calendar';
import { TodoTask } from '../../shared/types/todo';
import { closeQuickNoteWindow, openQuickNoteWindow } from '../windows/quick-note-window';
import { showMainWindow } from '../windows/main-window';

export function registerIpcHandlers(): void {
  // --- Calendar ---
  ipcMain.handle(IpcChannel.GET_EVENTS, async () => {
    const cached = getCalendarManager().getCachedEvents();
    if (cached.length > 0) return cached;
    return getCalendarManager().fetchAllEvents();
  });

  ipcMain.handle(IpcChannel.REFRESH_EVENTS, async () => {
    return getCalendarManager().fetchAllEvents();
  });

  // --- Accounts ---
  ipcMain.handle(IpcChannel.GET_ACCOUNTS, () => {
    return {
      microsoft: appStore.getMicrosoftAccounts(),
      google: appStore.getGoogleAccounts(),
      ics: appStore.getICSAccounts(),
    };
  });

  ipcMain.handle(IpcChannel.ADD_MICROSOFT_ACCOUNT, async () => {
    const auth = getMicrosoftAuth();
    if (!auth) throw new Error('Microsoft auth not configured. Set clientId in Settings first.');
    const account = await auth.addAccount();
    appStore.saveMicrosoftAccount(account);
    return account;
  });

  ipcMain.handle(IpcChannel.ADD_GOOGLE_ACCOUNT, async () => {
    const googleAuth = getGoogleAuth();
    const account = await googleAuth.addAccount();
    appStore.saveGoogleAccount(account);
    return account;
  });

  ipcMain.handle(IpcChannel.ADD_ICS_ACCOUNT, async (_, { url, displayName }: { url: string; displayName: string }) => {
    try {
      // Validate by doing a test fetch (7-day window)
      await getICSEvents(url, 'test', 24 * 7);
    } catch (e) {
      // Re-throw with the real message so the renderer can display it
      throw new Error((e as Error).message ?? 'Could not fetch the ICS feed. Check the URL and try again.');
    }
    const { createHash } = await import('crypto');
    const id = createHash('sha256').update(url).digest('hex').slice(0, 24);
    const account = { id, url, displayName };
    appStore.saveICSAccount(account);
    return account;
  });

  ipcMain.handle(IpcChannel.REMOVE_ACCOUNT, async (_, { provider, id }: { provider: 'microsoft' | 'google' | 'ics'; id: string }) => {
    if (provider === 'microsoft') {
      const auth = getMicrosoftAuth();
      if (auth) await auth.removeAccount(id);
      appStore.removeMicrosoftAccount(id);
    } else if (provider === 'google') {
      const googleAuth = getGoogleAuth();
      await googleAuth.removeAccount(id);
      appStore.removeGoogleAccount(id);
    } else {
      appStore.removeICSAccount(id);
    }
    return true;
  });

  // --- Note submission + AI extraction ---
  ipcMain.handle(IpcChannel.EXTRACT_ACTION_ITEMS, async (_, { note, event }) => {
    return extractActionItems(note, event);
  });

  ipcMain.handle(IpcChannel.SUBMIT_NOTE, async (_, {
    event,
    note,
    actionItems,
    planId,
    bucketId,
    accountId,
  }: {
    event: { id: string; accountId: string; provider: string; title: string; start: string; end: string };
    note: string;
    actionItems: ActionItem[];
    planId: string;
    bucketId: string;
    accountId: string;
  }) => {
    const taskIds: string[] = [];

    for (const item of actionItems) {
      try {
        const task = await createPlannerTask(item, planId, bucketId, accountId, event.title);
        taskIds.push(task.id);
      } catch (e) {
        console.error('Failed to create Planner task:', e);
      }
    }

    const record: MeetingRecord = {
      eventId: event.id,
      accountId: event.accountId,
      provider: event.provider as 'microsoft' | 'google',
      title: event.title,
      start: event.start,
      end: event.end,
      note,
      actionItems,
      plannerTaskIds: taskIds,
      createdAt: new Date().toISOString(),
    };
    appStore.addMeetingRecord(record);

    // Add extracted action items as To-Do tasks
    const priorityMap: Record<ActionItem['priority'], number> = {
      urgent: 5,
      important: 4,
      normal: 3,
    };
    const meetingDate = new Date(event.start).toLocaleDateString('en-US', {
      weekday: 'short', month: 'short', day: 'numeric',
    });
    for (const item of actionItems) {
      const todoTask: TodoTask = {
        id: `todo-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
        title: item.title,
        description: item.description || undefined,
        status: 'pending',
        priority: priorityMap[item.priority] ?? 3,
        source: { meetingTitle: event.title, meetingDate },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      appStore.addTodoTask(todoTask);
    }

    getMeetingDetector().markPrompted(event.id);
    closeQuickNoteWindow();

    return { success: true, taskIds };
  });

  // --- Planner ---
  ipcMain.handle(IpcChannel.GET_PLANS, async (_, { accountId }: { accountId: string }) => {
    return getPlansForAccount(accountId);
  });

  ipcMain.handle(IpcChannel.GET_BUCKETS, async (_, { planId, accountId }: { planId: string; accountId: string }) => {
    return getBuckets(planId, accountId);
  });

  // --- Settings ---
  ipcMain.handle(IpcChannel.GET_SETTINGS, () => {
    return appStore.getSettings();
  });

  ipcMain.handle(IpcChannel.SAVE_SETTINGS, async (_, settings) => {
    // If API key is being saved, store in Keychain
    if (settings.claudeApiKey !== undefined) {
      await tokenStore.saveSecret('claude-api-key', settings.claudeApiKey);
      resetClaudeClient();
      delete settings.claudeApiKey;
    }
    if (settings.msClientId !== undefined) {
      await tokenStore.saveSecret('ms-client-id', settings.msClientId);
      initMicrosoftAuth(settings.msClientId);
      delete settings.msClientId;
    }
    if (settings.googleClientId !== undefined) {
      await tokenStore.saveSecret('google-client-id', settings.googleClientId);
      delete settings.googleClientId;
    }
    if (settings.googleClientSecret !== undefined) {
      await tokenStore.saveSecret('google-client-secret', settings.googleClientSecret);
      getGoogleAuth().setCredentials({
        clientId: settings.googleClientId ?? (await tokenStore.loadSecret('google-client-id') ?? ''),
        clientSecret: settings.googleClientSecret,
      });
      delete settings.googleClientSecret;
    }

    appStore.saveSettings(settings);
    return true;
  });

  // --- Data backup ---
  ipcMain.handle(IpcChannel.SELECT_FOLDER, async () => {
    const { dialog } = await import('electron');
    const result = await dialog.showOpenDialog({
      properties: ['openDirectory', 'createDirectory'],
      title: 'Choose Data Storage Folder',
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    return result.filePaths[0];
  });

  ipcMain.handle(IpcChannel.EXPORT_DATA, async () => {
    const { writeFile } = await import('fs/promises');
    const path = await import('path');
    const settings = appStore.getSettings();
    if (!settings.dataFolderPath) throw new Error('No data folder configured. Set one in Settings first.');

    const backup = {
      version: 1,
      exportedAt: new Date().toISOString(),
      meetingHistory: appStore.getMeetingHistory(),
      todoTasks: appStore.getTodoTasks(),
    };

    const filePath = path.join(settings.dataFolderPath, 'caltask-backup.json');
    await writeFile(filePath, JSON.stringify(backup, null, 2), 'utf-8');
    return filePath;
  });

  ipcMain.handle(IpcChannel.IMPORT_DATA, async () => {
    const { readFile } = await import('fs/promises');
    const path = await import('path');
    const settings = appStore.getSettings();
    if (!settings.dataFolderPath) throw new Error('No data folder configured. Set one in Settings first.');

    const filePath = path.join(settings.dataFolderPath, 'caltask-backup.json');
    const raw = await readFile(filePath, 'utf-8');
    const backup = JSON.parse(raw);

    if (!backup.version || !Array.isArray(backup.meetingHistory) || !Array.isArray(backup.todoTasks)) {
      throw new Error('Invalid backup file format.');
    }

    appStore.setMeetingHistory(backup.meetingHistory);
    appStore.setTodoTasks(backup.todoTasks);

    return {
      meetingHistoryCount: backup.meetingHistory.length,
      todoTaskCount: backup.todoTasks.length,
      exportedAt: backup.exportedAt,
    };
  });

  // --- System ---
  ipcMain.handle(IpcChannel.CHECK_ACCESSIBILITY, () => {
    return checkAccessibilityPermission();
  });

  ipcMain.handle(IpcChannel.REQUEST_ACCESSIBILITY, () => {
    requestAccessibilityPermission();
  });

  ipcMain.handle(IpcChannel.SET_LAUNCH_AT_LOGIN, (_, enable: boolean) => {
    const { app } = require('electron');
    app.setLoginItemSettings({ openAtLogin: enable });
    appStore.saveSettings({ launchAtLogin: enable });
  });

  ipcMain.handle(IpcChannel.OPEN_MAIN_WINDOW, () => {
    showMainWindow();
  });

  ipcMain.handle(IpcChannel.GET_MEETING_HISTORY, () => {
    return appStore.getMeetingHistory();
  });

  // --- To-do tasks ---
  ipcMain.handle(IpcChannel.GET_TODOS, () => {
    return appStore.getTodoTasks();
  });

  ipcMain.handle(IpcChannel.ADD_TODO, (_, task) => {
    appStore.addTodoTask(task);
    return task;
  });

  ipcMain.handle(IpcChannel.UPDATE_TODO, (_, { id, updates }) => {
    return appStore.updateTodoTask(id, updates);
  });

  ipcMain.handle(IpcChannel.DELETE_TODO, (_, id: string) => {
    appStore.deleteTodoTask(id);
    return true;
  });

  ipcMain.handle(IpcChannel.OPEN_QUICK_NOTE, (_, event?: NormalizedEvent) => {
    openQuickNoteWindow(event);
  });

  ipcMain.handle(IpcChannel.DISMISS_MEETING, (_, eventId: string) => {
    getMeetingDetector().dismissMeeting(eventId);
  });
}

// Forward meeting-ended events to all renderer windows
export function setupMeetingEventForwarding(): void {
  const detector = getMeetingDetector();
  detector.on('meeting-ended', (event) => {
    openQuickNoteWindow(event);

    // Also notify the main window if open
    const wins = BrowserWindow.getAllWindows();
    for (const win of wins) {
      if (!win.isDestroyed()) {
        win.webContents.send(IpcChannel.MEETING_ENDED, event);
      }
    }
  });
}
