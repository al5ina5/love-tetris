-- src/ui/menu/main_menu.lua
-- Main menu screen

local MainMenu = {}

function MainMenu.draw(menu, sw, sh, game)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        -- Main menu - link style with subtitle
        local options = {
            "SINGLE PLAYER",
            "MULTIPLAYER",
            "STATS",
            "OPTIONS",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "SIRTET", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        -- Single player submenu - link style
        local options = {
            "SPRINT (40 LINES)",
            "MARATHON",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "SINGLE PLAYER", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        -- Multiplayer submenu - link style
        local options = {
            "LAN",
            "ONLINE",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "MULTIPLAYER", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        -- LAN submenu - link style
        local options = {
            "HOST",
            "BROWSE",
            "JOIN BY IP",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "LAN", nil, options)
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        -- Online submenu - link style
        local options = {
            "HOST",
            "JOIN WITH CODE",
            "BROWSE GAMES",
            "BACK",
        }
        Base.drawLinkMenu(menu, sw, sh, game, "ONLINE", nil, options)
    end
end

function MainMenu.handleKey(menu, key, game)
    local Base = require('src.ui.menu.base')
    
    local maxIndex = MainMenu.getMaxIndex(menu)
    
    if key == "up" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif key == "down" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        return MainMenu.select(menu, game)
    elseif key == "escape" or key == "z" then
        -- Back navigation
        if menu.state == Base.STATE.MAIN then
            return true -- No escape from main menu
        elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
            return true
        elseif menu.state == Base.STATE.SUBMENU_LAN or menu.state == Base.STATE.SUBMENU_ONLINE then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 1
            return true
        else
            -- Default back to main menu
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        end
    end
    return false
end

function MainMenu.handleGamepad(menu, button, game)
    local Base = require('src.ui.menu.base')
    local maxIndex = MainMenu.getMaxIndex(menu)
    
    if button == "dpup" then
        menu.selectedIndex = math.max(1, menu.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        menu.selectedIndex = math.min(maxIndex, menu.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
        return MainMenu.select(menu, game)
    elseif button == "b" or button == "back" then
        -- Back navigation
        if menu.state == Base.STATE.MAIN then
            return true -- No escape from main menu
        elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
            return true
        elseif menu.state == Base.STATE.SUBMENU_LAN or menu.state == Base.STATE.SUBMENU_ONLINE then
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 1
            return true
        else
            -- Default back to main menu
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
            return true
        end
    end
    return false
end

function MainMenu.getMaxIndex(menu)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        return 4  -- Single Player, Multiplayer, Stats, Options
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        return 3  -- Sprint, Marathon, Back
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        return 3  -- LAN, Online, Back
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        return 4  -- Host, Browse, Join IP, Back
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        return 4  -- Host, Join Code, Browse, Back
    end
    return 1
end

function MainMenu.select(menu, game)
    local Base = require('src.ui.menu.base')
    
    if menu.state == Base.STATE.MAIN then
        -- Main menu
        if menu.selectedIndex == 1 then
            -- Single Player
            menu.state = Base.STATE.SUBMENU_SINGLEPLAYER
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 2 then
            -- Multiplayer
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 3 then
            -- Stats
            menu.previousState = menu.state
            menu.state = Base.STATE.STATS
            menu.historyScrollIndex = 1
        elseif menu.selectedIndex == 4 then
            -- Options
            menu.previousState = menu.state
            menu.state = Base.STATE.OPTIONS
            menu.optionsSelectedIndex = 1
        end
    elseif menu.state == Base.STATE.SUBMENU_SINGLEPLAYER then
        -- Single player submenu
        if menu.selectedIndex == 1 then
            -- Sprint
            if game then game.gameMode = "SPRINT" end
            if menu.onStartAlone then menu.onStartAlone() end
        elseif menu.selectedIndex == 2 then
            -- Marathon
            if game then game.gameMode = "MARATHON" end
            if menu.onStartAlone then menu.onStartAlone() end
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 1
        end
    elseif menu.state == Base.STATE.SUBMENU_MULTIPLAYER then
        -- Multiplayer submenu
        if menu.selectedIndex == 1 then
            -- LAN
            menu.state = Base.STATE.SUBMENU_LAN
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 2 then
            -- Online
            menu.state = Base.STATE.SUBMENU_ONLINE
            menu.selectedIndex = 1
        elseif menu.selectedIndex == 3 then
            -- Back
            menu.state = Base.STATE.MAIN
            menu.selectedIndex = 2
        end
    elseif menu.state == Base.STATE.SUBMENU_LAN then
        -- LAN submenu
        if menu.selectedIndex == 1 then
            -- Host LAN Game
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.WAITING
            if menu.onHost then menu.onHost() end
        elseif menu.selectedIndex == 2 then
            -- Browse LAN Games
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.BROWSE
            menu.selectedIndex = 1
            menu.discovery:sendDiscoveryRequest()
        elseif menu.selectedIndex == 3 then
            -- Join by IP
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.IP_INPUT
            menu.selectedDigit = 1
        elseif menu.selectedIndex == 4 then
            -- Back
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 1
        end
    elseif menu.state == Base.STATE.SUBMENU_ONLINE then
        -- Online submenu
        if menu.selectedIndex == 1 then
            -- Host Online
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.ONLINE_HOST
            menu.selectedIndex = 1
            menu.isPublicRoom = true
        elseif menu.selectedIndex == 2 then
            -- Join with Code
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.ONLINE_JOIN
            menu.selectedIndex = 1
            menu.roomCode = ""
        elseif menu.selectedIndex == 3 then
            -- Browse Online Games
            if game then game.gameMode = "VERSUS" end
            menu.state = Base.STATE.ONLINE_BROWSE
            menu.selectedIndex = 1
            if menu.onRefreshOnlineRooms then menu.onRefreshOnlineRooms() end
        elseif menu.selectedIndex == 4 then
            -- Back
            menu.state = Base.STATE.SUBMENU_MULTIPLAYER
            menu.selectedIndex = 2
        end
    end
    return true
end

return MainMenu
