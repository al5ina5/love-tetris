-- src/ui/menu/base.lua
-- Base menu system with shared state and helpers

local Background = require('src.ui.menu.background')

local Base = {}

Base.STATE = {
    MAIN = "main",
    SUBMENU_SINGLEPLAYER = "submenu_singleplayer",
    SUBMENU_MULTIPLAYER = "submenu_multiplayer",
    SUBMENU_LAN = "submenu_lan",
    SUBMENU_ONLINE = "submenu_online",
    HOST = "host",
    BROWSE = "browse",
    CONNECTING = "connecting",
    WAITING = "waiting",
    IP_INPUT = "ip_input",
    OPTIONS = "options",
    PAUSE = "pause",
    STATS = "stats",
    CONTROLS = "controls",
    -- Online multiplayer states
    ONLINE_HOST = "online_host",
    ONLINE_JOIN = "online_join",
    ONLINE_BROWSE = "online_browse",
    ONLINE_WAITING = "online_waiting",
}

function Base.create(discovery, fonts)
    local menu = {
        state = nil,  -- Hidden by default
        previousState = nil,
        discovery = discovery,
        fonts = fonts,
        
        selectedServer = nil,
        selectedIndex = 1,
        serverName = "Player's Game",
        scanTimer = 0,
        
        inputCooldown = 0,
        COOLDOWN_TIME = 0.15,
        
        -- IP Input state
        ipDigits = {1,9,2,  1,6,8,  0,0,1,  0,0,1},
        selectedDigit = 1,
        
        -- Online multiplayer state
        playerName = "",
        roomCode = "",
        isPublicRoom = true,
        onlineRooms = {},
        onlineError = nil,
        
        -- Background
        fallingBlocks = Background.init(),
        
        -- Callbacks (set by game)
        onHost = nil,
        onStopHost = nil,
        onStartAlone = nil,
        onJoin = nil,
        onCancel = nil,
        onMainMenu = nil,
        onSettingChanged = nil,
        onControlsChanged = nil,
        onHostOnline = nil,
        onJoinOnline = nil,
        onRefreshOnlineRooms = nil,
        
        -- Settings
        settings = {}
    }
    
    return menu
end

function Base.show(menu, state)
    state = state or Base.STATE.MAIN
    print("Menu: Showing menu, state: " .. tostring(state))
    menu.state = state
    menu.selectedIndex = 1
    menu.scanTimer = 0
    menu.inputCooldown = 0.2

    if state == Base.STATE.BROWSE then
        menu.discovery:startListening()
        menu.discovery:sendDiscoveryRequest()
    elseif state == Base.STATE.MAIN then
        menu.discovery:startListening()
    end
end

function Base.hide(menu)
    print("Menu: Hiding menu (was in state: " .. tostring(menu.state) .. ")")
    menu.state = nil
end

function Base.isVisible(menu)
    return menu.state ~= nil
end

function Base.update(menu, dt)
    if not Base.isVisible(menu) then return end
    
    -- Update falling blocks
    Background.update(menu.fallingBlocks, dt)

    -- Update input cooldown
    if menu.inputCooldown > 0 then
        menu.inputCooldown = menu.inputCooldown - dt
    end
    
    -- Periodically rescan for servers when browsing
    if menu.state == Base.STATE.BROWSE then
        menu.scanTimer = menu.scanTimer + dt
        if menu.scanTimer >= 2.0 then
            menu.scanTimer = 0
            menu.discovery:sendDiscoveryRequest()
        end
    end
end

function Base.drawBackground(menu, game)
    if not Base.isVisible(menu) then return end
    Background.draw(menu.fallingBlocks)
end

-- Draw a link-style menu (centered, navigation-focused)
-- Used for main menu, submenus, pause menu, etc.
function Base.drawLinkMenu(menu, sw, sh, game, title, subtitle, options)
    -- Title
    if title then
        if title == "SIRTET" then
            -- Main menu title - large font
            if menu.fonts then love.graphics.setFont(menu.fonts.large) end
            game:drawText(title, 0, sh/2 - 65, sw, "center", {1, 1, 1}, {0.3, 0.3, 0.3})
        else
            -- Submenu titles - medium font
            if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
            game:drawText(title, 0, sh/2 - 65, sw, "center", {1, 1, 1})
        end
    end

    -- Subtitle (for main menu)
    if subtitle then
        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        game:drawText(subtitle, 0, sh/2 - 30, sw, "center", {0.7, 0.7, 0.7})
    end

    -- Menu options - centered
    if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
    local y = sh/2 - 10
    local spacing = 15
    
    for i, option in ipairs(options) do
        local color = {0.8, 0.8, 0.8}
        local text = "  " .. option
        if i == menu.selectedIndex then
            color = {1, 1, 0.5}
            text = "> " .. option
        end
        
        game:drawText(text, 0, y, sw, "center", color)
        y = y + spacing
    end
end

-- Legacy function for backwards compatibility
-- Automatically detects which style to use based on title
function Base.drawList(menu, sw, sh, game, title, subtitle, options, startY)
    -- For navigation menus (main, submenus), use link style
    if title == "SIRTET" or subtitle or not startY then
        Base.drawLinkMenu(menu, sw, sh, game, title, subtitle, options)
    else
        -- Content-heavy style (left-aligned, for options screens)
        if title then
            if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
            game:drawText(title, 0, 30, sw, "center", {1, 1, 1})
        end

        if menu.fonts then love.graphics.setFont(menu.fonts.medium) end
        local y = startY or 60
        local spacing = 18
        
        for i, option in ipairs(options) do
            local color = {0.8, 0.8, 0.8}
            local text = "  " .. option
            if i == menu.selectedIndex then
                color = {1, 1, 0.5}
                text = "> " .. option
            end
            
            game:drawText(text, 20, y, sw - 40, "left", color)
            y = y + spacing
        end
    end
end

function Base.setIPFromText(menu, ipText)
    local octets = {}
    for octet in ipText:gmatch("%d+") do
        table.insert(octets, octet)
    end
    
    if #octets == 4 then
        local newDigits = {}
        for i = 1, 4 do
            local octet = octets[i]
            while #octet < 3 do
                octet = "0" .. octet
            end
            for j = 1, 3 do
                table.insert(newDigits, tonumber(octet:sub(j, j)))
            end
        end
        menu.ipDigits = newDigits
    end
end

return Base
