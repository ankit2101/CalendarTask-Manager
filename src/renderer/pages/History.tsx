import React, { useEffect, useState } from 'react';
import { MeetingRecord } from '../../shared/types/calendar';

function formatDateTime(iso: string) {
  return new Date(iso).toLocaleString([], {
    weekday: 'short', month: 'short', day: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

function formatDuration(start: string, end: string): string {
  const mins = Math.round((new Date(end).getTime() - new Date(start).getTime()) / 60000);
  return mins >= 60 ? `${Math.floor(mins / 60)}h ${mins % 60 > 0 ? `${mins % 60}m` : ''}`.trim() : `${mins}m`;
}

export default function History() {
  const [records, setRecords] = useState<MeetingRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState<string | null>(null);

  useEffect(() => {
    window.api.getMeetingHistory().then(data => {
      setRecords(data);
      setLoading(false);
    });
  }, []);

  const filtered = records.filter(r =>
    r.title.toLowerCase().includes(search.toLowerCase()) ||
    r.note.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>Notes</h1>
          <p style={styles.subtitle}>Meeting notes from the last 90 days.</p>
        </div>
        <span style={styles.count}>{records.length} note{records.length !== 1 ? 's' : ''}</span>
      </div>

      <input
        style={styles.search}
        placeholder="Search notes…"
        value={search}
        onChange={e => setSearch(e.target.value)}
      />

      {loading && <div style={styles.empty}>Loading…</div>}

      {!loading && filtered.length === 0 && (
        <div style={styles.empty}>
          {search ? `No notes matching "${search}".` : 'No meeting notes yet.'}
          {!search && (
            <p style={{ fontSize: 13, color: '#45475a', marginTop: 8 }}>
              Use the "Add Notes" button on any past meeting to write notes.
            </p>
          )}
        </div>
      )}

      {filtered.map(record => (
        <div key={record.eventId} style={styles.card}>
          <div
            style={styles.cardHeader}
            onClick={() => setExpanded(expanded === record.eventId ? null : record.eventId)}
          >
            <div style={styles.cardHeaderLeft}>
              <div style={styles.cardTitle}>{record.title}</div>
              <div style={styles.cardMeta}>
                {formatDateTime(record.start)}
                {' · '}
                {formatDuration(record.start, record.end)}
                {record.actionItems.length > 0 && ` · ${record.actionItems.length} action item${record.actionItems.length !== 1 ? 's' : ''}`}
              </div>
              {/* Note preview when collapsed */}
              {expanded !== record.eventId && record.note && (
                <div style={styles.notePreview}>{record.note.slice(0, 120)}{record.note.length > 120 ? '…' : ''}</div>
              )}
            </div>
            <span style={styles.chevron}>{expanded === record.eventId ? '▲' : '▼'}</span>
          </div>

          {expanded === record.eventId && (
            <div style={styles.cardBody}>
              <div style={styles.noteSection}>
                <div style={styles.sectionLabel}>Notes</div>
                <p style={styles.noteText}>{record.note || '(no note written)'}</p>
              </div>

              {record.actionItems.length > 0 && (
                <div style={styles.noteSection}>
                  <div style={styles.sectionLabel}>Action Items</div>
                  {record.actionItems.map(item => (
                    <div key={item.id} style={styles.actionItem}>
                      <span style={styles.priorityIcon}>
                        {item.priority === 'urgent' ? '🔴' : item.priority === 'important' ? '🟡' : '⚪'}
                      </span>
                      <div>
                        <div style={styles.actionTitle}>{item.title}</div>
                        {item.description && (
                          <div style={styles.actionDesc}>{item.description}</div>
                        )}
                        {item.dueDate && (
                          <div style={styles.actionDue}>Due: {item.dueDate}</div>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {record.plannerTaskIds.length > 0 && (
                <div style={styles.plannerBadge}>
                  ✓ {record.plannerTaskIds.length} task{record.plannerTaskIds.length !== 1 ? 's' : ''} added to Planner
                </div>
              )}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 },
  title: { margin: '0 0 4px', fontSize: 24, fontWeight: 700, color: '#cdd6f4' },
  subtitle: { margin: 0, color: '#6c7086', fontSize: 13 },
  count: { color: '#45475a', fontSize: 13, marginTop: 6 },
  search: {
    width: '100%', background: '#313244', border: '1px solid #45475a',
    borderRadius: 8, padding: '8px 12px', color: '#cdd6f4', fontSize: 13,
    outline: 'none', boxSizing: 'border-box', marginBottom: 16,
  },
  empty: { textAlign: 'center', padding: 40, color: '#6c7086' },
  card: { background: '#313244', borderRadius: 8, marginBottom: 10, overflow: 'hidden' },
  cardHeader: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start',
    padding: '12px 16px', cursor: 'pointer',
  },
  cardHeaderLeft: { flex: 1, minWidth: 0 },
  cardTitle: { fontWeight: 600, color: '#cdd6f4' },
  cardMeta: { color: '#6c7086', fontSize: 12, marginTop: 2 },
  notePreview: {
    color: '#a6adc8', fontSize: 12, marginTop: 6,
    lineHeight: 1.5, whiteSpace: 'pre-wrap' as const,
  },
  chevron: { color: '#6c7086', fontSize: 12, marginLeft: 12, flexShrink: 0, marginTop: 2 },
  cardBody: { borderTop: '1px solid #45475a', padding: '12px 16px' },
  noteSection: { marginBottom: 16 },
  sectionLabel: { fontSize: 11, textTransform: 'uppercase' as const, letterSpacing: 0.8, color: '#6c7086', marginBottom: 6 },
  noteText: { color: '#a6adc8', fontSize: 13, margin: 0, lineHeight: 1.6, whiteSpace: 'pre-wrap' as const },
  actionItem: { display: 'flex', gap: 10, marginBottom: 8, alignItems: 'flex-start' },
  priorityIcon: { fontSize: 14, flexShrink: 0, marginTop: 1 },
  actionTitle: { color: '#cdd6f4', fontSize: 13 },
  actionDesc: { color: '#6c7086', fontSize: 12, marginTop: 2 },
  actionDue: { color: '#f9e2af', fontSize: 11, marginTop: 2 },
  plannerBadge: {
    background: '#a6e3a120', color: '#a6e3a1',
    padding: '6px 10px', borderRadius: 5, fontSize: 12, display: 'inline-block',
  },
};
