import React, { useEffect, useState } from 'react';
import { AppSettings } from '../../shared/types/settings';

export default function Settings() {
  const [settings, setSettings] = useState<Partial<AppSettings>>({});
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [backupStatus, setBackupStatus] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // Credential fields (not stored in settings, go to Keychain)
  const [claudeApiKey, setClaudeApiKey] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    try {
      const s = await window.api.getSettings() as AppSettings;
      setSettings(s);
    } catch (e) {
      setError((e as Error).message);
    }
  }

  async function handleBrowseFolder() {
    const folder = await window.api.selectFolder();
    if (!folder) return;
    update('dataFolderPath', folder);
    // Save immediately so the auto-export in the store picks up the new path
    try {
      await window.api.saveSettings({ dataFolderPath: folder });
      setBackupStatus({ type: 'success', message: `Folder set. Initial backup created at ${folder}/caltask-backup.json` });
    } catch (e) {
      setBackupStatus({ type: 'error', message: (e as Error).message });
    }
  }

  async function handleExport() {
    try {
      setBackupStatus(null);
      const filePath = await window.api.exportData();
      setBackupStatus({ type: 'success', message: `Exported to ${filePath}` });
    } catch (e) {
      setBackupStatus({ type: 'error', message: (e as Error).message });
    }
  }

  async function handleImport() {
    try {
      setBackupStatus(null);
      const result = await window.api.importData();
      const d = new Date(result.exportedAt).toLocaleString();
      setBackupStatus({
        type: 'success',
        message: `Imported ${result.meetingHistoryCount} meeting records and ${result.todoTaskCount} tasks (backup from ${d}).`,
      });
    } catch (e) {
      setBackupStatus({ type: 'error', message: (e as Error).message });
    }
  }

  async function save() {
    try {
      setError('');
      const payload: Record<string, unknown> = { ...settings };
      if (claudeApiKey) payload.claudeApiKey = claudeApiKey;

      await window.api.saveSettings(payload);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);

      // Reset credential fields after save
      setClaudeApiKey('');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const update = (key: keyof AppSettings, value: unknown) =>
    setSettings(s => ({ ...s, [key]: value }));

  return (
    <div>
      <h1 style={styles.title}>Settings</h1>

      {error && <div style={styles.error}>{error}</div>}
      {saved && <div style={styles.success}>Settings saved!</div>}

      {/* API Credentials */}
      <section style={styles.section}>
        <div style={styles.sectionTitle}>API Credentials</div>
        <p style={styles.hint}>Stored securely in macOS Keychain. Leave blank to keep existing value.</p>

        <label style={styles.label}>Claude API Key</label>
        <input
          type="password"
          style={styles.input}
          placeholder="sk-ant-…"
          value={claudeApiKey}
          onChange={e => setClaudeApiKey(e.target.value)}
        />
      </section>

      {/* Meeting Detection */}
      <section style={styles.section}>
        <div style={styles.sectionTitle}>Meeting Detection</div>

        <label style={styles.label}>
          Minimum attendees to trigger note prompt: {settings.minimumAttendeesForPrompt ?? 2}
        </label>
        <input
          type="range" min={1} max={10}
          value={settings.minimumAttendeesForPrompt ?? 2}
          onChange={e => update('minimumAttendeesForPrompt', Number(e.target.value))}
          style={styles.range}
        />

        <label style={styles.label}>
          Delay before prompt after meeting ends: {settings.promptDelayMinutes ?? 2} min
        </label>
        <input
          type="range" min={0} max={10}
          value={settings.promptDelayMinutes ?? 2}
          onChange={e => update('promptDelayMinutes', Number(e.target.value))}
          style={styles.range}
        />

        <label style={styles.label}>
          Polling interval: {settings.pollingIntervalSeconds ?? 30}s
        </label>
        <input
          type="range" min={15} max={120} step={5}
          value={settings.pollingIntervalSeconds ?? 30}
          onChange={e => update('pollingIntervalSeconds', Number(e.target.value))}
          style={styles.range}
        />
      </section>

      {/* Keyboard Shortcuts */}
      <section style={styles.section}>
        <div style={styles.sectionTitle}>Keyboard Shortcuts</div>

        <label style={styles.label}>Quick Note</label>
        <input
          type="text"
          style={styles.input}
          value={settings.globalShortcutQuickNote ?? ''}
          onChange={e => update('globalShortcutQuickNote', e.target.value)}
        />

        <label style={styles.label}>Toggle Main Window</label>
        <input
          type="text"
          style={styles.input}
          value={settings.globalShortcutToggleApp ?? ''}
          onChange={e => update('globalShortcutToggleApp', e.target.value)}
        />
      </section>

      {/* General */}
      <section style={styles.section}>
        <div style={styles.sectionTitle}>General</div>

        <label style={styles.checkLabel}>
          <input
            type="checkbox"
            checked={settings.launchAtLogin ?? true}
            onChange={e => {
              update('launchAtLogin', e.target.checked);
              window.api.setLaunchAtLogin(e.target.checked);
            }}
          />
          Launch at login
        </label>

        <label style={styles.checkLabel}>
          <input
            type="checkbox"
            checked={settings.showDockIcon ?? false}
            onChange={e => update('showDockIcon', e.target.checked)}
          />
          Show dock icon (requires restart)
        </label>
      </section>

      {/* Data Storage */}
      <section style={styles.section}>
        <div style={styles.sectionTitle}>Data Storage & Backup</div>
        <p style={styles.hint}>
          Export your meeting history and tasks to a local folder. Use the backup file to restore data if something goes wrong.
        </p>

        <label style={styles.label}>Backup Folder</label>
        <div style={styles.folderRow}>
          <input
            type="text"
            style={{ ...styles.input, flex: 1 }}
            placeholder="No folder selected"
            value={settings.dataFolderPath ?? ''}
            readOnly
          />
          <button style={styles.browseBtn} onClick={handleBrowseFolder}>Browse…</button>
        </div>

        {backupStatus && (
          <div style={backupStatus.type === 'success' ? styles.backupSuccess : styles.backupError}>
            {backupStatus.message}
          </div>
        )}

        <div style={styles.backupActions}>
          <button
            style={settings.dataFolderPath ? styles.exportBtn : styles.exportBtnDisabled}
            onClick={handleExport}
            disabled={!settings.dataFolderPath}
            title={settings.dataFolderPath ? 'Export to caltask-backup.json in the selected folder' : 'Select a folder first'}
          >
            ↑ Export Backup
          </button>
          <button
            style={settings.dataFolderPath ? styles.importBtn : styles.exportBtnDisabled}
            onClick={handleImport}
            disabled={!settings.dataFolderPath}
            title={settings.dataFolderPath ? 'Restore from caltask-backup.json in the selected folder' : 'Select a folder first'}
          >
            ↓ Import Backup
          </button>
        </div>
        <p style={styles.hint}>
          The backup file is named <code style={styles.code}>caltask-backup.json</code>. Importing will overwrite current data.
        </p>
      </section>

      <button style={styles.saveBtn} onClick={save}>Save Settings</button>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  title: { margin: '0 0 24px', fontSize: 24, fontWeight: 700, color: '#cdd6f4' },
  error: {
    background: '#f38ba820', border: '1px solid #f38ba8',
    borderRadius: 8, padding: '12px 16px', marginBottom: 16, color: '#f38ba8',
  },
  success: {
    background: '#a6e3a120', border: '1px solid #a6e3a1',
    borderRadius: 8, padding: '12px 16px', marginBottom: 16, color: '#a6e3a1',
  },
  section: { marginBottom: 28 },
  sectionTitle: {
    fontWeight: 700, color: '#cba6f7', fontSize: 13,
    textTransform: 'uppercase', letterSpacing: 0.8, marginBottom: 14,
    borderBottom: '1px solid #313244', paddingBottom: 6,
  },
  hint: { color: '#6c7086', fontSize: 12, margin: '0 0 12px' },
  label: { display: 'block', color: '#a6adc8', fontSize: 13, marginBottom: 4, marginTop: 12 },
  input: {
    width: '100%', background: '#313244', border: '1px solid #45475a',
    borderRadius: 6, padding: '8px 10px', color: '#cdd6f4', fontSize: 13,
    boxSizing: 'border-box', outline: 'none',
  },
  select: {
    width: '100%', background: '#313244', border: '1px solid #45475a',
    borderRadius: 6, padding: '8px 10px', color: '#cdd6f4', fontSize: 13,
    boxSizing: 'border-box', outline: 'none',
  },
  range: { width: '100%', marginTop: 4 },
  checkLabel: { display: 'flex', alignItems: 'center', gap: 8, color: '#cdd6f4', fontSize: 13, marginBottom: 8 },
  folderRow: { display: 'flex', gap: 8, alignItems: 'center' },
  browseBtn: {
    background: '#313244', border: '1px solid #45475a', color: '#cdd6f4',
    padding: '8px 12px', borderRadius: 6, cursor: 'pointer', fontSize: 13, flexShrink: 0,
  },
  backupActions: { display: 'flex', gap: 10, marginTop: 12, marginBottom: 8 },
  exportBtn: {
    background: '#89b4fa20', border: '1px solid #89b4fa60', color: '#89b4fa',
    padding: '8px 16px', borderRadius: 7, cursor: 'pointer', fontWeight: 600, fontSize: 13,
  },
  importBtn: {
    background: '#a6e3a120', border: '1px solid #a6e3a160', color: '#a6e3a1',
    padding: '8px 16px', borderRadius: 7, cursor: 'pointer', fontWeight: 600, fontSize: 13,
  },
  exportBtnDisabled: {
    background: '#313244', border: '1px solid #45475a', color: '#45475a',
    padding: '8px 16px', borderRadius: 7, cursor: 'not-allowed', fontWeight: 600, fontSize: 13,
  },
  backupSuccess: {
    background: '#a6e3a120', border: '1px solid #a6e3a140',
    borderRadius: 7, padding: '10px 14px', marginTop: 10, color: '#a6e3a1', fontSize: 13,
  },
  backupError: {
    background: '#f38ba820', border: '1px solid #f38ba840',
    borderRadius: 7, padding: '10px 14px', marginTop: 10, color: '#f38ba8', fontSize: 13,
  },
  code: {
    background: '#313244', borderRadius: 3, padding: '1px 5px',
    fontFamily: 'monospace', fontSize: 11, color: '#cdd6f4',
  },
  saveBtn: {
    background: '#cba6f7', border: 'none', color: '#1e1e2e',
    padding: '10px 24px', borderRadius: 8, cursor: 'pointer',
    fontWeight: 700, fontSize: 14, marginTop: 8,
  },
};
