-- src/net/updater.lua
-- In-game updater that checks GitHub releases and can replace the .love file

local Constants = require("src.constants")
local SimpleHTTP = require("src.net.simple_http")

local Updater = {}

-- Cache for update state
Updater.state = {
    supported = nil,  -- nil = not checked, true/false after check
    sourcePath = nil,
    latestVersion = nil,
    downloadUrl = nil,
    releaseNotes = nil,
    checking = false,
    downloading = false,
    error = nil,
    downloadProgress = 0
}

-- Parse version string like "v1.2.3" or "1.2.3" into comparable numbers
local function parseVersion(versionStr)
    if not versionStr then return 0, 0, 0 end
    -- Remove leading 'v' if present
    local v = versionStr:gsub("^v", "")
    local major, minor, patch = v:match("^(%d+)%.(%d+)%.(%d+)")
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

-- Compare two version strings, returns true if v1 < v2
local function isNewerVersion(current, latest)
    local c1, c2, c3 = parseVersion(current)
    local l1, l2, l3 = parseVersion(latest)
    
    if l1 > c1 then return true end
    if l1 < c1 then return false end
    if l2 > c2 then return true end
    if l2 < c2 then return false end
    return l3 > c3
end

-- Check if the game can be updated (running from .love file in writable location)
function Updater.isSupported()
    -- Return cached result if already checked
    if Updater.state.supported ~= nil then
        return Updater.state.supported
    end
    
    -- Check if HTTP client is available
    local httpAvailable = SimpleHTTP.isAvailable()
    if not httpAvailable then
        Updater.state.supported = false
        Updater.state.error = "No HTTP client (curl/wget)"
        return false
    end
    
    -- Get the source path (where the .love file is)
    local source = love.filesystem.getSource()
    Updater.state.sourcePath = source
    
    -- Must be a .love file, not a directory (running from source)
    if not source:match("%.love$") then
        Updater.state.supported = false
        Updater.state.error = "Running from source directory"
        return false
    end
    
    -- Check if we can write to the .love file location
    -- Try opening for read+write to test permissions
    local testFile = io.open(source, "r+b")
    if testFile then
        testFile:close()
        Updater.state.supported = true
        return true
    else
        Updater.state.supported = false
        Updater.state.error = "Cannot write to game location"
        return false
    end
end

-- Fetch raw file content from GitHub (not JSON)
local function fetchRawFile(url)
    local available, tool = SimpleHTTP.isAvailable()
    if not available then
        return false, "No HTTP client available"
    end
    
    local tempFile = os.tmpname()
    local cmd
    if tool == "curl" then
        cmd = string.format("curl -L -s -o '%s' '%s' 2>/dev/null", tempFile, url)
    else
        cmd = string.format("wget -q -O '%s' '%s' 2>/dev/null", tempFile, url)
    end
    
    local result = os.execute(cmd)
    local success = (result == 0 or result == true)
    
    if not success then
        os.remove(tempFile)
        return false, "Download failed"
    end
    
    local f = io.open(tempFile, "r")
    if not f then
        os.remove(tempFile)
        return false, "Cannot read response"
    end
    
    local content = f:read("*all")
    f:close()
    os.remove(tempFile)
    
    return true, content
end

-- Check GitHub repo for a new version (reads constants.lua directly from main branch)
-- Returns: hasUpdate (bool), latestVersion (string or nil), error (string or nil)
function Updater.checkForUpdate()
    if Updater.state.checking then
        return false, nil, "Already checking"
    end
    
    Updater.state.checking = true
    Updater.state.error = nil
    
    -- Fetch constants.lua from main branch to get the latest version
    local rawUrl = "https://raw.githubusercontent.com/" .. Constants.GITHUB_REPO .. "/main/src/constants.lua"
    
    local success, content = fetchRawFile(rawUrl)
    Updater.state.checking = false
    
    if not success then
        Updater.state.error = "Failed to check: " .. tostring(content)
        return false, nil, Updater.state.error
    end
    
    -- Parse version from constants.lua content
    local version = content:match('VERSION%s*=%s*"([^"]+)"')
    if not version then
        Updater.state.error = "Could not parse version"
        return false, nil, Updater.state.error
    end
    
    Updater.state.latestVersion = version
    
    -- Set download URL to the .love file in dist/
    Updater.state.downloadUrl = "https://raw.githubusercontent.com/" .. Constants.GITHUB_REPO .. "/main/dist/Sirtet/Sirtet.love"
    
    -- Check if this is a newer version
    local hasUpdate = isNewerVersion(Constants.VERSION, version)
    
    return hasUpdate, version, nil
end

-- Download a file using curl/wget (for binary files, not JSON)
local function downloadFile(url, destPath)
    local available, tool = SimpleHTTP.isAvailable()
    if not available then
        return false, "No HTTP client available"
    end
    
    local cmd
    if tool == "curl" then
        -- -L follows redirects (important for GitHub release assets)
        cmd = string.format("curl -L -s -o '%s' '%s' 2>/dev/null", destPath, url)
    else
        cmd = string.format("wget -q -O '%s' '%s' 2>/dev/null", destPath, url)
    end
    
    local result = os.execute(cmd)
    local success = (result == 0 or result == true)
    
    if success then
        -- Verify the file was created and has content
        local f = io.open(destPath, "rb")
        if f then
            local size = f:seek("end")
            f:close()
            if size and size > 1000 then  -- .love files should be at least a few KB
                return true, nil
            else
                return false, "Downloaded file too small or empty"
            end
        end
    end
    
    return false, "Download failed"
end

-- Copy a file from src to dest using binary mode
local function copyFile(srcPath, destPath)
    local src = io.open(srcPath, "rb")
    if not src then
        return false, "Cannot open source file"
    end
    
    local content = src:read("*all")
    src:close()
    
    if not content or #content < 1000 then
        return false, "Source file is empty or too small"
    end
    
    local dest = io.open(destPath, "wb")
    if not dest then
        return false, "Cannot write to destination"
    end
    
    dest:write(content)
    dest:close()
    
    return true, nil
end

-- Download the update and install it
-- Returns: success (bool), error (string or nil)
function Updater.downloadAndInstall()
    if not Updater.state.supported then
        return false, "Updates not supported on this platform"
    end
    
    if not Updater.state.downloadUrl then
        return false, "No download URL available"
    end
    
    if Updater.state.downloading then
        return false, "Already downloading"
    end
    
    Updater.state.downloading = true
    Updater.state.error = nil
    Updater.state.downloadProgress = 0
    
    -- Download to save directory first (safe location)
    local saveDir = love.filesystem.getSaveDirectory()
    local tempPath = saveDir .. "/update_temp.love"
    
    Updater.state.downloadProgress = 10
    
    local success, err = downloadFile(Updater.state.downloadUrl, tempPath)
    if not success then
        Updater.state.downloading = false
        Updater.state.error = err
        -- Clean up temp file
        os.remove(tempPath)
        return false, err
    end
    
    Updater.state.downloadProgress = 80
    
    -- Copy the downloaded file over the original .love
    success, err = copyFile(tempPath, Updater.state.sourcePath)
    if not success then
        Updater.state.downloading = false
        Updater.state.error = err
        -- Clean up temp file
        os.remove(tempPath)
        return false, err
    end
    
    Updater.state.downloadProgress = 100
    
    -- Clean up temp file
    os.remove(tempPath)
    
    Updater.state.downloading = false
    return true, nil
end

-- Get current version
function Updater.getCurrentVersion()
    return Constants.VERSION
end

-- Get latest version (after checkForUpdate was called)
function Updater.getLatestVersion()
    return Updater.state.latestVersion
end

-- Get update status string for display
function Updater.getStatusText()
    if Updater.state.checking then
        return "Checking..."
    elseif Updater.state.downloading then
        return "Downloading... " .. Updater.state.downloadProgress .. "%"
    elseif Updater.state.error then
        return "Error: " .. Updater.state.error
    elseif Updater.state.latestVersion then
        if isNewerVersion(Constants.VERSION, Updater.state.latestVersion) then
            return "Update available: " .. Updater.state.latestVersion
        else
            return "Up to date (v" .. Constants.VERSION .. ")"
        end
    else
        return "v" .. Constants.VERSION
    end
end

-- Check if an update is available (after checkForUpdate was called)
function Updater.hasUpdate()
    if not Updater.state.latestVersion then
        return false
    end
    return isNewerVersion(Constants.VERSION, Updater.state.latestVersion)
end

-- Reset state (for retrying after error)
function Updater.reset()
    Updater.state.error = nil
    Updater.state.checking = false
    Updater.state.downloading = false
    Updater.state.downloadProgress = 0
end

return Updater
