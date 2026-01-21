# Fixing the Ably API Key Error

If you're seeing the error: **"Environment Variable "ABLY_API_KEY" references Secret "ably_api_key", which does not exist"**, follow these steps:

## Quick Fix

The issue is that the Ably API key environment variable needs to be configured in Vercel. Here's how to fix it:

### Option 1: Add via Vercel CLI (Recommended)

```bash
# Make sure you're in the project root
cd /path/to/love-tetris

# Add the environment variable as a secret
vercel env add ABLY_API_KEY production

# When prompted, paste your Ably API key
# Format: xxxx.xxxxxx:xxxxxxxxxxxxxxxxxx
```

Then redeploy:

```bash
vercel --prod
```

### Option 2: Add via Vercel Dashboard

1. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Click **Add New**
5. Name: `ABLY_API_KEY`
6. Value: Your Ably API key (format: `xxxx.xxxxxx:xxxxxxxxxxxxxxxxxx`)
7. Environment: Select **Production** (and optionally Preview/Development)
8. Click **Save**
9. Redeploy your project

## Getting Your Ably API Key

If you don't have an Ably API key yet:

1. Go to [ably.com/signup](https://ably.com/signup) (free tier available)
2. Create a new app in the Ably dashboard
3. Go to the **API Keys** tab
4. Copy your **Root API key**
5. Use this key in the steps above

## Verifying the Fix

After adding the environment variable and redeploying, test that it works:

```bash
curl -X POST https://your-deployment-url.vercel.app/api/create-room \
  -H "Content-Type: application/json" \
  -d '{"isPublic":true}'
```

You should get a response like:

```json
{
  "roomCode": "ABC123",
  "channelName": "tetris:room:ABC123",
  "ablyToken": "..."
}
```

## Why This Happened

The `vercel.json` file references the environment variable as a "secret" using the `@ably_api_key` syntax. Vercel secrets must be added explicitly via the CLI or dashboard - they're not automatically created from `.env` files.

## Full Setup Guide

For complete deployment instructions, see: [docs/ONLINE_MULTIPLAYER_SETUP.md](docs/ONLINE_MULTIPLAYER_SETUP.md)
