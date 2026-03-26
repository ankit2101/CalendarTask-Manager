import * as keytar from 'keytar';

const SERVICE_NAME = 'CalendarTaskManager';

export type TokenProvider = 'microsoft' | 'google' | 'system';

export const tokenStore = {
  async save(provider: TokenProvider, accountId: string, data: object): Promise<void> {
    await keytar.setPassword(SERVICE_NAME, `${provider}:${accountId}`, JSON.stringify(data));
  },

  async load<T = Record<string, unknown>>(provider: TokenProvider, accountId: string): Promise<T | null> {
    const raw = await keytar.getPassword(SERVICE_NAME, `${provider}:${accountId}`);
    return raw ? (JSON.parse(raw) as T) : null;
  },

  async delete(provider: TokenProvider, accountId: string): Promise<void> {
    await keytar.deletePassword(SERVICE_NAME, `${provider}:${accountId}`);
  },

  // Special key for API keys / single-value secrets
  async saveSecret(key: string, value: string): Promise<void> {
    await keytar.setPassword(SERVICE_NAME, `secret:${key}`, value);
  },

  async loadSecret(key: string): Promise<string | null> {
    return keytar.getPassword(SERVICE_NAME, `secret:${key}`);
  },

  async deleteSecret(key: string): Promise<void> {
    await keytar.deletePassword(SERVICE_NAME, `secret:${key}`);
  },
};
