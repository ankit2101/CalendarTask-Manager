import { NormalizedEvent } from '../../../shared/types/calendar';
import { appStore } from '../../store/app-store';
import { getOutlookEvents } from './outlook-calendar';
import { getGoogleEvents } from './google-calendar';
import { getICSEvents } from './ics-calendar';

export class CalendarManager {
  private cachedEvents: NormalizedEvent[] = [];
  private lastFetchTime: Date | null = null;

  async fetchAllEvents(hoursBehind = 168, hoursAhead = 336): Promise<NormalizedEvent[]> {
    const msAccounts = appStore.getMicrosoftAccounts();
    const googleAccounts = appStore.getGoogleAccounts();

    const allEvents: NormalizedEvent[] = [];
    const errors: string[] = [];

    // Fetch Microsoft accounts in parallel
    const msPromises = msAccounts.map(async account => {
      try {
        const events = await getOutlookEvents(account.id, hoursAhead, hoursBehind);
        allEvents.push(...events);
      } catch (e) {
        errors.push(`Outlook (${account.email}): ${(e as Error).message}`);
        console.error(`Failed to fetch Outlook events for ${account.email}:`, e);
      }
    });

    // Fetch Google accounts in parallel
    const googlePromises = googleAccounts.map(async account => {
      try {
        const events = await getGoogleEvents(account.id, hoursAhead, hoursBehind);
        allEvents.push(...events);
      } catch (e) {
        errors.push(`Google (${account.email}): ${(e as Error).message}`);
        console.error(`Failed to fetch Google events for ${account.email}:`, e);
      }
    });

    // Fetch ICS accounts in parallel
    const icsAccounts = appStore.getICSAccounts();
    const icsPromises = icsAccounts.map(async account => {
      try {
        const events = await getICSEvents(account.url, account.id, hoursAhead, hoursBehind);
        allEvents.push(...events);
      } catch (e) {
        errors.push(`ICS (${account.displayName}): ${(e as Error).message}`);
        console.error(`Failed to fetch ICS events for ${account.displayName}:`, e);
      }
    });

    await Promise.all([...msPromises, ...googlePromises, ...icsPromises]);

    // Sort by start time
    allEvents.sort((a, b) => new Date(a.start).getTime() - new Date(b.start).getTime());

    this.cachedEvents = allEvents;
    this.lastFetchTime = new Date();

    if (errors.length > 0) {
      console.warn('Some calendar fetches failed:', errors);
    }

    return allEvents;
  }

  getCachedEvents(): NormalizedEvent[] {
    return this.cachedEvents;
  }

  getLastFetchTime(): Date | null {
    return this.lastFetchTime;
  }
}

let instance: CalendarManager | null = null;

export function getCalendarManager(): CalendarManager {
  if (!instance) instance = new CalendarManager();
  return instance;
}
