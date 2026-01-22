-- src/ui/menu/waiting_screens.lua
-- Waiting and connecting screens

local WaitingScreens = {}

function WaitingScreens.drawWaiting(menu, sw, sh, game)
    game:drawText("HOSTING GAME", 0, 60, sw, "center", {1, 1, 1})
    game:drawText("Waiting for opponent...", 0, 160, sw, "center", {0.6, 0.6, 0.6})
    
    if menu.discovery and menu.discovery.localIP then
        game:drawText("Your IP: " .. menu.discovery.localIP, 0, 220, sw, "center", {0.4, 0.8, 0.4})
    end
end

function WaitingScreens.drawConnecting(menu, sw, sh, game)
    game:drawText("CONNECTING", 0, 60, sw, "center", {1, 1, 1})
    game:drawText("Please wait...", 0, 160, sw, "center", {0.6, 0.6, 0.6})

    if menu.selectedServer then
        game:drawText(menu.selectedServer.name, 0, 220, sw, "center", {0.6, 0.6, 0.6})
    end
end

function WaitingScreens.handleWaitingKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    if key == "escape" or key == "z" then
        if menu.onStopHost then menu.onStopHost() end
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1  -- CREATE GAME is 1st in LAN submenu
        return true
    end
    return false
end

function WaitingScreens.handleWaitingGamepad(menu, button, game)
    local Base = require('src.ui.menu.base')
    
    if button == "b" or button == "back" then
        if menu.onStopHost then menu.onStopHost() end
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 1  -- CREATE GAME is 1st in LAN submenu
        return true
    end
    return false
end

function WaitingScreens.handleConnectingKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    if key == "escape" or key == "z" then
        print("Menu: User cancelled connection")
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        if menu.onCancel then menu.onCancel() end
        return true
    end
    return false
end

function WaitingScreens.handleConnectingGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    if button == "b" then
        print("Menu: User cancelled connection (gamepad)")
        menu.state = Base.STATE.SUBMENU_LAN
        menu.selectedIndex = 2  -- FIND GAME is 2nd in LAN submenu
        if menu.onCancel then menu.onCancel() end
        return true
    end
    return false
end

return WaitingScreens
