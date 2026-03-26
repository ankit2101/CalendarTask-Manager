import { PlannerPlan, PlannerBucket, PlannerTask } from '../../../shared/types/planner';
import { ActionItem } from '../../../shared/types/calendar';
import { getMicrosoftAuth } from '../auth/microsoft-auth';

const GRAPH_BASE = 'https://graph.microsoft.com/v1.0';

async function graphGet<T>(path: string, token: string): Promise<T> {
  const res = await fetch(`${GRAPH_BASE}${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Graph API error ${res.status}: ${text}`);
  }
  return res.json();
}

async function graphPost<T>(path: string, token: string, body: object): Promise<T> {
  const res = await fetch(`${GRAPH_BASE}${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Graph API error ${res.status}: ${text}`);
  }
  return res.json();
}

export async function getPlansForAccount(accountId: string): Promise<PlannerPlan[]> {
  const auth = getMicrosoftAuth();
  if (!auth) throw new Error('Microsoft auth not initialized');
  const token = await auth.getAccessToken(accountId);

  // Get joined groups/teams
  const groupsData = await graphGet<{ value: Array<{ id: string; displayName: string }> }>(
    '/me/joinedTeams',
    token
  );

  const plans: PlannerPlan[] = [];

  await Promise.all(
    groupsData.value.map(async group => {
      try {
        const plansData = await graphGet<{ value: Array<{ id: string; title: string }> }>(
          `/groups/${group.id}/planner/plans`,
          token
        );
        for (const plan of plansData.value) {
          plans.push({
            id: plan.id,
            title: plan.title,
            groupId: group.id,
            groupName: group.displayName,
          });
        }
      } catch (_) {
        // Some groups may not have Planner — ignore
      }
    })
  );

  return plans;
}

export async function getBuckets(planId: string, accountId: string): Promise<PlannerBucket[]> {
  const auth = getMicrosoftAuth();
  if (!auth) throw new Error('Microsoft auth not initialized');
  const token = await auth.getAccessToken(accountId);

  const data = await graphGet<{ value: PlannerBucket[] }>(
    `/planner/plans/${planId}/buckets`,
    token
  );
  return data.value;
}

export async function createPlannerTask(
  actionItem: ActionItem,
  planId: string,
  bucketId: string,
  accountId: string,
  meetingTitle: string
): Promise<PlannerTask> {
  const auth = getMicrosoftAuth();
  if (!auth) throw new Error('Microsoft auth not initialized');
  const token = await auth.getAccessToken(accountId);

  const body: Record<string, unknown> = {
    planId,
    bucketId,
    title: actionItem.title,
  };

  if (actionItem.dueDate) {
    body.dueDateTime = new Date(actionItem.dueDate + 'T23:59:59Z').toISOString();
  }

  // Set priority: 0=urgent, 2=important, 5=medium(normal), 9=low
  const priorityMap: Record<ActionItem['priority'], number> = {
    urgent: 0,
    important: 2,
    normal: 5,
  };
  body.priority = priorityMap[actionItem.priority];

  const task = await graphPost<PlannerTask>('/planner/tasks', token, body);

  // Add description via task details (separate PATCH call)
  if (actionItem.description || meetingTitle) {
    try {
      // First get the ETag for the task details
      const detailsRes = await fetch(`${GRAPH_BASE}/planner/tasks/${task.id}/details`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (detailsRes.ok) {
        const etag = detailsRes.headers.get('ETag');
        const description = [
          actionItem.description ?? '',
          `\n\nFrom meeting: ${meetingTitle}`,
        ]
          .join('')
          .trim();

        await fetch(`${GRAPH_BASE}/planner/tasks/${task.id}/details`, {
          method: 'PATCH',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
            'If-Match': etag ?? '*',
          },
          body: JSON.stringify({ description }),
        });
      }
    } catch (e) {
      console.warn('Failed to add task description:', e);
    }
  }

  return task;
}
