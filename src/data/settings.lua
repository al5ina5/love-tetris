-- src/settings.lua
-- Persistent settings management for Blockdrop

local Settings = {}

Settings.FILE_NAME = "settings.txt"

-- Default settings
Settings.current = {
    lastIP = "010.000.000.197",
    shader = "CRT",
    ghost = true,
    musicVolume = 5,
    sfxVolume = 5,
    fullscreen = false,
    controls = nil -- Will be populated by Controls module
}

function Settings.load()
    if love.filesystem.getInfo(Settings.FILE_NAME) then
        local contents, size = love.filesystem.read(Settings.FILE_NAME)
        if contents then
            -- Try to parse as Lua table first (new format)
            local loadedSettings = Settings.parseNewFormat(contents)
            if loadedSettings then
                for k, v in pairs(loadedSettings) do
                    Settings.current[k] = v
                end
            else
                -- Fall back to old format
                for line in contents:gmatch("[^\r\n]+") do
                    local key, value = line:match("([^=]+)=([^=]+)")
                    if key and value then
                        if value == "true" then value = true
                        elseif value == "false" then value = false
                        elseif tonumber(value) then value = tonumber(value)
                        end
                        Settings.current[key] = value
                    end
                end
            end
        end
    end
    return Settings.current
end

function Settings.parseNewFormat(contents)
    -- Try to load settings as a Lua table
    local chunk, err = loadstring("return " .. contents)
    if chunk then
        local success, result = pcall(chunk)
        if success and type(result) == "table" then
            return result
        end
    end
    return nil
end

function Settings.save()
    -- Save as Lua table for complex data structures (like controls)
    local contents = Settings.tableToString(Settings.current, 0)
    love.filesystem.write(Settings.FILE_NAME, contents)
end

function Settings.tableToString(tbl, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)
    local result = "{\n"
    
    for k, v in pairs(tbl) do
        local key = type(k) == "string" and string.format('"%s"', k) or tostring(k)
        result = result .. spacing .. "  [" .. key .. "] = "
        
        if type(v) == "table" then
            result = result .. Settings.tableToString(v, indent + 1)
        elseif type(v) == "string" then
            result = result .. string.format('"%s"', v)
        elseif type(v) == "boolean" or type(v) == "number" then
            result = result .. tostring(v)
        else
            result = result .. '"' .. tostring(v) .. '"'
        end
        result = result .. ",\n"
    end
    
    result = result .. spacing .. "}"
    return result
end

function Settings.update(key, value)
    if Settings.current[key] ~= value then
        Settings.current[key] = value
        Settings.save()
    end
end

return Settings
