# HTTPS Support Setup for Online Multiplayer

## Good News: It Probably Already Works!

The game now has **automatic fallback** to use system tools (curl/wget) if lua-sec isn't installed. This means:

- ✅ **macOS**: Works out of the box (curl is built-in)
- ✅ **Windows 10+**: Works out of the box (curl is built-in)
- ✅ **Most Linux**: Works out of the box (curl/wget pre-installed)

**Just try it!** Online multiplayer should work without any setup on 95% of systems.

## If You Still See Errors

If you see: **"Online multiplayer not available (HTTPS support not found)"**

This means neither `lua-sec` nor `curl`/`wget` are available. Here's how to fix it:

## Solution: Choose One

### Easy Option: Verify curl/wget (Usually Already Installed)

Test if you have curl or wget:

```bash
# Test curl (most common)
curl --version

# Test wget (common on Linux)
wget --version
```

If either works, online multiplayer should work! If you still see errors, it might be a permissions issue.

### Advanced Option: Install lua-sec (Optional, for better performance)

### macOS (using Homebrew + LuaRocks)

```bash
# 1. Install OpenSSL (if not already installed)
brew install openssl

# 2. Install LuaRocks (Lua package manager)
brew install luarocks

# 3. Install lua-sec
luarocks install luasec

# 4. Install LuaSocket (if not already installed)
luarocks install luasocket
```

### Alternative: Install via LÖVE's Lua

If the above doesn't work with LÖVE's bundled Lua:

```bash
# Find LÖVE's Lua version
love --version

# Install lua-sec for the correct Lua version
# For Lua 5.1 (most common with LÖVE)
luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl@3
```

### Linux (Ubuntu/Debian)

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install lua-sec lua-socket

# Or via LuaRocks
sudo apt-get install luarocks
sudo luarocks install luasec
sudo luarocks install luasocket
```

### Windows

1. Download and install LuaRocks: https://luarocks.org/
2. Open Command Prompt as Administrator
3. Run:
   ```cmd
   luarocks install luasec
   luarocks install luasocket
   ```

## Verification

After installation, test if it works:

```bash
# Start LÖVE with your game
love .

# Try to access online multiplayer
# You should no longer see the HTTPS error
```

Or test in Lua directly:

```lua
lua -e "require('ssl.https'); print('HTTPS support available!')"
```

## Troubleshooting

### "module 'ssl.https' not found"

This means lua-sec is not installed in the right location for LÖVE to find it.

**Solution:** Make sure you're installing for the same Lua version that LÖVE uses:

```bash
# Check LÖVE's Lua version
love --version

# Install for that specific version
luarocks install luasec --lua-version=5.1
```

### macOS: "Cannot find OpenSSL"

```bash
# Reinstall OpenSSL and link it
brew reinstall openssl
brew link openssl --force

# Install lua-sec with explicit OpenSSL path
luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl@3
```

For Intel Macs, use:
```bash
luarocks install luasec OPENSSL_DIR=/usr/local/opt/openssl@3
```

### Still not working?

Try installing in LÖVE's Lua directory:

1. Find where LÖVE keeps its Lua files:
   ```bash
   # macOS
   ls /Applications/love.app/Contents/Resources/
   
   # Linux
   ls /usr/lib/love/
   ```

2. Copy installed modules to that location, or set `LUA_PATH` and `LUA_CPATH`:
   ```bash
   export LUA_PATH="$HOME/.luarocks/share/lua/5.1/?.lua;;"
   export LUA_CPATH="$HOME/.luarocks/lib/lua/5.1/?.so;;"
   ```

## Alternative: Use LAN Multiplayer

If you can't get HTTPS working or prefer a simpler setup:

1. Go to **MULTIPLAYER** → **LAN**
2. Use **HOST** and **BROWSE** for local network games
3. No external dependencies required!

## Why is HTTPS Required?

- The online API is hosted on Vercel (HTTPS only)
- Ably real-time service requires HTTPS
- LuaSocket's `http` module doesn't support HTTPS
- `lua-sec` adds SSL/TLS support to LuaSocket

## What Gets Installed?

- **luasec**: SSL/TLS support for Lua
- **luasocket**: Network communication (usually bundled with LÖVE)
- **OpenSSL**: Cryptography library (system dependency)

## Testing Your Setup

Once installed, create a test file:

```lua
-- test_https.lua
local https = require("ssl.https")
local body, code = https.request("https://httpbin.org/get")
if code == 200 then
    print("✓ HTTPS works!")
    print(body)
else
    print("✗ HTTPS failed with code:", code)
end
```

Run it:
```bash
lua test_https.lua
```

## For Developers

If distributing your game, consider:

1. **Bundle lua-sec** with your game distribution
2. **Include installation instructions** in your README
3. **Add a fallback** to LAN-only mode if HTTPS isn't available
4. **Use LuaJIT-compatible versions** of dependencies

## Summary

For most users on macOS:
```bash
brew install luarocks openssl
luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl@3
luarocks install luasocket
```

Then restart your game and online multiplayer should work! 🎮
