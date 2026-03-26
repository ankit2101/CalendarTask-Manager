import { google, Auth } from 'googleapis';
import * as http from 'http';
import { shell } from 'electron';
import { tokenStore } from './token-store';
import { GoogleAccountRecord } from '../../../shared/types/account';

const SCOPES = ['https://www.googleapis.com/auth/calendar.readonly'];
const REDIRECT_PORT = 3478;
const REDIRECT_URI = `http://localhost:${REDIRECT_PORT}`;

interface GoogleCredentials {
  clientId: string;
  clientSecret: string;
}

interface StoredTokens {
  access_token?: string | null;
  refresh_token?: string | null;
  expiry_date?: number | null;
  token_type?: string | null;
}

export class GoogleAuthService {
  private clients: Map<string, Auth.OAuth2Client> = new Map();
  private credentials: GoogleCredentials | null = null;

  setCredentials(creds: GoogleCredentials): void {
    this.credentials = creds;
  }

  async restoreAccount(accountId: string): Promise<GoogleAccountRecord | null> {
    if (!this.credentials) return null;

    const tokens = await tokenStore.load<StoredTokens>('google', accountId);
    if (!tokens) return null;

    const client = new google.auth.OAuth2(
      this.credentials.clientId,
      this.credentials.clientSecret,
      REDIRECT_URI
    );
    client.setCredentials(tokens);
    this.clients.set(accountId, client);

    // Fetch display name from stored info
    const infoRaw = await tokenStore.load<{ email: string; displayName: string }>('google', `info:${accountId}`);
    if (!infoRaw) return null;

    return {
      id: accountId,
      email: infoRaw.email,
      displayName: infoRaw.displayName,
    };
  }

  async addAccount(): Promise<GoogleAccountRecord> {
    if (!this.credentials) {
      throw new Error('Google credentials not set. Configure clientId and clientSecret first.');
    }

    const client = new google.auth.OAuth2(
      this.credentials.clientId,
      this.credentials.clientSecret,
      REDIRECT_URI
    );

    const authUrl = client.generateAuthUrl({
      access_type: 'offline',
      scope: SCOPES,
      prompt: 'consent',
    });

    // Open browser and wait for redirect
    await shell.openExternal(authUrl);
    const code = await this.waitForAuthCode();

    const { tokens } = await client.getToken(code);
    client.setCredentials(tokens);

    // Get user info
    const oauth2 = google.oauth2({ version: 'v2', auth: client });
    const userInfo = await oauth2.userinfo.get();
    const email = userInfo.data.email!;
    const displayName = userInfo.data.name ?? email;

    // Store tokens and info
    await tokenStore.save('google', email, tokens as StoredTokens);
    await tokenStore.save('google', `info:${email}`, { email, displayName });

    this.clients.set(email, client);

    return { id: email, email, displayName };
  }

  async getClient(accountId: string): Promise<Auth.OAuth2Client> {
    const client = this.clients.get(accountId);
    if (!client) {
      throw new Error(`Google account ${accountId} not found`);
    }
    return client;
  }

  async removeAccount(accountId: string): Promise<void> {
    const client = this.clients.get(accountId);
    if (client) {
      try { await client.revokeCredentials(); } catch (_) { /* best effort */ }
      this.clients.delete(accountId);
    }
    await tokenStore.delete('google', accountId);
    await tokenStore.delete('google', `info:${accountId}`);
  }

  private waitForAuthCode(): Promise<string> {
    return new Promise((resolve, reject) => {
      const server = http.createServer((req, res) => {
        try {
          const url = new URL(req.url!, `http://localhost:${REDIRECT_PORT}`);
          const code = url.searchParams.get('code');
          const error = url.searchParams.get('error');

          res.writeHead(200, { 'Content-Type': 'text/html' });
          if (code) {
            res.end('<h1 style="font-family:sans-serif;text-align:center;margin-top:80px">Authentication successful!<br>You can close this window.</h1>');
            server.close();
            resolve(code);
          } else {
            res.end(`<h1 style="font-family:sans-serif;text-align:center;margin-top:80px;color:red">Authentication failed: ${error}<br>Please try again.</h1>`);
            server.close();
            reject(new Error(error ?? 'No auth code received'));
          }
        } catch (e) {
          res.end('Error');
          server.close();
          reject(e);
        }
      });

      server.listen(REDIRECT_PORT, '127.0.0.1', () => {
        console.log(`Waiting for Google OAuth callback on port ${REDIRECT_PORT}`);
      });

      server.on('error', reject);

      // Timeout after 5 minutes
      setTimeout(() => {
        server.close();
        reject(new Error('OAuth timeout - no response within 5 minutes'));
      }, 5 * 60 * 1000);
    });
  }
}

let instance: GoogleAuthService | null = null;

export function getGoogleAuth(): GoogleAuthService {
  if (!instance) instance = new GoogleAuthService();
  return instance;
}
