export interface ICSAccountRecord {
  id: string;       // stable URL-based key
  url: string;      // ICS feed URL
  displayName: string;
}

export interface AccountsState {
  ics: ICSAccountRecord[];
}
