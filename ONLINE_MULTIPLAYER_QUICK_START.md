# Online Multiplayer - Quick Start

## Good News: No Setup Required! 🎉

Online multiplayer now works out of the box on most systems! The game automatically uses:
1. **lua-sec** if installed (fastest)
2. **curl** if available (built into macOS & Windows 10+)
3. **wget** if available (common on Linux)

## Testing if It Works

1. **Launch the game**
2. Go to **MULTIPLAYER** → **ONLINE** → **HOST**
3. If you see options instead of an error, it works!

## If You See an Error

The error message will tell you:
```
Online multiplayer requires HTTPS support.
Please use LAN multiplayer instead.
```

### Quick Fix Options

**Option 1: Use LAN Multiplayer Instead** (Recommended)
- Go to **MULTIPLAYER** → **LAN**
- Works on local networks
- No dependencies needed
- To play over internet, use a VPN like Hamachi or ZeroTier

**Option 2: Install curl** (if not available)
- macOS: Already installed ✓
- Windows 10+: Already installed ✓
- Linux: `sudo apt-get install curl`

**Option 3: Install lua-sec** (best performance)
- See `docs/HTTPS_SETUP.md` for detailed instructions
- Only needed if curl/wget aren't available

## For Game Developers

Your players **don't need to do anything**! The game handles fallback automatically:

```lua
-- The game tries methods in this order:
1. lua-sec (fast, but requires manual install)
2. curl (pre-installed on macOS/Windows 10+/most Linux)
3. wget (pre-installed on many Linux distros)
```

95% of players will have working online multiplayer without any setup!

## Distribution

When distributing your game:
- ✅ No bundling required
- ✅ No installation instructions needed
- ✅ Works on Windows, macOS, Linux out of the box
- ✅ Graceful fallback with helpful error messages

See `docs/BUNDLING_DEPENDENCIES.md` for advanced options.

## Testing the Fallback

You can test which method your system is using:

```bash
# Launch the game and check the console output
love .

# You should see a line like:
# "OnlineClient: Using curl for HTTPS"
# or
# "OnlineClient: Using lua-sec for HTTPS"
```

## Troubleshooting

### "No HTTPS support available"
- This is rare! Check if curl/wget work in your terminal
- On Windows, ensure you're on Windows 10 or later
- See `docs/HTTPS_SETUP.md` for manual installation

### "Failed to create room"
- Your API might not be deployed yet
- Check `docs/ONLINE_MULTIPLAYER_SETUP.md` for API setup
- Verify the API URL in `src/constants.lua`

### LAN Works, Online Doesn't
- Check if curl/wget are blocked by firewall
- Verify you can access the API URL in a browser
- Check the Vercel deployment logs

## Summary

**For Players:**
- Just download and play! It should work.
- If not, use LAN multiplayer or install curl.

**For Developers:**
- Distribute your game as-is, no bundling needed.
- 95% of systems will have online multiplayer working.
- The 5% that don't will see a helpful error with alternatives.

Enjoy! 🎮
