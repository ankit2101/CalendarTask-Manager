import { EventEmitter } from 'events';
import { NormalizedEvent } from '../../../shared/types/calendar';
import { shouldPromptForEvent } from '../calendar/event-normalizer';
import { appStore } from '../../store/app-store';
import { getCalendarManager } from '../calendar/calendar-manager';
import { updateTray } from '../../tray';

export type MeetingState = 'upcoming' | 'active' | 'ended' | 'prompted' | 'dismissed';

export const MEETING_ENDED_EVENT = 'meeting-ended';

export class MeetingDetector extends EventEmitter {
  private states: Map<string, MeetingState> = new Map();
  private promptTimers: Map<string, NodeJS.Timeout> = new Map();
  private pollTimer: NodeJS.Timeout | null = null;
  private isRunning = false;

  start(intervalMs?: number): void {
    if (this.isRunning) return;
    this.isRunning = true;

    const settings = appStore.getSettings();
    const interval = intervalMs ?? settings.pollingIntervalSeconds * 1000;

    this.poll();
    this.pollTimer = setInterval(() => this.poll(), interval);
  }

  stop(): void {
    this.isRunning = false;
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
    for (const timer of this.promptTimers.values()) {
      clearTimeout(timer);
    }
    this.promptTimers.clear();
  }

  dismissMeeting(eventId: string): void {
    this.states.set(eventId, 'dismissed');
    appStore.addDismissedMeetingId(eventId);
    const timer = this.promptTimers.get(eventId);
    if (timer) {
      clearTimeout(timer);
      this.promptTimers.delete(eventId);
    }
  }

  markPrompted(eventId: string): void {
    this.states.set(eventId, 'prompted');
  }

  private async poll(): Promise<void> {
    try {
      const events = await getCalendarManager().fetchAllEvents(24);
      updateTray(events);
      this.processEvents(events);
    } catch (e) {
      console.error('MeetingDetector poll error:', e);
    }
  }

  private processEvents(events: NormalizedEvent[]): void {
    const now = new Date();
    const settings = appStore.getSettings();
    const dismissed = new Set(appStore.getDismissedMeetingIds());

    for (const event of events) {
      if (dismissed.has(event.id)) {
        this.states.set(event.id, 'dismissed');
        continue;
      }

      const current = this.states.get(event.id) ?? 'upcoming';

      // Don't process already-handled events
      if (current === 'prompted' || current === 'dismissed') continue;

      const next = this.transition(event, current, now);

      if (next !== current) {
        this.states.set(event.id, next);

        if (next === 'ended') {
          if (!shouldPromptForEvent(event, settings.minimumAttendeesForPrompt)) {
            this.states.set(event.id, 'dismissed');
            continue;
          }

          const delayMs = settings.promptDelayMinutes * 60 * 1000;
          const timer = setTimeout(() => {
            // Re-check state hasn't changed (e.g., user manually dismissed)
            if (this.states.get(event.id) === 'ended') {
              this.states.set(event.id, 'prompted');
              this.emit(MEETING_ENDED_EVENT, event);
            }
            this.promptTimers.delete(event.id);
          }, delayMs);

          this.promptTimers.set(event.id, timer);
        }
      }
    }

    // Clean up stale state for events no longer in calendar
    const currentIds = new Set(events.map(e => e.id));
    for (const [id, state] of this.states) {
      if (!currentIds.has(id) && state !== 'prompted' && state !== 'dismissed') {
        const timer = this.promptTimers.get(id);
        if (timer) {
          clearTimeout(timer);
          this.promptTimers.delete(id);
        }
        this.states.delete(id);
      }
    }
  }

  private transition(event: NormalizedEvent, current: MeetingState, now: Date): MeetingState {
    const start = new Date(event.start);
    const end = new Date(event.end);

    if (now >= end) {
      if (current === 'active') return 'ended';
      if (current === 'upcoming') return 'dismissed'; // missed the active window
      return current;
    }
    if (now >= start) return 'active';
    return 'upcoming';
  }
}

let instance: MeetingDetector | null = null;

export function getMeetingDetector(): MeetingDetector {
  if (!instance) instance = new MeetingDetector();
  return instance;
}
