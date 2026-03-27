import * as https from 'https';
import * as http from 'http';
import * as ical from 'node-ical';
import { NormalizedEvent } from '../../../shared/types/calendar';

const USER_AGENT = 'CalendarTaskManager/1.0 (Electron; Node.js)';
const MAX_REDIRECTS = 5;
const TIMEOUT_MS = 15000;

function fetchICSString(url: string, redirectsLeft = MAX_REDIRECTS): Promise<string> {
  return new Promise((resolve, reject) => {
    if (redirectsLeft === 0) {
      reject(new Error('Too many redirects fetching ICS feed'));
      return;
    }

    let parsedUrl: URL;
    try {
      parsedUrl = new URL(url);
    } catch {
      reject(new Error(`Invalid URL: ${url}`));
      return;
    }

    const client = parsedUrl.protocol === 'https:' ? https : http;
    const req = client.get(url, { headers: { 'User-Agent': USER_AGENT } }, (res) => {
      // Follow redirects
      if (
        res.statusCode &&
        res.statusCode >= 300 &&
        res.statusCode < 400 &&
        res.headers.location
      ) {
        // Resolve relative redirect URLs
        const nextUrl = new URL(res.headers.location, url).toString();
        fetchICSString(nextUrl, redirectsLeft - 1).then(resolve).catch(reject);
        return;
      }

      if (res.statusCode === 401 || res.statusCode === 403) {
        reject(new Error(
          `Access denied (HTTP ${res.statusCode}). Make sure the calendar is published publicly in Outlook Web: ` +
          'Settings → Calendar → Shared calendars → Publish a calendar.'
        ));
        return;
      }

      if (res.statusCode !== 200) {
        reject(new Error(`HTTP ${res.statusCode} fetching ICS feed — check the URL is correct.`));
        return;
      }

      let data = '';
      res.on('data', (chunk: string) => { data += chunk; });
      res.on('end', () => {
        if (!data.includes('BEGIN:VCALENDAR')) {
          reject(new Error('URL did not return a valid ICS calendar file. Make sure you copied the ICS link, not the HTML calendar link.'));
          return;
        }
        resolve(data);
      });
      res.on('error', (err: Error) => reject(new Error(`Network error: ${err.message}`)));
    });

    req.setTimeout(TIMEOUT_MS, () => {
      req.destroy();
      reject(new Error(`Request timed out after ${TIMEOUT_MS / 1000}s — check your network connection.`));
    });

    req.on('error', (err: Error) => reject(new Error(`Connection failed: ${err.message}`)));
  });
}

// node-ical attendee value can be a string like "mailto:email@example.com"
// or an object with a val property
function extractEmail(raw: unknown): string {
  if (!raw) return '';
  if (typeof raw === 'string') return raw.replace(/^mailto:/i, '');
  if (typeof raw === 'object') {
    const obj = raw as Record<string, unknown>;
    if (typeof obj.val === 'string') return obj.val.replace(/^mailto:/i, '');
  }
  return '';
}

function extractAttendees(attendee: unknown): string[] {
  if (!attendee) return [];
  if (Array.isArray(attendee)) {
    return attendee.map(extractEmail).filter(Boolean);
  }
  const email = extractEmail(attendee);
  return email ? [email] : [];
}

export async function getICSEvents(
  url: string,
  accountId: string,
  hoursAhead = 336,
  hoursBehind = 168
): Promise<NormalizedEvent[]> {
  const icsString = await fetchICSString(url);
  const data = ical.sync.parseICS(icsString);

  const now = new Date();
  const windowStart = new Date(now.getTime() - hoursBehind * 60 * 60 * 1000);
  const cutoff = new Date(now.getTime() + hoursAhead * 60 * 60 * 1000);

  const events: NormalizedEvent[] = [];

  for (const key of Object.keys(data)) {
    const entry = data[key];

    if (entry.type !== 'VEVENT') continue;

    const start = entry.start as Date | undefined;
    const end = entry.end as Date | undefined;

    if (!start || !end) continue;
    if (!(start instanceof Date) || isNaN(start.getTime())) continue;
    if (!(end instanceof Date) || isNaN(end.getTime())) continue;

    // Only include events in the fetch window
    if (end < windowStart || start > cutoff) continue;

    const uid = (entry.uid as string) ?? key;
    const summary = (entry.summary as string) ?? '(No Title)';
    const location = (entry.location as string) ?? undefined;
    const description = (entry.description as string) ?? undefined;

    const organizer = extractEmail((entry as Record<string, unknown>).organizer);
    const attendees = extractAttendees((entry as Record<string, unknown>).attendee);

    // Detect online meeting from location or description
    const onlineKeywords = ['zoom.us', 'teams.microsoft', 'meet.google', 'webex', 'gotomeeting'];
    const textToCheck = `${location ?? ''} ${description ?? ''}`.toLowerCase();
    const isOnlineMeeting = onlineKeywords.some(kw => textToCheck.includes(kw));

    events.push({
      id: `ics:${uid}`,
      accountId,
      provider: 'ics',
      title: summary,
      start: start.toISOString(),
      end: end.toISOString(),
      attendees,
      isOnlineMeeting,
      organizer,
      location,
      bodyPreview: description,
      userResponseStatus: 'none',
    });
  }

  return events;
}
