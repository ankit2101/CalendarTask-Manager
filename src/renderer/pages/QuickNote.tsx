import React, { useEffect, useState, useCallback } from 'react';
import { NormalizedEvent, ActionItem } from '../../shared/types/calendar';
import { AppSettings } from '../../shared/types/settings';
import { PlannerPlan, PlannerBucket } from '../../shared/types/planner';
import { MicrosoftAccountRecord } from '../../shared/types/account';

type Step = 'note' | 'extracting' | 'review' | 'submitting' | 'done' | 'error';

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

export default function QuickNote() {
  const [event, setEvent] = useState<NormalizedEvent | null>(null);
  const [note, setNote] = useState('');
  const [step, setStep] = useState<Step>('note');
  const [actionItems, setActionItems] = useState<ActionItem[]>([]);
  const [error, setError] = useState('');

  // Planner selection
  const [msAccounts, setMsAccounts] = useState<MicrosoftAccountRecord[]>([]);
  const [plans, setPlans] = useState<PlannerPlan[]>([]);
  const [buckets, setBuckets] = useState<PlannerBucket[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState('');
  const [selectedPlanId, setSelectedPlanId] = useState('');
  const [selectedBucketId, setSelectedBucketId] = useState('');

  // Listen for meeting-ended event from main process
  useEffect(() => {
    const unsubscribe = window.api?.onMeetingEnded?.((ev: NormalizedEvent) => {
      setEvent(ev);
    });
    return () => unsubscribe?.();
  }, []);

  // Load default planner settings
  useEffect(() => {
    async function loadDefaults() {
      try {
        const settings = await window.api.getSettings() as AppSettings;
        const accs = await window.api.getAccounts() as { microsoft: MicrosoftAccountRecord[] };
        setMsAccounts(accs.microsoft ?? []);

        if (settings.defaultPlannerAccountId) {
          setSelectedAccountId(settings.defaultPlannerAccountId);
          const p = await window.api.getPlans(settings.defaultPlannerAccountId) as PlannerPlan[];
          setPlans(p);

          if (settings.defaultPlanId) {
            setSelectedPlanId(settings.defaultPlanId);
            const b = await window.api.getBuckets(settings.defaultPlanId, settings.defaultPlannerAccountId) as PlannerBucket[];
            setBuckets(b);

            if (settings.defaultBucketId) {
              setSelectedBucketId(settings.defaultBucketId);
            }
          }
        }
      } catch (e) {
        console.error('Failed to load planner defaults:', e);
      }
    }
    loadDefaults();
  }, []);

  const handleExtract = useCallback(async () => {
    if (!event || !note.trim()) return;
    setStep('extracting');
    try {
      const items = await window.api.extractActionItems(note, event);
      setActionItems(items);
      setStep('review');
    } catch (e) {
      setError((e as Error).message);
      setStep('error');
    }
  }, [event, note]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      handleExtract();
    }
    if (e.key === 'Escape') {
      handleDismiss();
    }
  }, [handleExtract]);

  const handleDismiss = useCallback(() => {
    if (event) window.api.dismissMeeting(event.id);
    window.close();
  }, [event]);

  const handleSubmit = useCallback(async () => {
    if (!event) {
      setError('No meeting context. Cannot save note.');
      return;
    }
    // Only require Planner selection when there are action items to push
    if (actionItems.length > 0 && msAccounts.length > 0 && (!selectedPlanId || !selectedBucketId || !selectedAccountId)) {
      setError('Please select a Planner plan and bucket before submitting.');
      return;
    }
    setStep('submitting');
    try {
      await window.api.submitNote({
        event,
        note,
        actionItems,
        planId: selectedPlanId,
        bucketId: selectedBucketId,
        accountId: selectedAccountId,
      });
      setStep('done');
      setTimeout(() => window.close(), 1500);
    } catch (e) {
      setError((e as Error).message);
      setStep('error');
    }
  }, [event, note, actionItems, selectedPlanId, selectedBucketId, selectedAccountId]);

  const updateActionItem = (id: string, updates: Partial<ActionItem>) => {
    setActionItems(items => items.map(item => item.id === id ? { ...item, ...updates } : item));
  };

  const removeActionItem = (id: string) => {
    setActionItems(items => items.filter(item => item.id !== id));
  };

  // Window chrome
  return (
    <div style={styles.container} onKeyDown={handleKeyDown}>
      {/* Title bar drag region */}
      <div style={styles.titleBar}>
        <span style={styles.windowTitle}>
          {step === 'done' ? '✓ Tasks added to Planner' : 'Meeting Note'}
        </span>
        <button style={styles.closeBtn} onClick={handleDismiss}>✕</button>
      </div>

      <div style={styles.body}>
        {/* Meeting info */}
        {event && (
          <div style={styles.meetingInfo}>
            <span style={styles.meetingTitle}>{event.title}</span>
            <span style={styles.meetingTime}>
              {formatTime(event.start)} – {formatTime(event.end)}
            </span>
          </div>
        )}

        {!event && (
          <div style={styles.meetingInfo}>
            <span style={styles.meetingTitle}>Quick Note</span>
            <span style={styles.meetingTime}>No meeting context</span>
          </div>
        )}

        {/* Step: Write note */}
        {(step === 'note' || step === 'extracting') && (
          <>
            <textarea
              autoFocus
              style={styles.textarea}
              placeholder="What happened in this meeting? Action items, decisions, follow-ups…"
              value={note}
              onChange={e => setNote(e.target.value)}
              disabled={step === 'extracting'}
            />
            <div style={styles.hint}>⌘↵ to extract action items · Esc to dismiss</div>
            <div style={styles.actions}>
              <button style={styles.btnSecondary} onClick={handleDismiss}>
                Skip
              </button>
              <button
                style={step === 'extracting' ? styles.btnDisabled : styles.btnPrimary}
                onClick={handleExtract}
                disabled={step === 'extracting' || !note.trim()}
              >
                {step === 'extracting' ? 'Extracting…' : 'Extract Action Items →'}
              </button>
            </div>
          </>
        )}

        {/* Step: Review action items */}
        {step === 'review' && (
          <>
            {error && <div style={styles.errorBox}>{error}</div>}
            <div style={styles.reviewHeader}>
              {actionItems.length === 0
                ? 'No action items found. Submit note anyway?'
                : `Found ${actionItems.length} action item${actionItems.length !== 1 ? 's' : ''}:`}
            </div>

            <div style={styles.actionList}>
              {actionItems.map(item => (
                <div key={item.id} style={styles.actionCard}>
                  <select
                    style={styles.prioritySelect}
                    value={item.priority}
                    onChange={e => updateActionItem(item.id, { priority: e.target.value as ActionItem['priority'] })}
                  >
                    <option value="urgent">🔴</option>
                    <option value="important">🟡</option>
                    <option value="normal">⚪</option>
                  </select>
                  <div style={{ flex: 1 }}>
                    <input
                      style={styles.actionInput}
                      value={item.title}
                      onChange={e => updateActionItem(item.id, { title: e.target.value })}
                    />
                    {item.dueDate && (
                      <div style={styles.actionDue}>Due: {item.dueDate}</div>
                    )}
                  </div>
                  <button style={styles.removeBtn} onClick={() => removeActionItem(item.id)}>✕</button>
                </div>
              ))}
            </div>

            {/* Planner target selection */}
            {msAccounts.length > 0 && (
              <div style={styles.plannerSection}>
                <select
                  style={styles.plannerSelect}
                  value={selectedAccountId}
                  onChange={async e => {
                    setSelectedAccountId(e.target.value);
                    setSelectedPlanId('');
                    setSelectedBucketId('');
                    if (e.target.value) {
                      const p = await window.api.getPlans(e.target.value) as PlannerPlan[];
                      setPlans(p);
                    }
                  }}
                >
                  <option value="">Account…</option>
                  {msAccounts.map(a => <option key={a.id} value={a.id}>{a.email}</option>)}
                </select>
                <select
                  style={styles.plannerSelect}
                  value={selectedPlanId}
                  disabled={!plans.length}
                  onChange={async e => {
                    setSelectedPlanId(e.target.value);
                    setSelectedBucketId('');
                    if (e.target.value && selectedAccountId) {
                      const b = await window.api.getBuckets(e.target.value, selectedAccountId) as PlannerBucket[];
                      setBuckets(b);
                    }
                  }}
                >
                  <option value="">Plan…</option>
                  {plans.map(p => <option key={p.id} value={p.id}>{p.title}</option>)}
                </select>
                <select
                  style={styles.plannerSelect}
                  value={selectedBucketId}
                  disabled={!buckets.length}
                  onChange={e => setSelectedBucketId(e.target.value)}
                >
                  <option value="">Bucket…</option>
                  {buckets.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
                </select>
              </div>
            )}

            <div style={styles.actions}>
              <button style={styles.btnSecondary} onClick={() => { setStep('note'); setError(''); }}>
                ← Back
              </button>
              {(() => {
                const needsPlanner = actionItems.length > 0 && msAccounts.length > 0;
                const plannerReady = !!(selectedAccountId && selectedPlanId && selectedBucketId);
                const isDisabled = needsPlanner && !plannerReady;
                return (
                  <button
                    style={isDisabled ? styles.btnDisabled : styles.btnPrimary}
                    onClick={handleSubmit}
                    disabled={isDisabled}
                  >
                    {actionItems.length > 0 ? 'Add to Planner →' : 'Save Note'}
                  </button>
                );
              })()}
            </div>
          </>
        )}

        {/* Step: Submitting */}
        {step === 'submitting' && (
          <div style={styles.centered}>Adding tasks to Microsoft Planner…</div>
        )}

        {/* Step: Done */}
        {step === 'done' && (
          <div style={{ ...styles.centered, color: '#a6e3a1' }}>
            ✓ Done! Closing window…
          </div>
        )}

        {/* Step: Error */}
        {step === 'error' && (
          <>
            <div style={styles.errorBox}>{error}</div>
            <div style={styles.actions}>
              <button style={styles.btnSecondary} onClick={() => setStep('note')}>Try Again</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    display: 'flex', flexDirection: 'column',
    height: '100vh', background: '#1e1e2e',
    color: '#cdd6f4', fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    fontSize: 14, overflow: 'hidden',
  },
  titleBar: {
    height: 38, display: 'flex', alignItems: 'center',
    padding: '0 12px 0 80px', /* leave space for traffic lights */
    WebkitAppRegion: 'drag',
    background: '#181825', flexShrink: 0,
    justifyContent: 'space-between',
  },
  windowTitle: { fontSize: 13, fontWeight: 600, color: '#a6adc8' },
  closeBtn: {
    WebkitAppRegion: 'no-drag',
    background: 'transparent', border: 'none', color: '#6c7086',
    cursor: 'pointer', fontSize: 14, padding: '2px 6px',
  },
  body: {
    flex: 1, padding: '12px 16px 16px', display: 'flex',
    flexDirection: 'column', overflow: 'auto',
  },
  meetingInfo: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
    marginBottom: 10,
  },
  meetingTitle: { fontWeight: 700, color: '#cba6f7', fontSize: 15, flex: 1 },
  meetingTime: { color: '#6c7086', fontSize: 12, flexShrink: 0, marginLeft: 8 },
  textarea: {
    flex: 1, minHeight: 120, background: '#313244',
    border: '1px solid #45475a', borderRadius: 8,
    padding: '10px 12px', color: '#cdd6f4',
    fontSize: 13, lineHeight: 1.6, resize: 'none',
    outline: 'none', fontFamily: 'inherit',
  },
  hint: { color: '#45475a', fontSize: 11, marginTop: 4, marginBottom: 8 },
  actions: { display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 },
  btnPrimary: {
    background: '#cba6f7', border: 'none', color: '#1e1e2e',
    padding: '8px 16px', borderRadius: 7, cursor: 'pointer',
    fontWeight: 700, fontSize: 13,
  },
  btnSecondary: {
    background: '#313244', border: '1px solid #45475a', color: '#a6adc8',
    padding: '8px 14px', borderRadius: 7, cursor: 'pointer', fontSize: 13,
  },
  btnDisabled: {
    background: '#45475a', border: 'none', color: '#6c7086',
    padding: '8px 16px', borderRadius: 7, cursor: 'not-allowed', fontSize: 13,
  },
  reviewHeader: { color: '#a6adc8', fontSize: 13, marginBottom: 8 },
  actionList: { display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 10 },
  actionCard: {
    display: 'flex', alignItems: 'center', gap: 6,
    background: '#313244', borderRadius: 6, padding: '6px 10px',
  },
  prioritySelect: {
    background: 'transparent', border: 'none', color: '#cdd6f4',
    fontSize: 16, cursor: 'pointer', outline: 'none',
  },
  actionInput: {
    background: 'transparent', border: 'none', borderBottom: '1px solid #45475a',
    color: '#cdd6f4', fontSize: 13, padding: '2px 0', outline: 'none', width: '100%',
  },
  actionDue: { color: '#f9e2af', fontSize: 11, marginTop: 2 },
  removeBtn: {
    background: 'transparent', border: 'none', color: '#6c7086',
    cursor: 'pointer', fontSize: 12, padding: '2px 4px',
  },
  plannerSection: { display: 'flex', gap: 6, marginBottom: 8, flexWrap: 'wrap' },
  plannerSelect: {
    flex: 1, minWidth: 100,
    background: '#313244', border: '1px solid #45475a',
    borderRadius: 6, padding: '6px 8px', color: '#cdd6f4',
    fontSize: 12, outline: 'none',
  },
  centered: { flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#a6adc8' },
  errorBox: {
    background: '#f38ba820', border: '1px solid #f38ba8',
    borderRadius: 8, padding: '10px 14px', marginBottom: 10, color: '#f38ba8', fontSize: 13,
  },
};
