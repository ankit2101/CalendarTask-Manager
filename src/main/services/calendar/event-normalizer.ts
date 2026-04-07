import { NormalizedEvent } from '../../../shared/types/calendar';

// Microsoft Graph event shape (partial)
interface GraphEvent {
  id: string;
  subject?: string;
  start?: { dateTime: string; timeZone: string };
  end?: { dateTime: string; timeZone: string };
  attendees?: Array<{
    emailAddress?: { address?: string; name?: string };
    status?: { response?: string };
    type?: string;
  }>;
  isOnlineMeeting?: boolean;
  organizer?: { emailAddress?: { address?: string; name?: string } };
  location?: { displayName?: string };
  bodyPreview?: string;
}

// Google Calendar event shape (partial)
interface GoogleEvent {
  id?: string | null;
  summary?: string | null;
  start?: { dateTime?: string | null; date?: string | null; timeZone?: string | null };
  end?: { dateTime?: string | null; date?: string | null; timeZone?: string | null };
  attendees?: Array<{
    email?: string | null;
    displayName?: string | null;
    responseStatus?: string | null;
    self?: boolean | null;
  }>;
  conferenceData?: unknown;
  organizer?: { email?: string | null; displayName?: string | null };
  location?: string | null;
  description?: string | null;
  hangoutLink?: string | null;
}

export function normalizeMicrosoftEvent(event: GraphEvent, accountId: string): NormalizedEvent | null {
  if (!event.id || !event.start?.dateTime || !event.end?.dateTime) return null;

  const attendees = (event.attendees ?? [])
    .filter(a => a.type !== 'resource')
    .map(a => a.emailAddress?.address ?? '')
    .filter(Boolean);

  const selfAttendee = event.attendees?.find(a =>
    a.emailAddress?.address?.toLowerCase() === accountId.split(':')[0]?.toLowerCase()
  );
  const responseStatus = selfAttendee?.status?.response?.toLowerCase();

  let userResponseStatus: NormalizedEvent['userResponseStatus'] = 'none';
  if (responseStatus === 'accepted') userResponseStatus = 'accepted';
  else if (responseStatus === 'declined') userResponseStatus = 'declined';
  else if (responseStatus === 'tentativelyaccepted') userResponseStatus = 'tentative';

  return {
    id: `ms:${event.id}`,
    accountId,
    provider: 'microsoft',
    title: event.subject ?? '(No Title)',
    start: new Date(event.start.dateTime).toISOString(),
    end: new Date(event.end.dateTime).toISOString(),
    timeZone: event.start.timeZone,
    attendees,
    isOnlineMeeting: event.isOnlineMeeting ?? false,
    organizer: event.organizer?.emailAddress?.address ?? '',
    location: event.location?.displayName,
    bodyPreview: event.bodyPreview,
    userResponseStatus,
  };
}

export function normalizeGoogleEvent(event: GoogleEvent, accountId: string): NormalizedEvent | null {
  if (!event.id) return null;

  const startStr = event.start?.dateTime ?? event.start?.date;
  const endStr = event.end?.dateTime ?? event.end?.date;
  if (!startStr || !endStr) return null;

  const attendees = (event.attendees ?? [])
    .map(a => a.email ?? '')
    .filter(Boolean);

  const selfAttendee = event.attendees?.find(a => a.self);
  let userResponseStatus: NormalizedEvent['userResponseStatus'] = 'none';
  if (selfAttendee?.responseStatus === 'accepted') userResponseStatus = 'accepted';
  else if (selfAttendee?.responseStatus === 'declined') userResponseStatus = 'declined';
  else if (selfAttendee?.responseStatus === 'tentative') userResponseStatus = 'tentative';

  const isOnlineMeeting = !!(event.conferenceData || event.hangoutLink);

  return {
    id: `google:${event.id}`,
    accountId,
    provider: 'google',
    title: event.summary ?? '(No Title)',
    start: new Date(startStr).toISOString(),
    end: new Date(endStr).toISOString(),
    timeZone: event.start?.timeZone ?? undefined,
    attendees,
    isOnlineMeeting,
    organizer: event.organizer?.email ?? '',
    location: event.location ?? undefined,
    bodyPreview: event.description ?? undefined,
    userResponseStatus,
  };
}

export function shouldPromptForEvent(event: NormalizedEvent, minAttendees: number): boolean {
  const start = new Date(event.start);
  const end = new Date(event.end);
  const durationMs = end.getTime() - start.getTime();
  const fiveMinutes = 5 * 60 * 1000;
  const fourHours = 4 * 60 * 60 * 1000;

  // Skip solo blocks, all-day events, too-long events
  if (durationMs < fiveMinutes || durationMs > fourHours) return false;

  // Skip declined events
  if (event.userResponseStatus === 'declined') return false;

  // Must have minimum attendees
  if (event.attendees.length < minAttendees) return false;

  return true;
}
