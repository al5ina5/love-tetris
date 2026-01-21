-- src/ui/menu/server_browser.lua
-- Server browser for finding LAN games

local ServerBrowser = {}

function ServerBrowser.draw(menu, sw, sh, game)
    game:drawText("FIND GAME", 0, 30, sw, "center", {1, 1, 1})
    
    local servers = menu.discovery:getServers()
    
    if #servers == 0 then
        game:drawText("Searching for games...", 0, 80, sw, "center", {0.6, 0.6, 0.6})
        game:drawText("Same WiFi required", 0, 100, sw, "center", {0.6, 0.6, 0.6})
    else
        local y = 60
        local spacing = 22
        for i, server in ipairs(servers) do
            local isSelected = (i == menu.selectedIndex)
            local color = isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
            local prefix = isSelected and "> " or "  "
            
            -- Server name and player count
            game:drawText(prefix .. server.name, 20, y, sw - 40, "left", color)
            game:drawText(server.players .. "/" .. server.maxPlayers, 20, y, sw - 60, "right", color)
            
            -- IP below (smaller, dimmer)
            love.graphics.setFont(game.renderer.fonts.small)
            game:drawText(server.ip, 35, y + 10, sw - 40, "left", {0.5, 0.5, 0.5})
            love.graphics.setFont(game.renderer.fonts.medium)
            
            y = y + spacing
            if y > sh - 40 then break end
        end
    end
end

function ServerBrowser.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    local servers = menu.discovery:getServers()
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(math.max(1, #servers), menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if #servers > 0 and menu.selectedIndex <= #servers then
            menu.selectedServer = servers[menu.selectedIndex]
            menu.state = Base.STATE.CONNECTING
            
            if menu.onJoin then
                menu.onJoin(menu.selectedServer.ip, menu.selectedServer.port)
            end
        end
        return true
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_MULTIPLAYER
        menu.selectedIndex = 2  -- FIND GAME is 2nd in multiplayer submenu
        return true
    elseif key == "r" then
        menu.discovery:sendDiscoveryRequest()
        return true
    end
    return false
end

function ServerBrowser.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    local servers = menu.discovery:getServers()
    
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(math.max(1, #servers), menu.selectedIndex + 1)
        return true
    elseif button == "a" then
        if #servers > 0 and menu.selectedIndex <= #servers then
            menu.selectedServer = servers[menu.selectedIndex]
            menu.state = Base.STATE.CONNECTING
            
            if menu.onJoin then
                menu.onJoin(menu.selectedServer.ip, menu.selectedServer.port)
            end
        end
        return true
    elseif button == "b" or button == "back" then
        menu.state = Base.STATE.SUBMENU_MULTIPLAYER
        menu.selectedIndex = 2  -- FIND GAME is 2nd in multiplayer submenu
        return true
    elseif button == "x" or button == "y" then
        menu.discovery:sendDiscoveryRequest()
        return true
    end
    return false
end

return ServerBrowser
