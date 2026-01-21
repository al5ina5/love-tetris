// Ably token generation and management
import * as Ably from 'ably';

let ablyClient: Ably.Rest | null = null;

function getAblyClient(): Ably.Rest {
  if (!ablyClient) {
    const apiKey = process.env.ABLY_API_KEY;
    if (!apiKey) {
      throw new Error('ABLY_API_KEY environment variable is not set');
    }
    ablyClient = new Ably.Rest({ key: apiKey });
  }
  return ablyClient;
}

export async function generateAblyToken(
  channelName: string,
  clientId: string
): Promise<string> {
  const client = getAblyClient();
  
  const tokenParams: Ably.TokenParams = {
    clientId,
    capability: {
      [channelName]: ['publish', 'subscribe', 'presence'],
    },
    ttl: 3600000, // 1 hour
  };

  const tokenRequest = await client.auth.createTokenRequest(tokenParams);
  const tokenDetails = await client.auth.requestToken(tokenRequest);
  
  return tokenDetails.token;
}

export function generateChannelName(roomCode: string): string {
  return `tetris:room:${roomCode}`;
}
