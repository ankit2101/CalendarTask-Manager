export type TodoStatus = 'pending' | 'in-progress' | 'completed';

export interface TodoTask {
  id: string;
  title: string;
  description?: string;
  status: TodoStatus;
  /** Base priority set at creation time or manually. 1 (low) – 5 (critical). Default 3. */
  priority: number;
  /** When set, overrides auto-escalation and is treated as the definitive priority. */
  manualPriority?: number;
  /** Set when the task was auto-created from a meeting note. */
  source?: { meetingTitle: string; meetingDate: string };
  createdAt: string; // ISO
  updatedAt: string; // ISO
  completedAt?: string; // ISO
}

/** Returns the effective display priority, auto-escalating for tasks older than 2 days. */
export function effectivePriority(task: TodoTask): number {
  if (task.manualPriority !== undefined) return task.manualPriority;
  if (task.status === 'completed') return task.priority;
  const daysOld = (Date.now() - new Date(task.createdAt).getTime()) / 86400000;
  const escalation = Math.max(0, Math.floor(daysOld) - 2);
  return Math.min(5, task.priority + escalation);
}

export function isEscalated(task: TodoTask): boolean {
  if (task.manualPriority !== undefined) return false;
  if (task.status === 'completed') return false;
  const daysOld = (Date.now() - new Date(task.createdAt).getTime()) / 86400000;
  return daysOld > 2;
}

export const PRIORITY_LABEL: Record<number, string> = {
  1: 'Minimal',
  2: 'Low',
  3: 'Medium',
  4: 'High',
  5: 'Critical',
};

export const PRIORITY_COLOR: Record<number, string> = {
  1: '#6c7086',
  2: '#89b4fa',
  3: '#f9e2af',
  4: '#fab387',
  5: '#f38ba8',
};
