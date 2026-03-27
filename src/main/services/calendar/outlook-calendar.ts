import { NormalizedEvent } from '../../../shared/types/calendar';
import { getMicrosoftAuth } from '../auth/microsoft-auth';
import { normalizeMicrosoftEvent } from './event-normalizer';

const GRAPH_BASE = 'https://graph.microsoft.com/v1.0';

export async function getOutlookEvents(
  accountId: string,
  hoursAhead = 336,
  hoursBehind = 168
): Promise<NormalizedEvent[]> {
  const auth = getMicrosoftAuth();
  if (!auth) throw new Error('Microsoft auth not initialized');

  const token = await auth.getAccessToken(accountId);

  const now = new Date();
  const start = new Date(now.getTime() - hoursBehind * 60 * 60 * 1000);
  const end = new Date(now.getTime() + hoursAhead * 60 * 60 * 1000);

  const params = new URLSearchParams({
    startDateTime: start.toISOString(),
    endDateTime: end.toISOString(),
    $select: 'id,subject,start,end,attendees,isOnlineMeeting,organizer,location,bodyPreview',
    $orderby: 'start/dateTime',
    $top: '50',
  });

  const res = await fetch(`${GRAPH_BASE}/me/calendarView?${params}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      Prefer: `outlook.timezone="UTC"`,
    },
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Outlook calendar fetch failed: ${res.status} ${errorText}`);
  }

  const data = await res.json();
  const events: NormalizedEvent[] = [];

  for (const item of data.value ?? []) {
    const normalized = normalizeMicrosoftEvent(item, accountId);
    if (normalized) events.push(normalized);
  }

  return events;
}
