export interface AppSettings {
  pollingIntervalSeconds: number;
  promptDelayMinutes: number;
  globalShortcutQuickNote: string;
  globalShortcutToggleApp: string;
  defaultPlannerAccountId: string | null;
  defaultPlanId: string | null;
  defaultBucketId: string | null;
  minimumAttendeesForPrompt: number;
  showDockIcon: boolean;
  launchAtLogin: boolean;
  dataFolderPath: string;
}

export const DEFAULT_SETTINGS: AppSettings = {
  pollingIntervalSeconds: 30,
  promptDelayMinutes: 2,
  globalShortcutQuickNote: 'CommandOrControl+Shift+Space',
  globalShortcutToggleApp: 'CommandOrControl+Shift+M',
  defaultPlannerAccountId: null,
  defaultPlanId: null,
  defaultBucketId: null,
  minimumAttendeesForPrompt: 2,
  showDockIcon: false,
  launchAtLogin: true,
  dataFolderPath: '',
};
