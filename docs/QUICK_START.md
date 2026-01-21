# Quick Start - Online Multiplayer

## 5-Minute Setup

### 1. Get Ably API Key
- Go to [ably.com/signup](https://ably.com/signup)
- Create a new app
- Copy your API key from the **API Keys** tab

### 2. Deploy API
```bash
# Install dependencies
cd api && npm install && cd ..

# Deploy (you'll be prompted to login)
vercel --prod

# Add your Ably key
vercel env add ABLY_API_KEY production
# (paste your key when prompted)

# Redeploy with the key
vercel --prod
```

### 3. Create Vercel KV Database
1. Visit [vercel.com/dashboard](https://vercel.com/dashboard)
2. Click your project → **Storage** → **Create Database** → **KV**
3. Name it `tetris-rooms` → **Create** → **Connect to Project**

### 4. Update Game Config
```bash
# Vercel will show your URL after deployment, like:
# https://love-tetris-api-xyz.vercel.app

# Edit src/constants.lua and add this line:
Constants.API_BASE_URL = "https://your-actual-url.vercel.app"
```

### 5. Redeploy One More Time
```bash
vercel --prod
```

### 6. Test It!
```bash
# Run two instances of the game
love .  # Instance 1
love .  # Instance 2

# Instance 1: MULTIPLAYER → HOST ONLINE → Create Room
# Instance 2: MULTIPLAYER → JOIN WITH CODE → Enter the room code
```

Done! 🎮

For detailed troubleshooting, see [ONLINE_MULTIPLAYER_SETUP.md](ONLINE_MULTIPLAYER_SETUP.md)
