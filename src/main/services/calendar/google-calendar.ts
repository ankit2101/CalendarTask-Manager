import { google } from 'googleapis';
import { NormalizedEvent } from '../../../shared/types/calendar';
import { getGoogleAuth } from '../auth/google-auth';
import { normalizeGoogleEvent } from './event-normalizer';

export async function getGoogleEvents(
  accountId: string,
  hoursAhead = 336,
  hoursBehind = 168
): Promise<NormalizedEvent[]> {
  const auth = getGoogleAuth();
  const client = await auth.getClient(accountId);

  const calendar = google.calendar({ version: 'v3', auth: client });

  const now = new Date();
  const start = new Date(now.getTime() - hoursBehind * 60 * 60 * 1000);
  const end = new Date(now.getTime() + hoursAhead * 60 * 60 * 1000);

  const res = await calendar.events.list({
    calendarId: 'primary',
    timeMin: start.toISOString(),
    timeMax: end.toISOString(),
    singleEvents: true,
    orderBy: 'startTime',
    maxResults: 50,
    fields: 'items(id,summary,start,end,attendees,conferenceData,hangoutLink,organizer,location,description)',
  });

  const events: NormalizedEvent[] = [];

  for (const item of res.data.items ?? []) {
    const normalized = normalizeGoogleEvent(item, accountId);
    if (normalized) events.push(normalized);
  }

  return events;
}
