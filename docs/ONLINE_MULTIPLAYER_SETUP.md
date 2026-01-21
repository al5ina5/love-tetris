# Online Multiplayer Setup Guide

This guide will walk you through deploying the online multiplayer API and testing the game.

## Prerequisites

- An Ably account (free tier: https://ably.com/signup)
- Node.js 18+ installed
- Vercel CLI installed: `npm install -g vercel`
- Git repository initialized

## Step 1: Get Your Ably API Key

1. Go to [ably.com](https://ably.com) and sign up (free)
2. Create a new app in the Ably dashboard
3. Go to the **API Keys** tab
4. Copy your **Root API key** (format: `xxxx.xxxxxx:xxxxxxxxxxxxxxxxxx`)
5. Save this key - you'll need it in Step 4

## Step 2: Install API Dependencies

```bash
cd api/
npm install
```

This installs:
- `@vercel/kv` - Redis-like key-value storage
- `ably` - Ably SDK for token generation
- TypeScript and type definitions

## Step 3: Deploy to Vercel (First Time)

From the **project root** directory:

```bash
# Login to Vercel
vercel login

# Deploy and link to your git repo
vercel --prod
```

When prompted:
- **Set up and deploy?** Yes
- **Which scope?** Select your account
- **Link to existing project?** No
- **Project name?** `love-tetris-api` (or your choice)
- **Which directory is your code?** `./` (the root)
- **Want to override settings?** No

Vercel will:
- Deploy your API
- Link your git repo for auto-deploys
- Give you a production URL like: `https://love-tetris-api.vercel.app`

**Save this URL!** You'll need it in Step 6.

## Step 4: Add Ably API Key to Vercel

```bash
vercel env add ABLY_API_KEY production
```

When prompted, paste your Ably API key from Step 1.

## Step 5: Create Vercel KV Database

1. Go to [vercel.com/dashboard](https://vercel.com/dashboard)
2. Click on your project (`love-tetris-api`)
3. Go to the **Storage** tab
4. Click **Create Database** → Select **KV**
5. Name it: `tetris-rooms`
6. Click **Create & Continue**
7. **Connect to Project** → Select your project → Click **Connect**

This automatically adds the required environment variables (`KV_URL`, `KV_REST_API_URL`, etc.)

## Step 6: Redeploy with Environment Variables

```bash
vercel --prod
```

This redeploys with all environment variables properly configured.

## Step 7: Update Game Configuration

Edit `src/constants.lua` and update the API URL:

```lua
-- Change this line to your Vercel URL from Step 3
Constants.API_BASE_URL = "https://love-tetris-api.vercel.app"
```

**Important:** Use your actual Vercel URL, not the example above!

## Step 8: Test Locally

### Test the API

First, verify your API is working:

```bash
# Test create room
curl -X POST https://your-url.vercel.app/api/create-room \
  -H "Content-Type: application/json" \
  -d '{"isPublic":true}'

# Should return something like:
# {"roomCode":"ABC123","channelName":"tetris:room:ABC123","ablyToken":"..."}

# Test list rooms
curl https://your-url.vercel.app/api/list-rooms

# Should return:
# {"rooms":[{"roomCode":"ABC123","hostName":"Host","players":1,"maxPlayers":2}]}
```

### Test the Game

1. **Build the game:**
   ```bash
   love .
   ```

2. **Test online multiplayer:**
   - Start two instances of the game
   - Instance 1: Go to **MULTIPLAYER** → **ONLINE** → **HOST**
     - Select PUBLIC or PRIVATE
     - Click **CREATE ROOM**
     - Note the room code shown (6 characters)
   - Instance 2: Go to **MULTIPLAYER** → **ONLINE** → **JOIN WITH CODE**
     - Enter the room code from Instance 1
     - Click **JOIN ROOM**
   - Both players should connect and the game should start!

3. **Test room browser:**
   - Instance 1: Host a PUBLIC game
   - Instance 2: Go to **MULTIPLAYER** → **ONLINE** → **BROWSE GAMES**
     - You should see the hosted game in the list
     - Click on it to join

## Future Deployments

After the initial setup, deploying is automatic:

```bash
git add .
git commit -m "Your changes"
git push origin main
```

Vercel will automatically deploy when you push to your main branch!

## Troubleshooting

### "Failed to create room"

- Check that your Ably API key is correct: `vercel env ls`
- Verify the API is deployed: Visit `https://your-url.vercel.app/api/create-room` in browser
- Check Vercel logs: `vercel logs`

### "Room not found" when joining

- Make sure the host created the room successfully
- Room codes are case-insensitive but must be exact
- Rooms expire after 1 hour of inactivity

### "Connection timeout" / No messages received

- Verify the API URL in `src/constants.lua` is correct
- Check that you're using `https://` not `http://`
- Ensure both players are using the same API endpoint

### Vercel KV not working

- Make sure you created the KV database in Step 5
- Verify it's linked to your project
- Redeploy after linking: `vercel --prod`

## API Endpoints Reference

All endpoints are under `https://your-url.vercel.app/api/`

- **POST /create-room** - Create a new game room
  ```json
  Request: {"isPublic": true}
  Response: {"roomCode": "ABC123", "channelName": "...", "ablyToken": "..."}
  ```

- **POST /join-room** - Join an existing room
  ```json
  Request: {"roomCode": "ABC123"}
  Response: {"channelName": "...", "ablyToken": "...", "hostName": "Host"}
  ```

- **GET /list-rooms** - List public rooms
  ```json
  Response: {"rooms": [{"roomCode": "ABC123", "hostName": "Alice", "players": 1, "maxPlayers": 2}]}
  ```

- **POST /heartbeat** - Keep room alive (called automatically by host)
  ```json
  Request: {"roomCode": "ABC123"}
  Response: {"success": true}
  ```

## Architecture Overview

```
Love2D Game (Lua)
    ↓ HTTP
Vercel API (TypeScript)
    ↓ Generates secure tokens
Ably Real-time Service
    ↓ Pub/Sub messages
Both Players ↔ Game State Sync
```

- **Vercel API**: Manages rooms, generates Ably tokens
- **Ably**: Handles real-time message delivery between players
- **Vercel KV**: Stores room metadata (codes, player counts, etc.)

## Cost Estimate (Free Tiers)

- **Ably**: 3M messages/month → ~1000 games/month
- **Vercel**: 100GB bandwidth, 100K function calls/month
- **Vercel KV**: 30K requests/month

**Result:** Supports hundreds of concurrent users on free tier! 🎉

## Next Steps

- Share your game with friends and test online multiplayer!
- Monitor usage in Ably and Vercel dashboards
- If you exceed free tier limits, consider upgrading (very affordable)

## Support

If you run into issues:
1. Check Vercel logs: `vercel logs --follow`
2. Check browser console for errors (F12 in most browsers)
3. Verify API is responding: `curl https://your-url.vercel.app/api/list-rooms`
