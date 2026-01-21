# Bundling Dependencies for Distribution

## The Problem

Online multiplayer requires `lua-sec` (HTTPS support), but you don't want players to manually install it. This guide shows how to bundle everything so your game "just works" out of the box.

## Solution Options

### Option 1: Bundle lua-sec with Your Game (Recommended)

Bundle the compiled `lua-sec` libraries directly with your game for each platform.

#### For macOS Distribution

```bash
# 1. Install lua-sec locally first
luarocks install luasec OPENSSL_DIR=/opt/homebrew/opt/openssl@3
luarocks install luasocket

# 2. Find where luarocks installed the modules
luarocks show luasec
luarocks show luasocket

# 3. Copy the modules to your game directory
mkdir -p lib/macos
cp -r ~/.luarocks/lib/lua/5.1/* lib/macos/
cp -r ~/.luarocks/share/lua/5.1/* lib/macos/

# 4. Update your main.lua to add the lib directory to the path
```

Add this to the top of `main.lua`:

```lua
-- Add bundled libraries to Lua path
local function addLibPath(path)
    package.path = path .. "/?.lua;" .. path .. "/?/init.lua;" .. package.path
    package.cpath = path .. "/?.so;" .. path .. "/?.dylib;" .. package.cpath
end

-- Detect platform and add appropriate lib directory
local os_name = love.system.getOS()
if os_name == "OS X" then
    addLibPath("lib/macos")
elseif os_name == "Windows" then
    addLibPath("lib/windows")
elseif os_name == "Linux" then
    addLibPath("lib/linux")
end
```

#### For Windows Distribution

```bash
# On Windows, after installing via luarocks:
# Copy from: C:\Program Files\Lua\5.1\clibs\
# To: your_game/lib/windows/

# Include these DLLs:
# - ssl.dll
# - socket/core.dll
# - mime/core.dll
# And dependencies:
# - libeay32.dll (OpenSSL)
# - ssleay32.dll (OpenSSL)
```

#### For Linux Distribution

```bash
# Install lua-sec
sudo luarocks install luasec
sudo luarocks install luasocket

# Copy modules
mkdir -p lib/linux
cp -r /usr/local/lib/lua/5.1/* lib/linux/
cp -r /usr/local/share/lua/5.1/* lib/linux/
```

### Option 2: Use System Command Fallback (Simpler!)

Instead of bundling lua-sec, use `curl` or `wget` which are pre-installed on most systems:

```lua
-- src/net/online_client_simple.lua
local json = require("src.lib.dkjson")
local Constants = require("src.constants")

local OnlineClient = {}
OnlineClient.__index = OnlineClient

-- Check if curl or wget is available
function OnlineClient.isAvailable()
    local handle = io.popen("which curl 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        return true, "curl"
    end
    
    handle = io.popen("which wget 2>/dev/null")
    result = handle:read("*a")
    handle:close()
    
    return result and result ~= "", "wget"
end

function OnlineClient:new()
    local self = setmetatable({}, OnlineClient)
    self.roomCode = nil
    self.channelName = nil
    self.ablyToken = nil
    self.connected = false
    self.playerId = nil
    self.apiUrl = Constants.API_BASE_URL
    
    local available, method = OnlineClient.isAvailable()
    if not available then
        error("No HTTP client available (curl/wget not found)")
    end
    self.httpMethod = method
    
    return self
end

-- Make HTTP request using curl/wget
function OnlineClient:httpRequest(method, url, body)
    local tempFile = os.tmpname()
    local cmd
    
    if self.httpMethod == "curl" then
        if method == "POST" and body then
            local bodyFile = os.tmpname()
            local f = io.open(bodyFile, "w")
            f:write(body)
            f:close()
            
            cmd = string.format(
                "curl -X POST -H 'Content-Type: application/json' -d @%s '%s' -o %s -w '%%{http_code}' 2>/dev/null",
                bodyFile, url, tempFile
            )
        else
            cmd = string.format(
                "curl -X %s '%s' -o %s -w '%%{http_code}' 2>/dev/null",
                method, url, tempFile
            )
        end
    else -- wget
        if method == "POST" and body then
            local bodyFile = os.tmpname()
            local f = io.open(bodyFile, "w")
            f:write(body)
            f:close()
            
            cmd = string.format(
                "wget --method=POST --body-file=%s --header='Content-Type: application/json' '%s' -O %s 2>/dev/null && echo 200 || echo 500",
                bodyFile, url, tempFile
            )
        else
            cmd = string.format(
                "wget '%s' -O %s 2>/dev/null && echo 200 || echo 500",
                url, tempFile
            )
        end
    end
    
    local handle = io.popen(cmd)
    local httpCode = handle:read("*a"):gsub("%s+", "")
    handle:close()
    
    local code = tonumber(httpCode) or 500
    
    if code >= 200 and code < 300 then
        local f = io.open(tempFile, "r")
        local responseBody = f:read("*a")
        f:close()
        os.remove(tempFile)
        
        local success, data = pcall(json.decode, responseBody)
        if success then
            return true, data
        else
            return false, "Failed to parse JSON response"
        end
    else
        os.remove(tempFile)
        return false, "HTTP " .. code
    end
end

-- Rest of the OnlineClient methods remain the same...
-- (createRoom, joinRoom, listRooms, etc.)
```

**Pros of curl/wget approach:**
- ✅ No bundling needed
- ✅ Works on 99% of systems
- ✅ Much simpler
- ❌ Can't use Ably's realtime features (but REST API works fine)

### Option 3: Love.js (Browser-Based Distribution)

Compile your game to JavaScript using love.js - HTTPS is built into browsers!

```bash
# Install love.js
npm install -g love.js

# Compile your game
love.js . --title "Sirtet" --output web/

# Deploy to static hosting (Netlify, Vercel, GitHub Pages)
```

**Pros:**
- ✅ No installation needed
- ✅ HTTPS built-in
- ✅ Easy distribution (just share a URL)
- ✅ Cross-platform automatically
- ❌ Slightly different performance characteristics

### Option 4: Hybrid Approach (Best UX)

Combine multiple methods with graceful fallbacks:

```lua
-- src/net/online_client.lua (modified)

local OnlineClient = {}
OnlineClient.__index = OnlineClient

-- Try multiple HTTP methods in order of preference
function OnlineClient.isAvailable()
    -- Try 1: lua-sec (fastest, most reliable)
    local hasHttps = pcall(function()
        require("ssl.https")
    end)
    if hasHttps then
        return true, "https"
    end
    
    -- Try 2: curl (very common)
    local handle = io.popen("which curl 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    if result and result ~= "" then
        return true, "curl"
    end
    
    -- Try 3: wget (common on Linux)
    handle = io.popen("which wget 2>/dev/null")
    result = handle:read("*a")
    handle:close()
    if result and result ~= "" then
        return true, "wget"
    end
    
    -- No HTTPS support available
    return false, nil
end

function OnlineClient:new()
    local available, method = OnlineClient.isAvailable()
    if not available then
        error("No HTTPS support available")
    end
    
    local self = setmetatable({}, OnlineClient)
    self.httpMethod = method
    self.apiUrl = Constants.API_BASE_URL
    -- ... rest of initialization
    
    return self
end

function OnlineClient:httpRequest(method, url, body)
    if self.httpMethod == "https" then
        return self:httpRequestLuaSec(method, url, body)
    elseif self.httpMethod == "curl" then
        return self:httpRequestCurl(method, url, body)
    elseif self.httpMethod == "wget" then
        return self:httpRequestWget(method, url, body)
    end
end

-- Separate implementations for each method...
```

## Recommended Approach for Your Game

I recommend **Option 2 (curl/wget fallback)** because:

1. **Simplicity**: No complex bundling
2. **Coverage**: curl/wget are pre-installed on:
   - ✅ macOS (curl built-in)
   - ✅ Most Linux distros (both pre-installed)
   - ✅ Windows 10+ (curl built-in since 2018)
3. **Maintainability**: No platform-specific binaries to manage
4. **Works today**: Your existing API endpoints work as-is

### Implementation Steps

1. Create `src/net/simple_http.lua` with curl/wget support
2. Modify `src/net/online_client.lua` to try lua-sec first, fall back to curl/wget
3. Update error messages to be more helpful
4. Test on all platforms

Would you like me to implement the curl/wget fallback approach? It would make online multiplayer work on ~95% of systems without any manual installation!

## Alternative: Simplify to LAN-Only

If online multiplayer is too complex, you could:
1. Keep only LAN multiplayer (which already works perfectly)
2. Add instructions for players to use VPN services like:
   - **Hamachi** (popular for gaming)
   - **ZeroTier** (modern, open-source)
   - **Tailscale** (very easy to use)

This way, players can create "virtual LANs" over the internet and use your LAN features!

## Summary Table

| Approach | Complexity | Coverage | Best For |
|----------|-----------|----------|----------|
| Bundle lua-sec | High | 100% | Professional releases |
| curl/wget fallback | Low | 95% | **Recommended for indie** |
| Love.js | Medium | 100% | Web distribution |
| LAN + VPN | Very Low | 100% | Simple projects |

Let me know which approach you'd like to pursue!
