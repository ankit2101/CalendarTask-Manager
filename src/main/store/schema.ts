import { MeetingRecord } from '../../shared/types/calendar';
import { ICSAccountRecord } from '../../shared/types/account';
import { AppSettings, DEFAULT_SETTINGS } from '../../shared/types/settings';
import { TodoTask } from '../../shared/types/todo';

export interface AppStoreSchema {
  accounts: {
    ics: ICSAccountRecord[];
  };
  settings: AppSettings;
  meetingHistory: MeetingRecord[];
  dismissedMeetingIds: string[];
  todoTasks: TodoTask[];
}

export const DEFAULT_STORE: AppStoreSchema = {
  accounts: {
    ics: [],
  },
  settings: DEFAULT_SETTINGS,
  meetingHistory: [],
  dismissedMeetingIds: [],
  todoTasks: [],
};
