import React, { useEffect, useState, useCallback } from 'react';
import { TodoTask, TodoStatus, effectivePriority, isEscalated, PRIORITY_LABEL, PRIORITY_COLOR } from '../../shared/types/todo';

function newId(): string {
  return `todo-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

function now(): string {
  return new Date().toISOString();
}

const BUCKETS: { status: TodoStatus; label: string; icon: string }[] = [
  { status: 'pending',     label: 'Pending',     icon: '○' },
  { status: 'in-progress', label: 'In Progress',  icon: '◑' },
  { status: 'completed',   label: 'Completed',    icon: '●' },
];

const BUCKET_COLOR: Record<TodoStatus, string> = {
  'pending':     '#6c7086',
  'in-progress': '#89b4fa',
  'completed':   '#a6e3a1',
};

export default function Todos() {
  const [tasks, setTasks] = useState<TodoTask[]>([]);
  const [loading, setLoading] = useState(true);

  // Add-task form state (per bucket)
  const [addingIn, setAddingIn] = useState<TodoStatus | null>(null);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newPriority, setNewPriority] = useState(3);
  const [newDueDate, setNewDueDate] = useState('');

  // Editing state
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState('');
  const [editDesc, setEditDesc] = useState('');
  const [editPriority, setEditPriority] = useState<number | ''>('');
  const [editDueDate, setEditDueDate] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    const data = await window.api.getTodos();
    setTasks(data);
    setLoading(false);
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleAdd(status: TodoStatus) {
    if (!newTitle.trim()) return;
    const task: TodoTask = {
      id: newId(),
      title: newTitle.trim(),
      description: newDesc.trim() || undefined,
      status,
      priority: newPriority,
      dueDate: newDueDate || undefined,
      createdAt: now(),
      updatedAt: now(),
    };
    await window.api.addTodo(task);
    setTasks(t => [task, ...t]);
    setNewTitle('');
    setNewDesc('');
    setNewPriority(3);
    setNewDueDate('');
    setAddingIn(null);
  }

  async function handleMove(id: string, status: TodoStatus) {
    const updates: Partial<TodoTask> = { status };
    if (status === 'completed') updates.completedAt = now();
    await window.api.updateTodo(id, updates);
    setTasks(t => t.map(task => task.id === id ? { ...task, ...updates, updatedAt: now() } : task));
  }

  async function handleDelete(id: string) {
    await window.api.deleteTodo(id);
    setTasks(t => t.filter(task => task.id !== id));
  }

  function startEdit(task: TodoTask) {
    setEditingId(task.id);
    setEditTitle(task.title);
    setEditDesc(task.description ?? '');
    setEditPriority(task.manualPriority ?? task.priority);
    setEditDueDate(task.dueDate ?? '');
  }

  async function saveEdit(id: string) {
    const updates: Partial<TodoTask> = {
      title: editTitle.trim(),
      description: editDesc.trim() || undefined,
      manualPriority: editPriority === '' ? undefined : Number(editPriority),
      dueDate: editDueDate || undefined,
    };
    await window.api.updateTodo(id, updates);
    setTasks(t => t.map(task => task.id === id ? { ...task, ...updates, updatedAt: now() } : task));
    setEditingId(null);
  }

  async function setPriority(id: string, p: number) {
    await window.api.updateTodo(id, { manualPriority: p });
    setTasks(t => t.map(task => task.id === id ? { ...task, manualPriority: p, updatedAt: now() } : task));
  }

  if (loading) return <div style={styles.loading}>Loading…</div>;

  return (
    <div>
      <h1 style={styles.title}>To-Do</h1>

      <div style={styles.columns}>
        {BUCKETS.map(({ status, label, icon }) => {
          const bucketTasks = tasks
            .filter(t => t.status === status)
            .sort((a, b) => {
              // Sort by due date ascending; tasks without due date go last
              if (a.dueDate && b.dueDate) return a.dueDate.localeCompare(b.dueDate);
              if (a.dueDate) return -1;
              if (b.dueDate) return 1;
              // Fall back to priority (descending) for tasks without due date
              return effectivePriority(b) - effectivePriority(a);
            });

          return (
            <div key={status} style={styles.column}>
              {/* Column header */}
              <div style={styles.columnHeader}>
                <span style={{ color: BUCKET_COLOR[status], marginRight: 6 }}>{icon}</span>
                <span style={styles.columnLabel}>{label}</span>
                <span style={styles.columnCount}>{bucketTasks.length}</span>
              </div>

              {/* Task cards */}
              <div style={styles.cardList}>
                {bucketTasks.map(task => {
                  const prio = effectivePriority(task);
                  const escalated = isEscalated(task);
                  const isEditing = editingId === task.id;

                  return (
                    <div key={task.id} style={{
                      ...styles.card,
                      borderLeft: `3px solid ${PRIORITY_COLOR[prio]}`,
                    }}>
                      {isEditing ? (
                        /* Edit mode */
                        <div style={styles.editForm}>
                          <input
                            autoFocus
                            style={styles.editInput}
                            value={editTitle}
                            onChange={e => setEditTitle(e.target.value)}
                            onKeyDown={e => { if (e.key === 'Enter') saveEdit(task.id); if (e.key === 'Escape') setEditingId(null); }}
                          />
                          <input
                            style={styles.editInput}
                            placeholder="Description (optional)"
                            value={editDesc}
                            onChange={e => setEditDesc(e.target.value)}
                          />
                          <div style={styles.editRow}>
                            <label style={styles.editLabel}>Priority</label>
                            <select
                              style={styles.prioritySelect}
                              value={editPriority}
                              onChange={e => setEditPriority(Number(e.target.value))}
                            >
                              {[1,2,3,4,5].map(p => (
                                <option key={p} value={p}>{p} – {PRIORITY_LABEL[p]}</option>
                              ))}
                            </select>
                          </div>
                          <div style={styles.editRow}>
                            <label style={styles.editLabel}>Due date</label>
                            <input
                              type="date"
                              style={styles.dateInput}
                              value={editDueDate}
                              onChange={e => setEditDueDate(e.target.value)}
                            />
                          </div>
                          <div style={styles.editActions}>
                            <button style={styles.btnSave} onClick={() => saveEdit(task.id)}>Save</button>
                            <button style={styles.btnCancel} onClick={() => setEditingId(null)}>Cancel</button>
                          </div>
                        </div>
                      ) : (
                        /* View mode */
                        <>
                          <div style={styles.cardHeader}>
                            <span style={styles.cardTitle}>{task.title}</span>
                            <button style={styles.iconBtn} onClick={() => startEdit(task)} title="Edit">✎</button>
                            <button style={styles.iconBtn} onClick={() => handleDelete(task.id)} title="Delete">✕</button>
                          </div>

                          {task.description && (
                            <div style={styles.cardDesc}>{task.description}</div>
                          )}
                          {task.source && (
                            <div style={styles.sourceTag}>
                              📅 {task.source.meetingTitle} · {task.source.meetingDate}
                            </div>
                          )}

                          {task.dueDate && (
                            <div style={{
                              ...styles.dueDateTag,
                              color: task.dueDate < new Date().toISOString().slice(0, 10) && task.status !== 'completed'
                                ? '#f38ba8'
                                : '#a6adc8',
                            }}>
                              Due {task.dueDate}
                            </div>
                          )}

                          <div style={styles.cardFooter}>
                            {/* Priority selector */}
                            <select
                              style={{
                                ...styles.priorityBadge,
                                background: `${PRIORITY_COLOR[prio]}20`,
                                color: PRIORITY_COLOR[prio],
                                borderColor: `${PRIORITY_COLOR[prio]}40`,
                              }}
                              value={task.manualPriority ?? prio}
                              onChange={e => setPriority(task.id, Number(e.target.value))}
                              title="Set priority"
                            >
                              {[1,2,3,4,5].map(p => (
                                <option key={p} value={p}>{p} · {PRIORITY_LABEL[p]}</option>
                              ))}
                            </select>

                            {escalated && (
                              <span style={styles.escalatedBadge} title="Auto-escalated (2+ days old)">↑ escalated</span>
                            )}

                            {/* Move buttons */}
                            <div style={styles.moveButtons}>
                              {status !== 'pending' && (
                                <button style={styles.moveBtn} onClick={() => handleMove(task.id, 'pending')} title="Move to Pending">○</button>
                              )}
                              {status !== 'in-progress' && (
                                <button style={styles.moveBtn} onClick={() => handleMove(task.id, 'in-progress')} title="Move to In Progress">◑</button>
                              )}
                              {status !== 'completed' && (
                                <button style={styles.moveBtn} onClick={() => handleMove(task.id, 'completed')} title="Mark Complete">●</button>
                              )}
                            </div>
                          </div>
                        </>
                      )}
                    </div>
                  );
                })}

                {/* Add task form */}
                {addingIn === status ? (
                  <div style={styles.addForm}>
                    <input
                      autoFocus
                      style={styles.addInput}
                      placeholder="Task title…"
                      value={newTitle}
                      onChange={e => setNewTitle(e.target.value)}
                      onKeyDown={e => { if (e.key === 'Enter') handleAdd(status); if (e.key === 'Escape') setAddingIn(null); }}
                    />
                    <input
                      style={styles.addInput}
                      placeholder="Description (optional)"
                      value={newDesc}
                      onChange={e => setNewDesc(e.target.value)}
                    />
                    <div style={styles.addRow}>
                      <label style={styles.editLabel}>Priority</label>
                      <select
                        style={styles.prioritySelect}
                        value={newPriority}
                        onChange={e => setNewPriority(Number(e.target.value))}
                      >
                        {[1,2,3,4,5].map(p => (
                          <option key={p} value={p}>{p} – {PRIORITY_LABEL[p]}</option>
                        ))}
                      </select>
                    </div>
                    <div style={styles.addRow}>
                      <label style={styles.editLabel}>Due date</label>
                      <input
                        type="date"
                        style={styles.dateInput}
                        value={newDueDate}
                        onChange={e => setNewDueDate(e.target.value)}
                      />
                    </div>
                    <div style={styles.editActions}>
                      <button style={styles.btnSave} onClick={() => handleAdd(status)}>Add</button>
                      <button style={styles.btnCancel} onClick={() => setAddingIn(null)}>Cancel</button>
                    </div>
                  </div>
                ) : (
                  <button
                    style={styles.addBtn}
                    onClick={() => { setAddingIn(status); setNewTitle(''); setNewDesc(''); setNewPriority(3); setNewDueDate(''); }}
                  >
                    + Add task
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  loading: { color: '#6c7086', padding: 40, textAlign: 'center' },
  title: { margin: '0 0 20px', fontSize: 24, fontWeight: 700, color: '#cdd6f4' },
  columns: { display: 'flex', gap: 16, alignItems: 'flex-start' },
  column: { flex: 1, minWidth: 0 },
  columnHeader: {
    display: 'flex', alignItems: 'center', marginBottom: 10,
    paddingBottom: 8, borderBottom: '1px solid #313244',
  },
  columnLabel: { fontWeight: 700, fontSize: 13, color: '#cdd6f4', flex: 1 },
  columnCount: {
    background: '#313244', color: '#6c7086', fontSize: 11,
    padding: '1px 6px', borderRadius: 10, fontWeight: 600,
  },
  cardList: { display: 'flex', flexDirection: 'column', gap: 8 },
  card: {
    background: '#313244', borderRadius: 8, padding: '10px 12px',
    borderLeft: '3px solid #cdd6f4',
  },
  cardHeader: { display: 'flex', alignItems: 'flex-start', gap: 4, marginBottom: 4 },
  cardTitle: { flex: 1, fontWeight: 600, color: '#cdd6f4', fontSize: 13, lineHeight: 1.4 },
  cardDesc: { color: '#a6adc8', fontSize: 12, marginBottom: 4, lineHeight: 1.4 },
  sourceTag: {
    display: 'inline-block', marginBottom: 6,
    background: '#cba6f720', color: '#cba6f7',
    fontSize: 10, padding: '2px 7px', borderRadius: 4,
    fontWeight: 600, letterSpacing: '0.02em',
  },
  cardFooter: { display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' as const },
  priorityBadge: {
    border: '1px solid', borderRadius: 4, fontSize: 11, fontWeight: 600,
    padding: '2px 6px', cursor: 'pointer', outline: 'none',
  },
  escalatedBadge: {
    color: '#fab387', fontSize: 10, fontWeight: 700,
    textTransform: 'uppercase' as const, letterSpacing: '0.04em',
  },
  moveButtons: { marginLeft: 'auto', display: 'flex', gap: 4 },
  moveBtn: {
    background: 'none', border: 'none', color: '#6c7086',
    cursor: 'pointer', fontSize: 14, padding: '2px 4px',
    transition: 'color 0.1s',
  },
  iconBtn: {
    background: 'none', border: 'none', color: '#6c7086',
    cursor: 'pointer', fontSize: 12, padding: '2px 4px', flexShrink: 0,
  },
  addBtn: {
    width: '100%', background: 'none',
    border: '1px dashed #45475a', borderRadius: 8,
    color: '#6c7086', padding: '8px', cursor: 'pointer', fontSize: 12,
    textAlign: 'center' as const,
  },
  addForm: {
    background: '#1e1e2e', borderRadius: 8, padding: '10px 12px',
    border: '1px solid #45475a', display: 'flex', flexDirection: 'column', gap: 6,
  },
  addInput: {
    background: '#313244', border: '1px solid #45475a', borderRadius: 6,
    padding: '6px 8px', color: '#cdd6f4', fontSize: 13, outline: 'none',
  },
  addRow: { display: 'flex', alignItems: 'center', gap: 8 },
  editForm: { display: 'flex', flexDirection: 'column', gap: 6 },
  editInput: {
    background: '#1e1e2e', border: '1px solid #45475a', borderRadius: 6,
    padding: '6px 8px', color: '#cdd6f4', fontSize: 13, outline: 'none',
  },
  editRow: { display: 'flex', alignItems: 'center', gap: 8 },
  editLabel: { color: '#6c7086', fontSize: 12, flexShrink: 0 },
  prioritySelect: {
    background: '#313244', border: '1px solid #45475a', borderRadius: 6,
    padding: '4px 6px', color: '#cdd6f4', fontSize: 12, outline: 'none', flex: 1,
  },
  editActions: { display: 'flex', gap: 6, justifyContent: 'flex-end' },
  dueDateTag: { fontSize: 11, marginBottom: 4 },
  dateInput: {
    background: '#313244', border: '1px solid #45475a', borderRadius: 6,
    padding: '4px 6px', color: '#cdd6f4', fontSize: 12, outline: 'none', flex: 1,
    colorScheme: 'dark' as const,
  },
  btnSave: {
    background: '#cba6f7', border: 'none', color: '#1e1e2e',
    padding: '5px 12px', borderRadius: 6, cursor: 'pointer', fontWeight: 700, fontSize: 12,
  },
  btnCancel: {
    background: '#313244', border: '1px solid #45475a', color: '#a6adc8',
    padding: '5px 10px', borderRadius: 6, cursor: 'pointer', fontSize: 12,
  },
};
