-- src/ui/options.lua
-- Modular options screen for the menu system

local Updater = require("src.net.updater")

local Options = {}

-- Build the options items list dynamically (to include/exclude update option)
local function buildItems(menu)
    local items = {
        { name = "CONTROLS", type = "submenu", submenu = "controls" },
        { name = "SHADER", key = "shader", type = "select", options = {"OFF", "CRT", "GRAYSCALE", "DREAM", "GAMEBOY", "ANAGLYPH"} },
        { name = "GHOST PIECE", key = "ghost", type = "toggle" },
        { name = "MUSIC VOLUME", key = "musicVolume", type = "slider", min = 0, max = 10 },
        { name = "SFX VOLUME", key = "sfxVolume", type = "slider", min = 0, max = 10 },
        { name = "FULLSCREEN", key = "fullscreen", type = "toggle" },
    }
    
    -- Only add update option if supported on this platform
    if Updater.isSupported() then
        table.insert(items, { name = "CHECK FOR UPDATES", type = "action", action = "update" })
    end
    
    table.insert(items, { name = "BACK", type = "back" })
    
    return items
end

function Options.init(menu)
    menu.optionsSelectedIndex = 1
    menu.settings = {
        shader = _G.CRT_ENABLED and "CRT" or "OFF",
        ghost = true,
        musicVolume = 5,
        sfxVolume = 5,
        fullscreen = love.window.getFullscreen()
    }
    
    -- Build option items (includes update if supported)
    Options.ITEMS = buildItems(menu)
    
    -- Track update UI state
    menu.updateState = "idle"  -- idle, checking, ready, downloading, done, error
    menu.updateMessage = nil
end

function Options.draw(menu, sw, sh, game)
    game:drawText("OPTIONS", 0, 60, sw, "center", {1, 1, 1})
    
    local startY = 120
    local spacing = 36
    
    for i, item in ipairs(Options.ITEMS) do
        local y = startY + (i-1) * spacing
        local isSelected = (i == menu.optionsSelectedIndex)
        local color = isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
        local prefix = isSelected and "> " or "  "
        
        local text = prefix .. item.name
        game:drawText(text, 40, y, sw - 80, "left", color)
        
        if item.type == "toggle" then
            local valText = menu.settings[item.key] and "ON" or "OFF"
            game:drawText(valText, 40, y, sw - 120, "right", color)
        elseif item.type == "select" then
            local valText = menu.settings[item.key] or "OFF"
            game:drawText(valText, 40, y, sw - 120, "right", color)
        elseif item.type == "slider" then
            local val = menu.settings[item.key]
            local valText = string.rep("|", val) .. string.rep(".", item.max - val)
            game:drawText(valText .. " " .. val, 40, y, sw - 120, "right", color)
        elseif item.type == "submenu" then
            game:drawText(">>", 40, y, sw - 120, "right", color)
        elseif item.type == "action" and item.action == "update" then
            -- Show update status
            local statusText = Updater.getStatusText()
            local statusColor = color
            if Updater.hasUpdate() then
                statusColor = {0.5, 1, 0.5}  -- Green for update available
            end
            game:drawText(statusText, 40, y, sw - 120, "right", statusColor)
        end
    end
    
    -- Show update message if any
    if menu.updateMessage then
        local msgColor = {1, 1, 0.5}
        if menu.updateState == "error" then
            msgColor = {1, 0.5, 0.5}
        elseif menu.updateState == "done" then
            msgColor = {0.5, 1, 0.5}
        end
        game:drawText(menu.updateMessage, 0, sh - 60, sw, "center", msgColor)
    end
end

-- Handle the update action (check, download, install)
local function handleUpdateAction(menu)
    if Updater.state.downloading then
        -- Already downloading, ignore
        return true
    end
    
    if Updater.hasUpdate() and Updater.state.downloadUrl then
        -- Update is available, download and install it
        menu.updateState = "downloading"
        menu.updateMessage = "Downloading update..."
        
        local success, err = Updater.downloadAndInstall()
        if success then
            menu.updateState = "done"
            menu.updateMessage = "Update installed! Restart to apply."
        else
            menu.updateState = "error"
            menu.updateMessage = err or "Download failed"
        end
    else
        -- Check for updates
        menu.updateState = "checking"
        menu.updateMessage = "Checking for updates..."
        
        local hasUpdate, version, err = Updater.checkForUpdate()
        if err then
            menu.updateState = "error"
            menu.updateMessage = err
        elseif hasUpdate then
            menu.updateState = "ready"
            menu.updateMessage = "Update " .. version .. " available! Press again to install."
        else
            menu.updateState = "idle"
            menu.updateMessage = "You're up to date! (v" .. Updater.getCurrentVersion() .. ")"
        end
    end
    return true
end

function Options.handleKey(menu, key, onSettingChanged)
    if key == "up" then
        menu.optionsSelectedIndex = math.max(1, menu.optionsSelectedIndex - 1)
        return true
    elseif key == "down" then
        menu.optionsSelectedIndex = math.min(#Options.ITEMS, menu.optionsSelectedIndex + 1)
        return true
    elseif key == "left" or key == "right" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local step = (key == "right") and 1 or -1
            local nextIdx = idx + step
            if nextIdx > #item.options then nextIdx = 1 end
            if nextIdx < 1 then nextIdx = #item.options end
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "slider" then
            local step = (key == "right") and 1 or -1
            local newVal = math.max(item.min, math.min(item.max, menu.settings[item.key] + step))
            if newVal ~= menu.settings[item.key] then
                menu.settings[item.key] = newVal
                if onSettingChanged then onSettingChanged(item.key, newVal) end
            end
            return true
        end
    elseif key == "return" or key == "space" or key == "x" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local nextIdx = (idx % #item.options) + 1
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "submenu" then
            if item.submenu == "controls" then
                -- Don't overwrite previousState - Controls screen will return to OPTIONS
                menu.state = menu.STATE.CONTROLS
                local ControlsUI = require('src.ui.menu.controls_screen')
                ControlsUI.buildItems(menu)
            end
            return true
        elseif item.type == "action" and item.action == "update" then
            return handleUpdateAction(menu)
        elseif item.type == "back" then
            return Options.back(menu)
        end
    elseif key == "escape" or key == "z" then
        return Options.back(menu)
    end
    return false
end

function Options.handleGamepad(menu, button, onSettingChanged)
    if button == "dpup" then
        menu.optionsSelectedIndex = math.max(1, menu.optionsSelectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.optionsSelectedIndex = math.min(#Options.ITEMS, menu.optionsSelectedIndex + 1)
        return true
    elseif button == "dpleft" or button == "dpright" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local step = (button == "dpright") and 1 or -1
            local nextIdx = idx + step
            if nextIdx > #item.options then nextIdx = 1 end
            if nextIdx < 1 then nextIdx = #item.options end
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "slider" then
            local step = (button == "dpright") and 1 or -1
            local newVal = math.max(item.min, math.min(item.max, menu.settings[item.key] + step))
            if newVal ~= menu.settings[item.key] then
                menu.settings[item.key] = newVal
                if onSettingChanged then onSettingChanged(item.key, newVal) end
            end
            return true
        end
    elseif button == "a" or button == "start" then
        local item = Options.ITEMS[menu.optionsSelectedIndex]
        if item.type == "toggle" then
            menu.settings[item.key] = not menu.settings[item.key]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "select" then
            local current = menu.settings[item.key]
            local idx = 1
            for i, opt in ipairs(item.options) do
                if opt == current then idx = i; break end
            end
            local nextIdx = (idx % #item.options) + 1
            menu.settings[item.key] = item.options[nextIdx]
            if onSettingChanged then onSettingChanged(item.key, menu.settings[item.key]) end
            return true
        elseif item.type == "submenu" then
            if item.submenu == "controls" then
                -- Don't overwrite previousState - Controls screen will return to OPTIONS
                menu.state = menu.STATE.CONTROLS
                local ControlsUI = require('src.ui.menu.controls_screen')
                ControlsUI.buildItems(menu)
            end
            return true
        elseif item.type == "action" and item.action == "update" then
            return handleUpdateAction(menu)
        elseif item.type == "back" then
            return Options.back(menu)
        end
    elseif button == "b" or button == "back" then
        return Options.back(menu)
    end
    return false
end

function Options.back(menu)
    menu.state = menu.previousState or menu.STATE.MAIN
    -- Reset selection index to OPTIONS menu item position
    if menu.state == menu.STATE.MAIN then
        menu.selectedIndex = 4  -- OPTIONS is 4th item in main menu
    elseif menu.state == menu.STATE.PAUSE then
        menu.selectedIndex = 2  -- OPTIONS is 2nd item in pause menu
    else
        menu.selectedIndex = 1  -- Default
    end
    return true
end

return Options
