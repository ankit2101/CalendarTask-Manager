import React, { useEffect, useState, useCallback } from 'react';
import { NormalizedEvent, MeetingRecord } from '../../shared/types/calendar';

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatDate(d: Date) {
  return d.toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' });
}

function startOfDay(d: Date): Date {
  const result = new Date(d);
  result.setHours(0, 0, 0, 0);
  return result;
}

function isSameDay(a: Date, b: Date): boolean {
  return a.toDateString() === b.toDateString();
}

function eventStatus(event: NormalizedEvent): 'past' | 'active' | 'upcoming' {
  const now = new Date();
  const start = new Date(event.start);
  const end = new Date(event.end);
  if (now > end) return 'past';
  if (now >= start) return 'active';
  return 'upcoming';
}

// Patterns for leave/OOO events to hide from the calendar view.
// Acronyms (PTO, OOO, DTO, etc.) are matched as whole words; phrases use substring match.
const LEAVE_ACRONYMS = /\b(PTO|OOO|DTO|WTO|OOF|LOA)\b/i;
const LEAVE_PHRASES = [
  'out of office', 'on leave', 'annual leave', 'sick leave', 'parental leave',
  'maternity leave', 'paternity leave', 'family leave', 'bereavement',
  'vacation', 'holiday', 'time off', 'day off', 'days off',
  'paid leave', 'unpaid leave', 'sabbatical', 'away',
];

function isLeaveEvent(event: NormalizedEvent): boolean {
  const title = event.title.toLowerCase();
  if (LEAVE_ACRONYMS.test(event.title)) return true;
  return LEAVE_PHRASES.some(phrase => title.includes(phrase));
}

const STATUS_COLORS = { past: '#6c7086', active: '#a6e3a1', upcoming: '#cdd6f4' };
const STATUS_DOT = { past: '○', active: '●', upcoming: '◌' };
const MISSING_NOTE_COLOR = '#f9e2af';

// Distinct Catppuccin-palette colors for calendar accounts
const ACCOUNT_PALETTE = [
  '#89b4fa', // blue
  '#cba6f7', // mauve
  '#a6e3a1', // green
  '#fab387', // peach
  '#f38ba8', // red
  '#94e2d5', // teal
  '#f9e2af', // yellow
  '#89dceb', // sky
  '#b4befe', // lavender
  '#eba0ac', // maroon
];

// Deterministic color per accountId so the same account always gets the same color
function accountColor(accountId: string): string {
  let hash = 0;
  for (let i = 0; i < accountId.length; i++) {
    hash = (hash * 31 + accountId.charCodeAt(i)) & 0xffffffff;
  }
  return ACCOUNT_PALETTE[Math.abs(hash) % ACCOUNT_PALETTE.length];
}

export default function Dashboard() {
  const [events, setEvents] = useState<NormalizedEvent[]>([]);
  const [history, setHistory] = useState<MeetingRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);
  const [selectedDate, setSelectedDate] = useState(() => startOfDay(new Date()));

  const fetchEvents = useCallback(async (forceRefresh: boolean) => {
    try {
      setLoading(true);
      setError('');
      const [data, hist] = await Promise.all([
        forceRefresh ? window.api.refreshEvents() : window.api.getEvents(),
        window.api.getMeetingHistory(),
      ]);
      setEvents(data);
      setHistory(hist);
      setLastRefresh(new Date());
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchEvents(false);
  }, [fetchEvents]);

  // Auto-refresh when background sync delivers new events
  useEffect(() => {
    return window.api.onCalendarSynced(events => {
      setEvents(events);
      setLastRefresh(new Date());
    });
  }, []);

  const today = startOfDay(new Date());
  const isToday = isSameDay(selectedDate, today);

  const selectedDateEvents = events.filter(
    e => new Date(e.start).toDateString() === selectedDate.toDateString() && !isLeaveEvent(e)
  );

  const notedEventIds = new Set(history.map(r => r.eventId));
  const now = new Date();

  function isMissingNote(event: NormalizedEvent): boolean {
    return new Date(event.end) < now && !notedEventIds.has(event.id);
  }

  const missingCount = selectedDateEvents.filter(isMissingNote).length;

  function goBack() {
    setSelectedDate(d => {
      const prev = new Date(d);
      prev.setDate(prev.getDate() - 1);
      return prev;
    });
  }

  function goForward() {
    setSelectedDate(d => {
      const next = new Date(d);
      next.setDate(next.getDate() + 1);
      return next;
    });
  }

  function goToday() {
    setSelectedDate(startOfDay(new Date()));
  }

  const titleLabel = isToday ? 'Today' : selectedDate.toLocaleDateString([], { weekday: 'long' });

  return (
    <div>
      <div style={styles.header}>
        <div style={styles.headerLeft}>
          <div style={styles.navRow}>
            <button style={styles.navBtn} onClick={goBack} title="Previous day">‹</button>
            <h1 style={styles.title}>{titleLabel}</h1>
            <button style={styles.navBtn} onClick={goForward} title="Next day">›</button>
          </div>
          <p style={styles.subtitle}>{formatDate(selectedDate)}</p>
        </div>
        <div style={styles.headerRight}>
          {!isToday && (
            <button style={styles.todayBtn} onClick={goToday}>Today</button>
          )}
          <button style={styles.refreshBtn} onClick={() => fetchEvents(true)} disabled={loading}>
            {loading ? '↻ Refreshing…' : '↻ Refresh'}
          </button>
        </div>
      </div>

      {error && <div style={styles.error}>{error}</div>}

      {missingCount > 0 && (
        <div style={styles.missingBanner}>
          ✏️ {missingCount} meeting{missingCount !== 1 ? 's' : ''} need{missingCount === 1 ? 's' : ''} notes
        </div>
      )}

      {!loading && selectedDateEvents.length === 0 && (
        <div style={styles.empty}>
          <p>No meetings on this day.</p>
          {events.length === 0 && (
            <p style={{ fontSize: 13, color: '#6c7086', marginTop: 8 }}>
              Add calendar accounts in the Accounts tab to see your events.
            </p>
          )}
        </div>
      )}

      <div style={styles.eventList}>
        {selectedDateEvents.map(event => {
          const status = eventStatus(event);
          const missing = isMissingNote(event);
          const hasNote = notedEventIds.has(event.id);
          const calColor = accountColor(event.accountId);
          const borderColor = missing ? MISSING_NOTE_COLOR : calColor;

          return (
            <div
              key={event.id}
              style={{
                ...styles.eventCard,
                borderLeft: `4px solid ${borderColor}`,
                background: `linear-gradient(90deg, ${calColor}18 0%, #313244 60%)`,
                opacity: status === 'past' && !missing ? 0.7 : 1,
              }}
            >
              <div style={styles.eventHeader}>
                <span style={{ color: STATUS_COLORS[status], marginRight: 6, fontSize: 12 }}>
                  {STATUS_DOT[status]}
                </span>
                <span style={styles.eventTitle}>{event.title}</span>
                {missing && (
                  <span style={styles.missingBadge}>note missing</span>
                )}
                <span
                  style={{
                    ...styles.calPill,
                    background: `${calColor}30`,
                    color: calColor,
                    border: `1px solid ${calColor}60`,
                  }}
                >
                  {event.provider === 'microsoft' ? '🪟' : event.provider === 'google' ? '🟢' : '📅'}
                </span>
              </div>
              <div style={styles.eventMeta}>
                <span>{formatTime(event.start)} – {formatTime(event.end)}</span>
                {event.attendees.length > 1 && (
                  <span style={styles.attendeeCount}>
                    · {event.attendees.length} attendees
                  </span>
                )}
                {event.isOnlineMeeting && <span style={styles.tag}>Online</span>}
              </div>
              {event.location && (
                <div style={styles.location}>📍 {event.location}</div>
              )}
              {status === 'past' && (
                <div style={styles.noteRow}>
                  {hasNote ? (
                    <span style={styles.notedLabel}>✓ Note saved</span>
                  ) : (
                    <button
                      style={styles.addNoteBtn}
                      onClick={() => window.api.openQuickNote(event)}
                    >
                      + Add Notes
                    </button>
                  )}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {lastRefresh && (
        <p style={styles.lastRefresh}>
          Last updated {lastRefresh.toLocaleTimeString()}
        </p>
      )}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 24 },
  headerLeft: { display: 'flex', flexDirection: 'column', gap: 2 },
  headerRight: { display: 'flex', alignItems: 'center', gap: 8 },
  navRow: { display: 'flex', alignItems: 'center', gap: 6 },
  title: { margin: 0, fontSize: 24, fontWeight: 700, color: '#cdd6f4' },
  subtitle: { margin: '4px 0 0', color: '#6c7086', fontSize: 13 },
  navBtn: {
    background: 'none', border: 'none', color: '#6c7086',
    fontSize: 22, cursor: 'pointer', padding: '0 2px', lineHeight: 1,
  },
  todayBtn: {
    background: '#313244', border: 'none', color: '#89b4fa',
    padding: '6px 12px', borderRadius: 6, cursor: 'pointer', fontSize: 13,
  },
  refreshBtn: {
    background: '#313244', border: 'none', color: '#cdd6f4',
    padding: '6px 14px', borderRadius: 6, cursor: 'pointer', fontSize: 13,
  },
  missingBanner: {
    background: '#f9e2af20', border: '1px solid #f9e2af40',
    borderRadius: 8, padding: '8px 14px', marginBottom: 16,
    color: '#f9e2af', fontSize: 13,
  },
  error: {
    background: '#f38ba820', border: '1px solid #f38ba8',
    borderRadius: 8, padding: '12px 16px', marginBottom: 16, color: '#f38ba8',
  },
  empty: { textAlign: 'center', padding: 40, color: '#6c7086' },
  eventList: { display: 'flex', flexDirection: 'column', gap: 10 },
  eventCard: {
    background: '#313244', borderRadius: 8, padding: '12px 16px',
    borderLeft: '3px solid #cdd6f4',
  },
  eventHeader: { display: 'flex', alignItems: 'center', marginBottom: 4 },
  eventTitle: { flex: 1, fontWeight: 600, color: '#cdd6f4' },
  missingBadge: {
    background: '#f9e2af20', color: '#f9e2af',
    fontSize: 10, padding: '2px 6px', borderRadius: 4, marginRight: 6,
    fontWeight: 600, textTransform: 'uppercase' as const, letterSpacing: '0.04em',
  },
  calPill: {
    fontSize: 11, padding: '1px 6px', borderRadius: 4,
    marginLeft: 6, flexShrink: 0, fontWeight: 600,
  },
  eventMeta: { color: '#a6adc8', fontSize: 13 },
  attendeeCount: { marginLeft: 4 },
  tag: {
    display: 'inline-block', marginLeft: 8,
    background: '#89b4fa20', color: '#89b4fa',
    padding: '1px 6px', borderRadius: 4, fontSize: 11,
  },
  location: { color: '#6c7086', fontSize: 12, marginTop: 4 },
  noteRow: { marginTop: 8, display: 'flex', justifyContent: 'flex-end' },
  addNoteBtn: {
    background: 'none', border: '1px solid #f9e2af60', color: '#f9e2af',
    padding: '4px 10px', borderRadius: 5, cursor: 'pointer', fontSize: 12,
  },
  notedLabel: { color: '#a6e3a1', fontSize: 12 },
  lastRefresh: { marginTop: 16, color: '#45475a', fontSize: 12, textAlign: 'right' },
};
