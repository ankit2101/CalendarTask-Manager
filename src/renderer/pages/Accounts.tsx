import React, { useEffect, useState } from 'react';
import { MicrosoftAccountRecord, GoogleAccountRecord, ICSAccountRecord } from '../../shared/types/account';

interface AccountsState {
  microsoft: MicrosoftAccountRecord[];
  google: GoogleAccountRecord[];
  ics: ICSAccountRecord[];
}

export default function Accounts() {
  const [accounts, setAccounts] = useState<AccountsState>({ microsoft: [], google: [], ics: [] });
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [showICSForm, setShowICSForm] = useState(false);
  const [icsUrl, setIcsUrl] = useState('');
  const [icsName, setIcsName] = useState('');

  useEffect(() => {
    loadAccounts();
  }, []);

  async function loadAccounts() {
    try {
      setLoading(true);
      const data = await window.api.getAccounts() as AccountsState;
      setAccounts(data);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  async function addMicrosoft() {
    try {
      setBusy('Adding Microsoft account…');
      setError('');
      await window.api.addMicrosoftAccount();
      await loadAccounts();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy('');
    }
  }

  async function addGoogle() {
    try {
      setBusy('Adding Google account…');
      setError('');
      await window.api.addGoogleAccount();
      await loadAccounts();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy('');
    }
  }

  async function addICSFeed() {
    if (!icsUrl.trim()) { setError('Please enter an ICS URL.'); return; }
    if (!icsName.trim()) { setError('Please enter a calendar name.'); return; }
    try {
      setBusy('Validating and adding ICS feed…');
      setError('');
      await window.api.addICSAccount(icsUrl.trim(), icsName.trim());
      setIcsUrl('');
      setIcsName('');
      setShowICSForm(false);
      await loadAccounts();
      await window.api.refreshEvents(); // fetch events from the newly added feed
    } catch (e) {
      setError(`Failed to add ICS feed: ${(e as Error).message}`);
    } finally {
      setBusy('');
    }
  }

  async function removeAccount(provider: 'microsoft' | 'google' | 'ics', id: string) {
    if (!confirm('Remove this account? You can re-add it later.')) return;
    try {
      await window.api.removeAccount(provider, id);
      await loadAccounts();
    } catch (e) {
      setError((e as Error).message);
    }
  }

  if (loading) return <div style={styles.loading}>Loading accounts…</div>;

  return (
    <div>
      <h1 style={styles.title}>Connected Accounts</h1>
      <p style={styles.subtitle}>Connect Outlook and Google Calendar accounts to monitor.</p>

      {error && <div style={styles.error}>{error}</div>}
      {busy && <div style={styles.info}>{busy}</div>}

      {/* Microsoft accounts */}
      <section style={styles.section}>
        <div style={styles.sectionHeader}>
          <span>🪟 Microsoft / Outlook</span>
          <button style={styles.addBtn} onClick={addMicrosoft} disabled={!!busy}>
            + Add Account
          </button>
        </div>
        {accounts.microsoft.length === 0 ? (
          <p style={styles.empty}>No Microsoft accounts connected.</p>
        ) : (
          accounts.microsoft.map(account => (
            <div key={account.id} style={styles.accountCard}>
              <div style={styles.avatar}>
                {account.displayName?.[0]?.toUpperCase() ?? 'M'}
              </div>
              <div style={styles.accountInfo}>
                <div style={styles.accountName}>{account.displayName}</div>
                <div style={styles.accountEmail}>{account.email}</div>
              </div>
              <button
                style={styles.removeBtn}
                onClick={() => removeAccount('microsoft', account.id)}
              >
                Remove
              </button>
            </div>
          ))
        )}
      </section>

      {/* Google accounts */}
      <section style={styles.section}>
        <div style={styles.sectionHeader}>
          <span>🟢 Google Calendar</span>
          <button style={styles.addBtn} onClick={addGoogle} disabled={!!busy}>
            + Add Account
          </button>
        </div>
        {accounts.google.length === 0 ? (
          <p style={styles.empty}>No Google accounts connected.</p>
        ) : (
          accounts.google.map(account => (
            <div key={account.id} style={styles.accountCard}>
              <div style={{ ...styles.avatar, background: '#a6e3a1' }}>
                {account.displayName?.[0]?.toUpperCase() ?? 'G'}
              </div>
              <div style={styles.accountInfo}>
                <div style={styles.accountName}>{account.displayName}</div>
                <div style={styles.accountEmail}>{account.email}</div>
              </div>
              <button
                style={styles.removeBtn}
                onClick={() => removeAccount('google', account.id)}
              >
                Remove
              </button>
            </div>
          ))
        )}
      </section>

      {/* ICS / Outlook Feed accounts */}
      <section style={styles.section}>
        <div style={styles.sectionHeader}>
          <span>📅 Outlook ICS Feed <span style={styles.badge}>No sign-in needed</span></span>
          <button style={styles.addBtn} onClick={() => setShowICSForm(v => !v)} disabled={!!busy}>
            {showICSForm ? 'Cancel' : '+ Add ICS Feed'}
          </button>
        </div>

        {showICSForm && (
          <div style={styles.icsForm}>
            <p style={styles.icsHelp}>
              In <strong>Outlook Web</strong>: Settings → Calendar → Shared calendars → Publish a calendar → Copy ICS link.
            </p>
            <input
              style={styles.input}
              type="text"
              placeholder="Calendar name (e.g. Work Calendar)"
              value={icsName}
              onChange={e => setIcsName(e.target.value)}
            />
            <input
              style={styles.input}
              type="url"
              placeholder="https://outlook.office365.com/owa/calendar/…/calendar.ics"
              value={icsUrl}
              onChange={e => setIcsUrl(e.target.value)}
            />
            <button style={styles.addBtn} onClick={addICSFeed} disabled={!!busy}>
              Add Feed
            </button>
          </div>
        )}

        {accounts.ics.length === 0 && !showICSForm ? (
          <p style={styles.empty}>No ICS feeds connected. Use this if Microsoft sign-in requires admin approval.</p>
        ) : (
          accounts.ics.map(account => (
            <div key={account.id} style={styles.accountCard}>
              <div style={{ ...styles.avatar, background: '#fab387' }}>
                {account.displayName?.[0]?.toUpperCase() ?? 'I'}
              </div>
              <div style={styles.accountInfo}>
                <div style={styles.accountName}>{account.displayName}</div>
                <div style={styles.accountEmail} title={account.url}>
                  ICS Feed · {account.url.length > 50 ? account.url.slice(0, 50) + '…' : account.url}
                </div>
              </div>
              <button
                style={styles.removeBtn}
                onClick={() => removeAccount('ics', account.id)}
              >
                Remove
              </button>
            </div>
          ))
        )}
      </section>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  title: { margin: '0 0 6px', fontSize: 24, fontWeight: 700, color: '#cdd6f4' },
  subtitle: { margin: '0 0 24px', color: '#6c7086', fontSize: 13 },
  loading: { color: '#6c7086', padding: 24 },
  error: {
    background: '#f38ba820', border: '1px solid #f38ba8',
    borderRadius: 8, padding: '12px 16px', marginBottom: 16, color: '#f38ba8',
  },
  info: {
    background: '#89b4fa20', border: '1px solid #89b4fa',
    borderRadius: 8, padding: '12px 16px', marginBottom: 16, color: '#89b4fa',
  },
  section: { marginBottom: 32 },
  sectionHeader: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    marginBottom: 12, fontWeight: 600, color: '#a6adc8', fontSize: 13,
    textTransform: 'uppercase', letterSpacing: 0.8,
  },
  addBtn: {
    background: '#cba6f7', border: 'none', color: '#1e1e2e',
    padding: '6px 14px', borderRadius: 6, cursor: 'pointer',
    fontWeight: 600, fontSize: 13,
  },
  empty: { color: '#6c7086', fontSize: 13, padding: '12px 0' },
  accountCard: {
    display: 'flex', alignItems: 'center', gap: 12,
    background: '#313244', borderRadius: 8, padding: '12px 16px',
    marginBottom: 8,
  },
  avatar: {
    width: 36, height: 36, borderRadius: '50%',
    background: '#89b4fa', display: 'flex', alignItems: 'center',
    justifyContent: 'center', fontWeight: 700, color: '#1e1e2e',
    flexShrink: 0,
  },
  accountInfo: { flex: 1 },
  accountName: { fontWeight: 600, color: '#cdd6f4' },
  accountEmail: { color: '#6c7086', fontSize: 12, marginTop: 2 },
  removeBtn: {
    background: 'transparent', border: '1px solid #45475a',
    color: '#f38ba8', padding: '4px 10px', borderRadius: 5,
    cursor: 'pointer', fontSize: 12,
  },
  icsForm: {
    background: '#1e1e2e', border: '1px solid #45475a',
    borderRadius: 8, padding: '16px', marginBottom: 12,
    display: 'flex', flexDirection: 'column' as const, gap: 10,
  },
  icsHelp: {
    color: '#a6adc8', fontSize: 12, margin: 0, lineHeight: 1.5,
  },
  input: {
    background: '#313244', border: '1px solid #45475a',
    borderRadius: 6, padding: '8px 12px', color: '#cdd6f4',
    fontSize: 13, outline: 'none', width: '100%', boxSizing: 'border-box' as const,
  },
  badge: {
    background: '#a6e3a120', border: '1px solid #a6e3a1',
    color: '#a6e3a1', fontSize: 10, borderRadius: 4,
    padding: '1px 6px', marginLeft: 8, fontWeight: 400,
    textTransform: 'none' as const, letterSpacing: 0,
  },
};
