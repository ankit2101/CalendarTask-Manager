import Store from 'electron-store';
import { writeFile } from 'fs/promises';
import * as path from 'path';
import { AppStoreSchema, DEFAULT_STORE } from './schema';
import { AppSettings } from '../../shared/types/settings';
import { MeetingRecord } from '../../shared/types/calendar';
import { MicrosoftAccountRecord, GoogleAccountRecord, ICSAccountRecord } from '../../shared/types/account';
import { TodoTask } from '../../shared/types/todo';


const store = new Store<AppStoreSchema>({
  defaults: DEFAULT_STORE,
  name: 'calendar-task-manager',
});

function triggerAutoExport(): void {
  const folderPath = store.get('settings').dataFolderPath;
  if (!folderPath) return;
  const backup = {
    version: 1,
    exportedAt: new Date().toISOString(),
    meetingHistory: store.get('meetingHistory', []),
    todoTasks: store.get('todoTasks', []),
  };
  const filePath = path.join(folderPath, 'caltask-backup.json');
  writeFile(filePath, JSON.stringify(backup, null, 2), 'utf-8').catch(err =>
    console.error('[auto-export] Failed to write backup:', err)
  );
}

export const appStore = {
  // Settings
  getSettings(): AppSettings {
    return store.get('settings');
  },
  saveSettings(settings: Partial<AppSettings>): void {
    const current = store.get('settings');
    store.set('settings', { ...current, ...settings });
    triggerAutoExport();
  },

  // Accounts
  getMicrosoftAccounts(): MicrosoftAccountRecord[] {
    return store.get('accounts.microsoft', []);
  },
  saveMicrosoftAccount(account: MicrosoftAccountRecord): void {
    const accounts = store.get('accounts.microsoft', []);
    const idx = accounts.findIndex(a => a.id === account.id);
    if (idx >= 0) accounts[idx] = account;
    else accounts.push(account);
    store.set('accounts.microsoft', accounts);
  },
  removeMicrosoftAccount(id: string): void {
    const accounts = store.get('accounts.microsoft', []).filter(a => a.id !== id);
    store.set('accounts.microsoft', accounts);
  },

  getGoogleAccounts(): GoogleAccountRecord[] {
    return store.get('accounts.google', []);
  },
  saveGoogleAccount(account: GoogleAccountRecord): void {
    const accounts = store.get('accounts.google', []);
    const idx = accounts.findIndex(a => a.id === account.id);
    if (idx >= 0) accounts[idx] = account;
    else accounts.push(account);
    store.set('accounts.google', accounts);
  },
  removeGoogleAccount(id: string): void {
    const accounts = store.get('accounts.google', []).filter(a => a.id !== id);
    store.set('accounts.google', accounts);
  },

  getICSAccounts(): ICSAccountRecord[] {
    return store.get('accounts.ics', []);
  },
  saveICSAccount(account: ICSAccountRecord): void {
    const accounts = store.get('accounts.ics', []);
    const idx = accounts.findIndex(a => a.id === account.id);
    if (idx >= 0) accounts[idx] = account;
    else accounts.push(account);
    store.set('accounts.ics', accounts);
  },
  removeICSAccount(id: string): void {
    const accounts = store.get('accounts.ics', []).filter(a => a.id !== id);
    store.set('accounts.ics', accounts);
  },

  // Bulk setters used by data import
  setMeetingHistory(records: MeetingRecord[]): void {
    store.set('meetingHistory', records);
    triggerAutoExport();
  },
  setTodoTasks(tasks: TodoTask[]): void {
    store.set('todoTasks', tasks);
    triggerAutoExport();
  },

  // Meeting history (rolling 90 days)
  getMeetingHistory(): MeetingRecord[] {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - 90);
    return store.get('meetingHistory', []).filter(
      m => new Date(m.createdAt) > cutoff
    );
  },
  addMeetingRecord(record: MeetingRecord): void {
    const history = this.getMeetingHistory();
    history.unshift(record);
    store.set('meetingHistory', history.slice(0, 500));
    triggerAutoExport();
  },

  // To-do tasks
  getTodoTasks(): TodoTask[] {
    return store.get('todoTasks', []);
  },
  addTodoTask(task: TodoTask): void {
    const tasks = store.get('todoTasks', []);
    tasks.unshift(task);
    store.set('todoTasks', tasks);
    triggerAutoExport();
  },
  updateTodoTask(id: string, updates: Partial<Omit<TodoTask, 'id' | 'createdAt'>>): TodoTask | null {
    const tasks = store.get('todoTasks', []);
    const idx = tasks.findIndex(t => t.id === id);
    if (idx < 0) return null;
    tasks[idx] = { ...tasks[idx], ...updates, updatedAt: new Date().toISOString() };
    store.set('todoTasks', tasks);
    triggerAutoExport();
    return tasks[idx];
  },
  deleteTodoTask(id: string): void {
    store.set('todoTasks', store.get('todoTasks', []).filter(t => t.id !== id));
    triggerAutoExport();
  },

  // Dismissed meetings
  getDismissedMeetingIds(): string[] {
    return store.get('dismissedMeetingIds', []);
  },
  addDismissedMeetingId(id: string): void {
    const ids = store.get('dismissedMeetingIds', []);
    if (!ids.includes(id)) {
      ids.push(id);
      // Keep only last 1000 dismissed IDs
      store.set('dismissedMeetingIds', ids.slice(-1000));
    }
  },
};
