export interface PlannerPlan {
  id: string;
  title: string;
  groupId: string;
  groupName?: string;
}

export interface PlannerBucket {
  id: string;
  name: string;
  planId: string;
  orderHint: string;
}

export interface PlannerTask {
  id: string;
  title: string;
  planId: string;
  bucketId: string;
  dueDateTime?: string;
  percentComplete: number;
  webUrl?: string;
}
