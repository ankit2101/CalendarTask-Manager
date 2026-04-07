export type CalendarProvider = 'microsoft' | 'google' | 'ics';

export interface NormalizedEvent {
  id: string;
  accountId: string;
  provider: CalendarProvider;
  title: string;
  start: string; // ISO string
  end: string;   // ISO string
  timeZone?: string;
  attendees: string[];
  isOnlineMeeting: boolean;
  organizer: string;
  location?: string;
  bodyPreview?: string;
  userResponseStatus?: 'accepted' | 'declined' | 'tentative' | 'none';
}

export interface ActionItem {
  id: string;
  title: string;
  description?: string;
  dueDate?: string; // YYYY-MM-DD or undefined
  assignee?: string;
  priority: 'urgent' | 'important' | 'normal';
}

export interface MeetingRecord {
  eventId: string;
  accountId: string;
  provider: CalendarProvider;
  title: string;
  start: string;
  end: string;
  note: string;
  actionItems: ActionItem[];
  plannerTaskIds: string[];
  createdAt: string;
}
