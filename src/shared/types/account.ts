export interface MicrosoftAccountRecord {
  id: string;       // MSAL homeAccountId
  email: string;
  displayName: string;
  tenantId: string;
}

export interface GoogleAccountRecord {
  id: string;       // email address used as key
  email: string;
  displayName: string;
}

export interface ICSAccountRecord {
  id: string;       // stable URL-based key
  url: string;      // ICS feed URL
  displayName: string;
}

export interface AccountsState {
  microsoft: MicrosoftAccountRecord[];
  google: GoogleAccountRecord[];
  ics: ICSAccountRecord[];
}
