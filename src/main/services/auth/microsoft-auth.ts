import {
  PublicClientApplication,
  AccountInfo,
  InteractiveRequest,
  SilentFlowRequest,
  ICachePlugin,
  TokenCacheContext,
} from '@azure/msal-node';
import { shell } from 'electron';
import { tokenStore } from './token-store';

interface MicrosoftAccountRecord {
  id: string;
  email: string;
  displayName: string;
  tenantId: string;
}

export const MS_SCOPES = [
  'Calendars.Read',
  'Tasks.ReadWrite',
  'offline_access',
  'User.Read',
  'Tasks.ReadWrite.Shared',
];

const CACHE_KEY = 'msal-token-cache';

function buildCachePlugin(): ICachePlugin {
  return {
    async beforeCacheAccess(cacheContext: TokenCacheContext): Promise<void> {
      const data = await tokenStore.load<{ data: string }>('microsoft', CACHE_KEY);
      if (data?.data) {
        cacheContext.tokenCache.deserialize(data.data);
      }
    },
    async afterCacheAccess(cacheContext: TokenCacheContext): Promise<void> {
      if (cacheContext.cacheHasChanged) {
        const serialized = cacheContext.tokenCache.serialize();
        await tokenStore.save('microsoft', CACHE_KEY, { data: serialized });
      }
    },
  };
}

export class MicrosoftAuthService {
  private pca: PublicClientApplication;
  private clientId: string;

  constructor(clientId: string) {
    this.clientId = clientId;
    this.pca = new PublicClientApplication({
      auth: {
        clientId,
        authority: 'https://login.microsoftonline.com/common',
      },
      cache: {
        cachePlugin: buildCachePlugin(),
      },
    });
  }

  async addAccount(): Promise<MicrosoftAccountRecord> {
    const request: InteractiveRequest = {
      scopes: MS_SCOPES,
      openBrowser: async (url: string) => {
        await shell.openExternal(url);
      },
      successTemplate:
        '<h1 style="font-family:sans-serif;text-align:center;margin-top:80px">Authentication successful!<br>You can close this window.</h1>',
      errorTemplate:
        '<h1 style="font-family:sans-serif;text-align:center;margin-top:80px;color:red">Authentication failed: {error}<br>Please try again.</h1>',
    };

    const result = await this.pca.acquireTokenInteractive(request);
    const account = result.account!;

    return {
      id: account.homeAccountId,
      email: account.username,
      displayName: account.name ?? account.username,
      tenantId: account.tenantId,
    };
  }

  async getAccessToken(accountId: string): Promise<string> {
    const accounts = await this.pca.getTokenCache().getAllAccounts();
    const account = accounts.find(a => a.homeAccountId === accountId);

    if (!account) {
      throw new Error(`Microsoft account ${accountId} not found in cache`);
    }

    const request: SilentFlowRequest = {
      scopes: MS_SCOPES,
      account,
    };

    try {
      const result = await this.pca.acquireTokenSilent(request);
      return result.accessToken;
    } catch (e) {
      // If silent fails, trigger interactive
      const result = await this.pca.acquireTokenInteractive({
        scopes: MS_SCOPES,
        account,
        openBrowser: async (url: string) => {
          await shell.openExternal(url);
        },
      });
      return result.accessToken;
    }
  }

  async removeAccount(accountId: string): Promise<void> {
    const accounts = await this.pca.getTokenCache().getAllAccounts();
    const account = accounts.find(a => a.homeAccountId === accountId);
    if (account) {
      await this.pca.getTokenCache().removeAccount(account);
    }
  }

  getClientId(): string {
    return this.clientId;
  }
}

let instance: MicrosoftAuthService | null = null;

export function getMicrosoftAuth(): MicrosoftAuthService | null {
  return instance;
}

export function initMicrosoftAuth(clientId: string): MicrosoftAuthService {
  instance = new MicrosoftAuthService(clientId);
  return instance;
}
