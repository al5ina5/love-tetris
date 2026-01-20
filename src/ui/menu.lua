-- src/ui/menu.lua
-- Simple menu system for server browser and hosting
-- Like a React component with state

local Menu = {}
Menu.__index = Menu

-- Menu states
Menu.STATE = {
    MAIN = "main",
    HOST = "host",
    BROWSE = "browse",
    CONNECTING = "connecting",
    WAITING = "waiting",
}

-- Pass discovery from Game (dependency injection, like passing props)
function Menu:new(discovery)
    local self = setmetatable({}, Menu)
    
    -- Start HIDDEN (state = nil means not visible)
    self.state = nil
    
    -- Use shared discovery instance from Game
    self.discovery = discovery
    
    self.selectedServer = nil
    self.selectedIndex = 1
    self.serverName = "Player's Game"
    self.scanTimer = 0
    
    -- Callback functions (set by game.lua)
    self.onHost = nil      -- Called when user wants to host
    self.onStopHost = nil  -- Called when user wants to stop hosting
    self.onJoin = nil      -- Called when user wants to join a server
    self.onCancel = nil    -- Called when returning to game
    
    return self
end

function Menu:show()
    print("Menu: Showing menu, resetting to MAIN state")
    self.state = Menu.STATE.MAIN
    self.selectedIndex = 1
    self.scanTimer = 0

    -- Start listening for servers when menu opens
    self.discovery:startListening()
    self.discovery:sendDiscoveryRequest()
end

function Menu:hide()
    print("Menu: Hiding menu (was in state: " .. tostring(self.state) .. ")")
    self.state = nil
    -- Don't stop advertising here - Game manages that
end

function Menu:isVisible()
    return self.state ~= nil
end

function Menu:update(dt)
    if not self:isVisible() then return end
    
    -- Periodically rescan for servers when browsing
    if self.state == Menu.STATE.BROWSE then
        self.scanTimer = self.scanTimer + dt
        if self.scanTimer >= 2.0 then
            self.scanTimer = 0
            self.discovery:sendDiscoveryRequest()
        end
    end
end

function Menu:draw()
    if not self:isVisible() then return end

    -- Darken full background
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Draw based on state
    if self.state == Menu.STATE.MAIN then
        self:drawMainMenu()
    elseif self.state == Menu.STATE.WAITING then
        self:drawWaitingScreen()
    elseif self.state == Menu.STATE.BROWSE then
        self:drawServerBrowser()
    elseif self.state == Menu.STATE.CONNECTING then
        self:drawConnecting()
    end

    love.graphics.setColor(1, 1, 1)
end

function Menu:drawMainMenu()
    local sw, sh = love.graphics.getDimensions()

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Sirtet", 0, sh/2 - 100, sw, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("Multiplayer Tetris", 0, sh/2 - 70, sw, "center")

    -- Menu options - Host Game, Join Game (network), Join Host (same machine)
    local options = {
        "Host Game",
        "Join Game",
        "Join Host",
    }

    local startY = sh/2 - 20
    local y = startY
    for i, option in ipairs(options) do
        if i == self.selectedIndex then
            love.graphics.setColor(1, 1, 0.5)
            love.graphics.printf("> " .. option, 0, y, sw, "center")
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf("  " .. option, 0, y, sw, "center")
        end
        y = y + 30
    end

    -- Show IP address for join options
    if self.selectedIndex == 2 then
        local servers = self.discovery:getServers()
        love.graphics.setColor(0.6, 0.6, 0.6)
        if #servers > 0 then
            love.graphics.printf("Auto-join", 0, y + 10, sw, "center")
        else
            love.graphics.printf("No servers found", 0, y + 10, sw, "center")
        end
    elseif self.selectedIndex == 3 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("localhost", 0, y + 10, sw, "center")
    end

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Host Game on one device, Join Game on another", 0, sh - 70, sw, "center")
    love.graphics.printf("Arrow Keys: Select | Enter: Confirm", 0, sh - 50, sw, "center")
end

function Menu:drawServerBrowser()
    local sw, sh = love.graphics.getDimensions()
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Find Game", 0, 20, sw, "center")
    
    local servers = self.discovery:getServers()
    
    if #servers == 0 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf("Searching for games...", 0, 100, sw, "center")
        love.graphics.printf("Make sure both devices are on\nthe same WiFi network", 0, 130, sw, "center")
    else
        -- List servers
        local y = 50
        local menuWidth = 280
        local menuX = (sw - menuWidth) / 2
        for i, server in ipairs(servers) do
            local isSelected = (i == self.selectedIndex)
            
            if isSelected then
                love.graphics.setColor(0.3, 0.3, 0.5)
                love.graphics.rectangle("fill", menuX - 10, y - 2, menuWidth + 20, 24)
                love.graphics.setColor(1, 1, 0.5)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            
            -- Server name
            love.graphics.print(server.name, menuX, y)
            
            -- Player count
            love.graphics.printf(
                server.players .. "/" .. server.maxPlayers,
                menuX, y, menuWidth, "right"
            )
            
            -- IP (smaller, dimmer)
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print(server.ip, menuX, y + 11)
            
            y = y + 30
            if y > sh - 100 then break end  -- Max visible servers
        end
    end
    
    -- Controls hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Enter: Join | ESC: Back | R: Refresh", 0, sh - 40, sw, "center")
end

function Menu:drawWaitingScreen()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Hosting Game", 0, 40, sw, "center")

    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("Waiting for opponent to join...", 0, 100, sw, "center")

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Press ESC to stop hosting", 0, sh - 40, sw, "center")
end

function Menu:drawConnecting()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Connecting...", 0, 110, sw, "center")

    if self.selectedServer then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.printf(self.selectedServer.name, 0, 130, sw, "center")
    end

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Press ESC to cancel", 0, sh - 40, sw, "center")
end

function Menu:keypressed(key)
    if not self:isVisible() then return false end

    if self.state == Menu.STATE.MAIN then
        return self:handleMainMenuKey(key)
    elseif self.state == Menu.STATE.WAITING then
        if key == "escape" then
            if self.onStopHost then self.onStopHost() end
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            return true
        end
    elseif self.state == Menu.STATE.BROWSE then
        return self:handleBrowseKey(key)
    elseif self.state == Menu.STATE.CONNECTING then
        if key == "escape" then
            print("Menu: User cancelled connection, returning to main menu")
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            -- Disconnect client if connecting
            if self.onCancel then self.onCancel() end
            return true
        end
    end

    return false
end

function Menu:gamepadpressed(button)
    if not self:isVisible() then return false end

    if self.state == Menu.STATE.MAIN then
        return self:handleMainMenuGamepad(button)
    elseif self.state == Menu.STATE.WAITING then
        if button == "b" or button == "back" then
            if self.onStopHost then self.onStopHost() end
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            return true
        end
    elseif self.state == Menu.STATE.BROWSE then
        return self:handleBrowseGamepad(button)
    elseif self.state == Menu.STATE.CONNECTING then
        if button == "b" then
            print("Menu: User cancelled connection (gamepad), returning to main menu")
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            -- Disconnect client if connecting
            if self.onCancel then self.onCancel() end
            return true
        end
    end

    return false
end

function Menu:handleMainMenuKey(key)
    if key == "up" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif key == "down" then
        self.selectedIndex = math.min(3, self.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" then
        if self.selectedIndex == 1 then
            -- Host Game - go to waiting screen
            self.state = Menu.STATE.WAITING
            if self.onHost then self.onHost() end
        elseif self.selectedIndex == 2 then
            -- Join Game - Go to browse state
            self.state = Menu.STATE.BROWSE
            self.selectedIndex = 1
            self.discovery:sendDiscoveryRequest()
        elseif self.selectedIndex == 3 then
            -- Join Host (localhost)
            self.state = Menu.STATE.CONNECTING
            self.selectedServer = {name = "Host Server", ip = "localhost", port = 12345}
            if self.onJoin then
                self.onJoin("localhost", 12345)
            end
        end
        return true
    elseif key == "escape" then
        -- No escape handling for main menu - must choose an option
        return true
    end

    return false
end

function Menu:handleMainMenuGamepad(button)
    if button == "dpup" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        self.selectedIndex = math.min(3, self.selectedIndex + 1)
        return true
    elseif button == "a" then
        if self.selectedIndex == 1 then
            -- Host Game - go to waiting screen
            self.state = Menu.STATE.WAITING
            if self.onHost then self.onHost() end
        elseif self.selectedIndex == 2 then
            -- Join Game - Go to browse state
            self.state = Menu.STATE.BROWSE
            self.selectedIndex = 1
            self.discovery:sendDiscoveryRequest()
        elseif self.selectedIndex == 3 then
            -- Join Host (localhost)
            self.state = Menu.STATE.CONNECTING
            self.selectedServer = {name = "Host Server", ip = "localhost", port = 12345}
            if self.onJoin then
                self.onJoin("localhost", 12345)
            end
        end
        return true
    elseif button == "b" or button == "back" then
        -- No back button handling for main menu - must choose an option
        return true
    end

    return false
end

function Menu:handleBrowseKey(key)
    local servers = self.discovery:getServers()
    
    if key == "up" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif key == "down" then
        self.selectedIndex = math.min(math.max(1, #servers), self.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" then
        if #servers > 0 and self.selectedIndex <= #servers then
            self.selectedServer = servers[self.selectedIndex]
            self.state = Menu.STATE.CONNECTING
            
            if self.onJoin then
                self.onJoin(self.selectedServer.ip, self.selectedServer.port)
            end
        end
        return true
    elseif key == "escape" then
        self.state = Menu.STATE.MAIN
        self.selectedIndex = 2
        return true
    elseif key == "r" then
        -- Refresh
        self.discovery:sendDiscoveryRequest()
        return true
    end
    
    return false
end

function Menu:handleBrowseGamepad(button)
    local servers = self.discovery:getServers()
    
    if button == "dpup" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        self.selectedIndex = math.min(math.max(1, #servers), self.selectedIndex + 1)
        return true
    elseif button == "a" then
        if #servers > 0 and self.selectedIndex <= #servers then
            self.selectedServer = servers[self.selectedIndex]
            self.state = Menu.STATE.CONNECTING
            
            if self.onJoin then
                self.onJoin(self.selectedServer.ip, self.selectedServer.port)
            end
        end
        return true
    elseif button == "b" or button == "back" then
        self.state = Menu.STATE.MAIN
        self.selectedIndex = 2
        return true
    elseif button == "x" or button == "y" then
        -- Refresh
        self.discovery:sendDiscoveryRequest()
        return true
    end
    
    return false
end

function Menu:close()
    -- Discovery is owned by Game, don't close it here
end

return Menu
