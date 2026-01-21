-- src/ui/menu/online_screens.lua
-- Online multiplayer menu screens (host, join, browse)

local OnlineScreens = {}

-- Draw online host screen
function OnlineScreens.drawHost(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("HOST ONLINE", 0, 60, sw, "center", {1, 1, 1})
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        local y = 90
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 12
        end
        
        -- Only show back button when there's an error
        y = y + 10
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Public/Private toggle
    local y = 90
    local visibility = menu.isPublicRoom and "PUBLIC" or "PRIVATE"
    if menu.selectedIndex == 1 then
        game:drawText("> Visibility: " .. visibility, 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  Visibility: " .. visibility, 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Create button
    y = y + 20
    if menu.selectedIndex == 2 then
        game:drawText("> CREATE ROOM", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  CREATE ROOM", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 20
    if menu.selectedIndex == 3 then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
end

-- Draw online join screen
function OnlineScreens.drawJoin(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("JOIN ONLINE", 0, 60, sw, "center", {1, 1, 1})
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        local y = 90
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 12
        end
        
        -- Only show back button when there's an error
        y = y + 10
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Room code input
    local y = 90
    local codeText = menu.roomCode ~= "" and menu.roomCode or "______"
    if menu.selectedIndex == 1 then
        game:drawText("> Code: " .. codeText, 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  Code: " .. codeText, 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Join button
    y = y + 20
    if menu.selectedIndex == 2 then
        game:drawText("> JOIN ROOM", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  JOIN ROOM", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 20
    if menu.selectedIndex == 3 then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Instructions
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    if menu.selectedIndex == 1 and not menu.onlineError then
        game:drawText("Type the 6-character room code", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
    end
end

-- Draw online browse screen
function OnlineScreens.drawBrowse(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("BROWSE GAMES", 0, 30, sw, "center", {1, 1, 1})
    
    local y = 60
    
    -- Show error if any
    if menu.onlineError then
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        local errorLines = {}
        for line in menu.onlineError:gmatch("[^\n]+") do
            table.insert(errorLines, line)
        end
        for _, line in ipairs(errorLines) do
            game:drawText(line, 0, y, sw, "center", {1, 0.5, 0.5})
            y = y + 12
        end
        
        -- Show back button when there's an error
        y = y + 10
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
        
        if menu.fonts then love.graphics.setFont(menu.fonts.small) end
        game:drawText("See docs/HTTPS_SETUP.md for help", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
        return
    end
    
    -- Room list
    if #menu.onlineRooms == 0 then
        game:drawText("No public games found", 0, y + 20, sw, "center", {0.6, 0.6, 0.6})
    else
        for i, room in ipairs(menu.onlineRooms) do
            local roomText = string.format("Room %s (%d/%d)", 
                room.roomCode, room.players, room.maxPlayers)
            if menu.selectedIndex == i then
                game:drawText("> " .. roomText, 0, y, sw, "center", {1, 1, 0.5})
            else
                game:drawText("  " .. roomText, 0, y, sw, "center", {0.8, 0.8, 0.8})
            end
            y = y + 15
        end
    end
    
    -- Refresh button
    y = math.max(y, 100)
    local refreshIndex = #menu.onlineRooms + 1
    if menu.selectedIndex == refreshIndex then
        game:drawText("> REFRESH", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  REFRESH", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
    
    -- Back button
    y = y + 15
    local backIndex = #menu.onlineRooms + 2
    if menu.selectedIndex == backIndex then
        game:drawText("> BACK", 0, y, sw, "center", {1, 1, 0.5})
    else
        game:drawText("  BACK", 0, y, sw, "center", {0.8, 0.8, 0.8})
    end
end

-- Draw online waiting screen
function OnlineScreens.drawWaiting(menu, sw, sh, game)
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    game:drawText("WAITING FOR PLAYER", 0, 60, sw, "center", {1, 1, 1})
    
    -- Show room code
    if menu.onlineRoomCode then
        if menu.fonts then love.graphics.setFont(menu.fonts.large) end
        game:drawText("Room Code:", 0, 90, sw, "center", {0.8, 0.8, 0.8})
        game:drawText(menu.onlineRoomCode, 0, 110, sw, "center", {1, 1, 0.5})
    end
    
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    game:drawText("Share this code with your opponent", 0, 140, sw, "center", {0.6, 0.6, 0.6})
    game:drawText("Press ESC to cancel", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
end

-- Handle keyboard input for online host screen
function OnlineScreens.handleHostKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
            return true
        end
        return false
    end
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex == 1 then
            -- Toggle public/private
            menu.isPublicRoom = not menu.isPublicRoom
            return true
        elseif menu.selectedIndex == 2 then
            -- Create room
            if menu.onHostOnline then
                menu.onHostOnline(menu.isPublicRoom)
            end
            return true
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 1
        return true
    end
    return false
end

-- Handle keyboard input for online join screen
function OnlineScreens.handleJoinKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 2
            return true
        end
        return false
    end
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(3, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex == 1 then
            -- Text input - handled by textinput
            return true
        elseif menu.selectedIndex == 2 then
            -- Join room
            if menu.roomCode ~= "" then
                if menu.onJoinOnline then
                    menu.onJoinOnline(menu.roomCode:upper())
                end
            end
            return true
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 2
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 2
        return true
    end
    return false
end

-- Handle keyboard input for online browse screen
function OnlineScreens.handleBrowseKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    -- If there's an error, only allow going back
    if menu.onlineError then
        if key == "return" or key == "space" or key == "x" or key == "escape" or key == "z" then
            menu.onlineError = nil
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 3
            return true
        end
        return false
    end
    
    local maxIndex = #menu.onlineRooms + 2
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.selectedIndex >= 1 and menu.selectedIndex <= #menu.onlineRooms then
            -- Join selected room
            local roomIndex = menu.selectedIndex
            if menu.onlineRooms[roomIndex] then
                if menu.onJoinOnline then
                    menu.onJoinOnline(menu.onlineRooms[roomIndex].roomCode)
                end
            end
            return true
        elseif menu.selectedIndex == #menu.onlineRooms + 1 then
            -- Refresh
            if menu.onRefreshOnlineRooms then
                menu.onRefreshOnlineRooms()
            end
            return true
        elseif menu.selectedIndex == #menu.onlineRooms + 2 then
            -- Back
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 3
            return true
        end
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 3
        return true
    end
    return false
end

-- Handle text input for online screens
function OnlineScreens.handleTextInput(menu, text)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.ONLINE_JOIN then
        if menu.selectedIndex == 1 and #menu.roomCode < 6 then
            menu.roomCode = menu.roomCode .. text:upper()
            return true
        end
    end
    
    return false
end

-- Handle backspace for online screens
function OnlineScreens.handleBackspace(menu)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.ONLINE_JOIN then
        if menu.selectedIndex == 1 and #menu.roomCode > 0 then
            menu.roomCode = menu.roomCode:sub(1, -2)
            return true
        end
    end
    
    return false
end

return OnlineScreens
