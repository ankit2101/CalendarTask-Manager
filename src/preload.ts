import { contextBridge, ipcRenderer } from 'electron';
import { IpcChannel } from './shared/types/ipc-channels';
import { NormalizedEvent, ActionItem, MeetingRecord } from './shared/types/calendar';
import { TodoTask } from './shared/types/todo';

// Type-safe API exposed to renderer
export interface ElectronAPI {
  // Calendar
  getEvents: () => Promise<NormalizedEvent[]>;
  refreshEvents: () => Promise<NormalizedEvent[]>;

  // Accounts
  getAccounts: () => Promise<{ ics: unknown[] }>;
  addICSAccount: (url: string, displayName: string) => Promise<unknown>;
  removeAccount: (provider: 'ics', id: string) => Promise<void>;

  // Notes + AI
  extractActionItems: (note: string, event: NormalizedEvent) => Promise<ActionItem[]>;
  submitNote: (args: {
    event: NormalizedEvent;
    note: string;
    actionItems: ActionItem[];
    planId: string;
    bucketId: string;
    accountId: string;
  }) => Promise<{ success: boolean; taskIds: string[] }>;
  getMeetingHistory: () => Promise<MeetingRecord[]>;
  dismissMeeting: (eventId: string) => Promise<void>;
  openQuickNote: (event?: NormalizedEvent) => Promise<void>;

  // Planner
  getPlans: (accountId: string) => Promise<unknown[]>;
  getBuckets: (planId: string, accountId: string) => Promise<unknown[]>;

  // To-do tasks
  getTodos: () => Promise<TodoTask[]>;
  addTodo: (task: TodoTask) => Promise<TodoTask>;
  updateTodo: (id: string, updates: Partial<Omit<TodoTask, 'id' | 'createdAt'>>) => Promise<TodoTask | null>;
  deleteTodo: (id: string) => Promise<void>;

  // Settings
  getSettings: () => Promise<unknown>;
  saveSettings: (settings: Record<string, unknown>) => Promise<void>;

  // Data backup
  selectFolder: () => Promise<string | null>;
  exportData: () => Promise<string>;
  importData: () => Promise<{ meetingHistoryCount: number; todoTaskCount: number; exportedAt: string }>;

  // System
  checkAccessibility: () => Promise<boolean>;
  requestAccessibility: () => Promise<void>;
  setLaunchAtLogin: (enable: boolean) => Promise<void>;

  // Event listeners
  onMeetingEnded: (callback: (event: NormalizedEvent) => void) => () => void;
  onMeetingUpcoming: (callback: (event: NormalizedEvent) => void) => () => void;
  onCalendarSynced: (callback: (events: NormalizedEvent[]) => void) => () => void;
}

const api: ElectronAPI = {
  getEvents: () => ipcRenderer.invoke(IpcChannel.GET_EVENTS),
  refreshEvents: () => ipcRenderer.invoke(IpcChannel.REFRESH_EVENTS),

  getAccounts: () => ipcRenderer.invoke(IpcChannel.GET_ACCOUNTS),
  addICSAccount: (url, displayName) => ipcRenderer.invoke(IpcChannel.ADD_ICS_ACCOUNT, { url, displayName }),
  removeAccount: (provider, id) => ipcRenderer.invoke(IpcChannel.REMOVE_ACCOUNT, { provider, id }),

  extractActionItems: (note, event) => ipcRenderer.invoke(IpcChannel.EXTRACT_ACTION_ITEMS, { note, event }),
  submitNote: (args) => ipcRenderer.invoke(IpcChannel.SUBMIT_NOTE, args),
  getMeetingHistory: () => ipcRenderer.invoke(IpcChannel.GET_MEETING_HISTORY),
  dismissMeeting: (eventId) => ipcRenderer.invoke(IpcChannel.DISMISS_MEETING, eventId),
  openQuickNote: (event?) => ipcRenderer.invoke(IpcChannel.OPEN_QUICK_NOTE, event),

  getPlans: (accountId) => ipcRenderer.invoke(IpcChannel.GET_PLANS, { accountId }),
  getBuckets: (planId, accountId) => ipcRenderer.invoke(IpcChannel.GET_BUCKETS, { planId, accountId }),

  getTodos: () => ipcRenderer.invoke(IpcChannel.GET_TODOS),
  addTodo: (task) => ipcRenderer.invoke(IpcChannel.ADD_TODO, task),
  updateTodo: (id, updates) => ipcRenderer.invoke(IpcChannel.UPDATE_TODO, { id, updates }),
  deleteTodo: (id) => ipcRenderer.invoke(IpcChannel.DELETE_TODO, id),

  getSettings: () => ipcRenderer.invoke(IpcChannel.GET_SETTINGS),
  saveSettings: (settings) => ipcRenderer.invoke(IpcChannel.SAVE_SETTINGS, settings),

  selectFolder: () => ipcRenderer.invoke(IpcChannel.SELECT_FOLDER),
  exportData: () => ipcRenderer.invoke(IpcChannel.EXPORT_DATA),
  importData: () => ipcRenderer.invoke(IpcChannel.IMPORT_DATA),

  checkAccessibility: () => ipcRenderer.invoke(IpcChannel.CHECK_ACCESSIBILITY),
  requestAccessibility: () => ipcRenderer.invoke(IpcChannel.REQUEST_ACCESSIBILITY),
  setLaunchAtLogin: (enable) => ipcRenderer.invoke(IpcChannel.SET_LAUNCH_AT_LOGIN, enable),

  onMeetingEnded: (callback) => {
    const handler = (_: unknown, event: NormalizedEvent) => callback(event);
    ipcRenderer.on(IpcChannel.MEETING_ENDED, handler);
    return () => ipcRenderer.removeListener(IpcChannel.MEETING_ENDED, handler);
  },

  onMeetingUpcoming: (callback) => {
    const handler = (_: unknown, event: NormalizedEvent) => callback(event);
    ipcRenderer.on(IpcChannel.MEETING_UPCOMING, handler);
    return () => ipcRenderer.removeListener(IpcChannel.MEETING_UPCOMING, handler);
  },

  onCalendarSynced: (callback) => {
    const handler = (_: unknown, events: NormalizedEvent[]) => callback(events);
    ipcRenderer.on(IpcChannel.CALENDAR_SYNCED, handler);
    return () => ipcRenderer.removeListener(IpcChannel.CALENDAR_SYNCED, handler);
  },
};

contextBridge.exposeInMainWorld('api', api);
