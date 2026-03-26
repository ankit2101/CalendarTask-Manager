import { MeetingRecord } from '../../shared/types/calendar';
import { MicrosoftAccountRecord, GoogleAccountRecord, ICSAccountRecord } from '../../shared/types/account';
import { AppSettings, DEFAULT_SETTINGS } from '../../shared/types/settings';
import { TodoTask } from '../../shared/types/todo';

export interface AppStoreSchema {
  accounts: {
    microsoft: MicrosoftAccountRecord[];
    google: GoogleAccountRecord[];
    ics: ICSAccountRecord[];
  };
  settings: AppSettings;
  meetingHistory: MeetingRecord[];
  dismissedMeetingIds: string[];
  todoTasks: TodoTask[];
}

export const DEFAULT_STORE: AppStoreSchema = {
  accounts: {
    microsoft: [],
    google: [],
    ics: [],
  },
  settings: DEFAULT_SETTINGS,
  meetingHistory: [],
  dismissedMeetingIds: [],
  todoTasks: [],
};
