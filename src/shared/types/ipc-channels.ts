export enum IpcChannel {
  // Calendar
  GET_EVENTS = 'calendar:get-events',
  REFRESH_EVENTS = 'calendar:refresh',

  // Accounts
  ADD_ICS_ACCOUNT = 'auth:add-ics',
  REMOVE_ACCOUNT = 'auth:remove',
  GET_ACCOUNTS = 'auth:get-accounts',

  // Meeting events (main -> renderer push)
  MEETING_ENDED = 'meeting:ended',
  MEETING_UPCOMING = 'meeting:upcoming',
  CALENDAR_SYNCED = 'calendar:synced',

  // Notes and AI
  SUBMIT_NOTE = 'note:submit',
  GET_MEETING_HISTORY = 'note:get-history',
  EXTRACT_ACTION_ITEMS = 'ai:extract',

  // Planner
  GET_PLANS = 'planner:get-plans',
  GET_BUCKETS = 'planner:get-buckets',
  CREATE_TASKS = 'planner:create-tasks',

  // Settings
  GET_SETTINGS = 'settings:get',
  SAVE_SETTINGS = 'settings:save',

  // To-do tasks
  GET_TODOS = 'todo:get',
  ADD_TODO = 'todo:add',
  UPDATE_TODO = 'todo:update',
  DELETE_TODO = 'todo:delete',

  // Data backup
  SELECT_FOLDER = 'data:select-folder',
  EXPORT_DATA = 'data:export',
  IMPORT_DATA = 'data:import',

  // System
  CHECK_ACCESSIBILITY = 'system:check-accessibility',
  REQUEST_ACCESSIBILITY = 'system:request-accessibility',
  SET_LAUNCH_AT_LOGIN = 'system:launch-at-login',
  OPEN_MAIN_WINDOW = 'system:open-main-window',
  OPEN_QUICK_NOTE = 'system:open-quick-note',
  DISMISS_MEETING = 'meeting:dismiss',
}
