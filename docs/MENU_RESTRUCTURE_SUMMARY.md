# Menu Restructure & Online Simplification Summary

This document summarizes the changes made to restructure the multiplayer menus and simplify the online multiplayer flow.

## Changes Made

### 1. Menu Restructure - Multilayer Navigation

**Old Structure:**
```
MULTIPLAYER
├── HOST ONLINE
├── JOIN WITH CODE
├── BROWSE GAMES
├── HOST LAN
├── FIND LAN GAME
├── JOIN BY IP
└── BACK
```

**New Structure:**
```
MULTIPLAYER
├── LAN
│   ├── HOST
│   ├── BROWSE
│   ├── JOIN BY IP
│   └── BACK
├── ONLINE
│   ├── HOST
│   ├── JOIN WITH CODE
│   ├── BROWSE GAMES
│   └── BACK
└── BACK
```

**Benefits:**
- Clearer separation between LAN and Online multiplayer
- Better organization and easier navigation
- More scalable for future additions

### 2. Removed Name Input from Online Multiplayer

**Old Flow - Host:**
1. Click "HOST ONLINE"
2. Enter player name
3. Choose PUBLIC/PRIVATE
4. Click "CREATE ROOM"
5. Wait for player

**New Flow - Host:**
1. Click "MULTIPLAYER" → "ONLINE" → "HOST"
2. Choose PUBLIC/PRIVATE
3. Click "CREATE ROOM"
4. Room code displayed (like LAN waiting page)
5. Wait for player

**Old Flow - Join:**
1. Click "JOIN WITH CODE"
2. Enter player name
3. Enter room code
4. Click "JOIN ROOM"

**New Flow - Join:**
1. Click "MULTIPLAYER" → "ONLINE" → "JOIN WITH CODE"
2. Enter room code
3. Click "JOIN ROOM"
4. Game starts immediately

**Benefits:**
- Simpler, faster flow - "just works"
- Consistent with LAN multiplayer experience
- Less friction for quick matches
- Fewer steps to get into a game

### 3. Updated API to Handle Missing Player Names

The API now uses default names if none are provided:
- **Host:** Defaults to "Host"
- **Guest:** Defaults to "Guest"

This change maintains backward compatibility while supporting the simplified flow.

## Files Modified

### Menu System
- `src/ui/menu/base.lua` - Added new submenu states (SUBMENU_LAN, SUBMENU_ONLINE)
- `src/ui/menu/main_menu.lua` - Restructured menu hierarchy and navigation
- `src/ui/menu/online_screens.lua` - Removed name input fields and simplified screens
- `src/ui/menu.lua` - Updated to handle new submenu states

### Game Logic
- `src/game/game.lua` - Updated callbacks to not require playerName
- `src/game/connection_manager.lua` - Updated functions to not require playerName
- `src/net/online_client.lua` - Updated API calls to omit playerName

### API
- `api/lib/types.ts` - Made playerName optional in request types
- `api/pages/api/create-room.ts` - Added default "Host" for missing playerName
- `api/pages/api/join-room.ts` - Added default "Guest" for missing playerName

### Configuration & Documentation
- `vercel.json` - Created deployment configuration for Vercel
- `DEPLOYMENT_FIX.md` - Created guide to fix Ably API key errors
- `docs/ONLINE_MULTIPLAYER_SETUP.md` - Updated to reflect new menu structure and simplified flow
- `docs/MENU_RESTRUCTURE_SUMMARY.md` - This document

## Deployment Notes

### Ably API Key Configuration

If you encounter the error: **"Environment Variable "ABLY_API_KEY" references Secret "ably_api_key", which does not exist"**

Follow these steps:

```bash
# Add the environment variable via Vercel CLI
vercel env add ABLY_API_KEY production

# When prompted, paste your Ably API key
# Format: xxxx.xxxxxx:xxxxxxxxxxxxxxxxxx

# Redeploy
vercel --prod
```

See `DEPLOYMENT_FIX.md` for more details.

## Testing the Changes

### Menu Navigation
1. Launch the game
2. Go to **MULTIPLAYER**
3. Verify you see **LAN** and **ONLINE** options
4. Navigate into each submenu and verify all options work
5. Test back navigation at each level

### Online Multiplayer - Host
1. Go to **MULTIPLAYER** → **ONLINE** → **HOST**
2. Toggle between PUBLIC and PRIVATE
3. Click **CREATE ROOM**
4. Verify room code is displayed
5. Wait for another player to join

### Online Multiplayer - Join
1. Go to **MULTIPLAYER** → **ONLINE** → **JOIN WITH CODE**
2. Enter a valid room code
3. Click **JOIN ROOM**
4. Verify game starts immediately

### Online Multiplayer - Browse
1. Go to **MULTIPLAYER** → **ONLINE** → **BROWSE GAMES**
2. Verify public rooms are listed
3. Click on a room to join
4. Verify game starts immediately

## Backward Compatibility

The API changes are backward compatible:
- Old clients that send `playerName` will still work
- New clients that omit `playerName` will use defaults
- No breaking changes to the API contract

## Future Improvements

Possible enhancements for the future:
- Add player customization (colors, avatars) separate from name input
- Add optional persistent username setting in Options menu
- Add "Quick Match" option that automatically finds/creates a game
- Add player statistics and ranking system
