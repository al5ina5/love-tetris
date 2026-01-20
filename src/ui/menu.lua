-- src/ui/menu.lua
-- Simple menu system for server browser and hosting
-- Like a React component with state

local TetrisBoard = require('src.tetris_board')

local Options = require('src.ui.options')

local Menu = {}
Menu.__index = Menu

-- Menu states
Menu.STATE = {
    MAIN = "main",
    HOST = "host",
    BROWSE = "browse",
    CONNECTING = "connecting",
    WAITING = "waiting",
    IP_INPUT = "ip_input",
    OPTIONS = "options",
    PAUSE = "pause",
}

-- Add a property to track which menu we came from (for Options)
Menu.previousState = nil

-- Pass discovery from Game (dependency injection, like passing props)
function Menu:new(discovery, fonts)
    local self = setmetatable({}, Menu)
    
    -- Start HIDDEN (state = nil means not visible)
    self.state = nil
    
    -- Use shared discovery instance from Game
    self.discovery = discovery
    self.fonts = fonts
    
    self.selectedServer = nil
    self.selectedIndex = 1
    self.serverName = "Player's Game"
    self.scanTimer = 0
    
    -- Input debouncing for handhelds that might map gamepad to keys
    self.inputCooldown = 0
    self.COOLDOWN_TIME = 0.15 -- 150ms lockout between menu actions
    
    -- IP Input state (12 digits, 3 per octet)
    self.ipDigits = {1,9,2,  1,6,8,  0,0,1,  0,0,1}
    self.selectedDigit = 1
    
    -- Falling blocks for background effect
    self.fallingBlocks = {}
    self:initFallingBlocks()
    
    -- Callback functions (set by game.lua)
    self.onHost = nil      -- Called when user wants to host
    self.onStopHost = nil  -- Called when user wants to stop hosting
    self.onStartAlone = nil -- Called when user wants to start alone
    self.onJoin = nil      -- Called when user wants to join a server
    self.onCancel = nil    -- Called when returning to game
    self.onMainMenu = nil  -- Called when returning to main menu from game
    self.onSettingChanged = nil -- Called when a setting is changed

    -- Initialize options
    Options.init(self)
    
    return self
end

function Menu:initFallingBlocks()
    self.fallingBlocks = {}
    local pieceTypes = {"I", "J", "L", "O", "S", "T", "Z"}
    -- Use virtual resolution 320x240
    for i = 1, 25 do
        local sizeX, sizeY = 16, 11 -- Match game board block size
        local type = pieceTypes[love.math.random(#pieceTypes)]
        table.insert(self.fallingBlocks, {
            type = type,
            color = TetrisBoard.PIECES[type].color,
            x = math.floor(love.math.random(0, 320 / sizeX)) * sizeX,
            y = math.floor(love.math.random(-20, 240 / sizeY)) * sizeY,
            speed = love.math.random(2, 6) * 0.1, -- seconds per step
            moveTimer = 0,
            rotation = love.math.random(0, 3),
            opacity = love.math.random(15, 35) / 100, -- 0.15 to 0.35
            sizeX = sizeX,
            sizeY = sizeY
        })
    end
end

function Menu:show(state)
    state = state or Menu.STATE.MAIN
    print("Menu: Showing menu, state: " .. tostring(state))
    self.state = state
    self.selectedIndex = 1
    self.scanTimer = 0
    self.inputCooldown = 0.2 -- Small delay when opening menu to prevent accidental double-clicks

    if state == Menu.STATE.BROWSE then
        -- Start listening for servers when menu opens to browse
        self.discovery:startListening()
        self.discovery:sendDiscoveryRequest()
    elseif state == Menu.STATE.MAIN then
        -- Also listen in main menu just in case
        self.discovery:startListening()
    end
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
    
    -- Update falling blocks
    for _, block in ipairs(self.fallingBlocks) do
        block.moveTimer = block.moveTimer + dt
        if block.moveTimer >= block.speed then
            block.moveTimer = 0
            block.y = block.y + block.sizeY
            if block.y > 240 then
                block.y = -block.sizeY * 4
                block.x = math.floor(love.math.random(0, 320 / block.sizeX)) * block.sizeX
                block.speed = love.math.random(2, 6) * 0.1
                block.opacity = love.math.random(15, 35) / 100
                
                -- New type and color
                local pieceTypes = {"I", "J", "L", "O", "S", "T", "Z"}
                block.type = pieceTypes[love.math.random(#pieceTypes)]
                block.color = TetrisBoard.PIECES[block.type].color
            end
        end
    end

    -- Update input cooldown
    if self.inputCooldown > 0 then
        self.inputCooldown = self.inputCooldown - dt
    end
    
    -- Periodically rescan for servers when browsing
    if self.state == Menu.STATE.BROWSE then
        self.scanTimer = self.scanTimer + dt
        if self.scanTimer >= 2.0 then
            self.scanTimer = 0
            self.discovery:sendDiscoveryRequest()
        end
    end
end

function Menu:draw(game)
    -- This method is now split into drawBackground and drawForeground
    -- for better shader support.
end

function Menu:drawBackground(game)
    if not self:isVisible() then return end
    local sw, sh = 320, 240

    -- Darken full background
    love.graphics.setColor(0, 0, 0, 1.0)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Draw falling blocks
    self:drawFallingBlocks()
end

function Menu:drawForeground(game)
    if not self:isVisible() then return end
    local sw, sh = 320, 240

    -- Use medium font as default for menu
    if self.fonts then
        love.graphics.setFont(self.fonts.medium)
    end

    -- Draw based on state
    if self.state == Menu.STATE.MAIN then
        self:drawMainMenu(sw, sh, game)
    elseif self.state == Menu.STATE.WAITING then
        self:drawWaitingScreen(sw, sh, game)
    elseif self.state == Menu.STATE.BROWSE then
        self:drawServerBrowser(sw, sh, game)
    elseif self.state == Menu.STATE.CONNECTING then
        self:drawConnecting(sw, sh, game)
    elseif self.state == Menu.STATE.IP_INPUT then
        self:drawIPInput(sw, sh, game)
    elseif self.state == Menu.STATE.PAUSE then
        self:drawPauseMenu(sw, sh, game)
    elseif self.state == Menu.STATE.OPTIONS then
        Options.draw(self, sw, sh, game)
    end

    love.graphics.setColor(1, 1, 1)
end

function Menu:drawFallingBlocks()
    for _, block in ipairs(self.fallingBlocks) do
        local data = TetrisBoard.PIECES[block.type]
        if data then
            -- Use the block's assigned color with its opacity
            local r, g, b = unpack(block.color or {0, 0.8, 0.2})
            love.graphics.setColor(r, g, b, block.opacity)
            
            local shape = data
            for y = 1, #shape do
                for x = 1, #shape[y] do
                    if shape[y][x] ~= 0 then
                        -- Simple rotation logic for background blocks
                        local drawX, drawY = x-1, y-1
                        if block.rotation == 1 then
                            drawX, drawY = #shape-y, x-1
                        elseif block.rotation == 2 then
                            drawX, drawY = #shape-x, #shape-y
                        elseif block.rotation == 3 then
                            drawX, drawY = y-1, #shape-x
                        end
                        
                        love.graphics.rectangle("fill", 
                            block.x + drawX * block.sizeX, 
                            block.y + drawY * block.sizeY, 
                            block.sizeX - 1, block.sizeY - 1)
                    end
                end
            end
        end
    end
end

function Menu:drawList(sw, sh, game, title, subtitle, options, startY)
    -- Title
    if title then
        if self.fonts then love.graphics.setFont(self.fonts.large) end
        game:drawText(title, 0, sh/2 - 65, sw, "center", {1, 1, 1}, {0.3, 0.3, 0.3})
    end

    -- Subtitle
    if subtitle then
        if self.fonts then love.graphics.setFont(self.fonts.medium) end
        game:drawText(subtitle, 0, sh/2 - 30, sw, "center", {0.7, 0.7, 0.7})
    end

    -- Menu options
    if self.fonts then love.graphics.setFont(self.fonts.medium) end
    local y = startY or (sh/2 - 10)
    for i, option in ipairs(options) do
        local color = {0.8, 0.8, 0.8}
        local text = "  " .. option
        if i == self.selectedIndex then
            color = {1, 1, 0.5}
            text = "> " .. option
        end
        game:drawText(text, 0, y, sw, "center", color)
        y = y + 15
    end
end

function Menu:drawMainMenu(sw, sh, game)
    local options = {
        "HOST GAME",
        "FIND GAME",
        "JOIN BY IP",
        "OPTIONS",
    }
    self:drawList(sw, sh, game, "SIRTET", "Multiplayer Tetris", options)
end

function Menu:drawPauseMenu(sw, sh, game)
    local options = {
        "RESUME",
        "OPTIONS",
        "MAIN MENU",
    }
    self:drawList(sw, sh, game, "PAUSED", nil, options)
end

function Menu:drawIPInput(sw, sh, game)
    game:drawText("Join via IP", 0, 40, sw, "center", {1, 1, 1})
    
    local digitWidth = 14
    local spacing = 2
    local groupSpacing = 12
    local totalWidth = (digitWidth * 12) + (spacing * 8) + (groupSpacing * 3)
    local startX = (sw - totalWidth) / 2
    local y = sh / 2 - 10
    
    for i = 1, 12 do
        local group = math.floor((i-1) / 3)
        local groupOffset = group * groupSpacing
        local x = startX + (i - 1) * (digitWidth + spacing) + groupOffset
        local isSelected = (i == self.selectedDigit)
        
        -- Box for selection
        if isSelected then
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", x - 2, y - 5, digitWidth + 4, 30)
            
            -- Up/Down arrows
            game:drawText("^", x, y - 20, digitWidth, "center", {1, 1, 0.5})
            game:drawText("v", x, y + 25, digitWidth, "center", {1, 1, 0.5})
        end
        
        love.graphics.setColor(1, 1, 1)
        game:drawText(tostring(self.ipDigits[i]), x, y, digitWidth, "center", isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8})
        
        -- Dot after groups of 3
        if i % 3 == 0 and i < 12 then
            game:drawText(".", x + digitWidth, y, groupSpacing, "center", {0.5, 0.5, 0.5})
        end
    end
    
end

function Menu:drawServerBrowser(sw, sh, game)
    -- Title
    game:drawText("Find Game", 0, 10, sw, "center", {1, 1, 1})
    
    local servers = self.discovery:getServers()
    
    if #servers == 0 then
        game:drawText("Searching for games...", 0, 80, sw, "center", {0.6, 0.6, 0.6})
        game:drawText("Same WiFi required", 0, 100, sw, "center", {0.6, 0.6, 0.6})
    else
        -- List servers
        local y = 35
        local menuWidth = 200
        local menuX = (sw - menuWidth) / 2
        for i, server in ipairs(servers) do
            local isSelected = (i == self.selectedIndex)
            
            if isSelected then
                love.graphics.setColor(0.3, 0.3, 0.5)
                love.graphics.rectangle("fill", menuX - 5, y - 2, menuWidth + 10, 20)
                game:drawText(server.name, menuX, y, menuWidth, "left", {1, 1, 0.5})
                game:drawText(server.players .. "/" .. server.maxPlayers, menuX, y, menuWidth, "right", {1, 1, 0.5})
            else
                game:drawText(server.name, menuX, y, menuWidth, "left", {0.8, 0.8, 0.8})
                game:drawText(server.players .. "/" .. server.maxPlayers, menuX, y, menuWidth, "right", {0.8, 0.8, 0.8})
            end
            
            -- IP
            game:drawText(server.ip, menuX, y + 9, menuWidth, "left", {0.5, 0.5, 0.5})
            
            y = y + 22
            if y > sh - 50 then break end
        end
    end
    
end

function Menu:drawWaitingScreen(sw, sh, game)
    game:drawText("Hosting Game", 0, 30, sw, "center", {1, 1, 1})
    game:drawText("Waiting for opponent...", 0, 80, sw, "center", {0.6, 0.6, 0.6})
    
    if self.discovery and self.discovery.localIP then
        game:drawText("Your IP: " .. self.discovery.localIP, 0, 110, sw, "center", {0.4, 0.8, 0.4})
    end

end

function Menu:drawConnecting(sw, sh, game)
    game:drawText("Connecting...", 0, 90, sw, "center", {1, 1, 1})

    if self.selectedServer then
        game:drawText(self.selectedServer.name, 0, 110, sw, "center", {0.6, 0.6, 0.6})
    end

end

function Menu:keypressed(key)
    if not self:isVisible() then return false end
    if self.inputCooldown > 0 then return true end

    local handled = false
    if self.state == Menu.STATE.MAIN then
        handled = self:handleMainMenuKey(key)
    elseif self.state == Menu.STATE.WAITING then
        if key == "escape" or key == "z" then
            if self.onStopHost then self.onStopHost() end
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            handled = true
        elseif key == "return" or key == "x" or key == "space" then
            if self.onStartAlone then self.onStartAlone() end
            handled = true
        end
    elseif self.state == Menu.STATE.BROWSE then
        handled = self:handleBrowseKey(key)
    elseif self.state == Menu.STATE.PAUSE then
        handled = self:handlePauseMenuKey(key)
    elseif self.state == Menu.STATE.OPTIONS then
        handled = Options.handleKey(self, key, self.onSettingChanged)
    elseif self.state == Menu.STATE.IP_INPUT then
        handled = self:handleIPInputKey(key)
    elseif self.state == Menu.STATE.CONNECTING then
        if key == "escape" or key == "z" then
            print("Menu: User cancelled connection, returning to main menu")
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            -- Disconnect client if connecting
            if self.onCancel then self.onCancel() end
            handled = true
        end
    end

    if handled then
        self.inputCooldown = self.COOLDOWN_TIME
    end
    return handled
end

function Menu:gamepadpressed(button)
    if not self:isVisible() then return false end
    if self.inputCooldown > 0 then return true end

    local handled = false
    if self.state == Menu.STATE.MAIN then
        handled = self:handleMainMenuGamepad(button)
    elseif self.state == Menu.STATE.WAITING then
        if button == "b" or button == "back" then
            if self.onStopHost then self.onStopHost() end
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            handled = true
        elseif button == "a" or button == "start" then
            if self.onStartAlone then self.onStartAlone() end
            handled = true
        end
    elseif self.state == Menu.STATE.BROWSE then
        handled = self:handleBrowseGamepad(button)
    elseif self.state == Menu.STATE.PAUSE then
        handled = self:handlePauseMenuGamepad(button)
    elseif self.state == Menu.STATE.OPTIONS then
        handled = Options.handleGamepad(self, button, self.onSettingChanged)
    elseif self.state == Menu.STATE.IP_INPUT then
        handled = self:handleIPInputGamepad(button)
    elseif self.state == Menu.STATE.CONNECTING then
        if button == "b" then
            print("Menu: User cancelled connection (gamepad), returning to main menu")
            self.state = Menu.STATE.MAIN
            self.selectedIndex = 1
            -- Disconnect client if connecting
            if self.onCancel then self.onCancel() end
            handled = true
        end
    end

    if handled then
        self.inputCooldown = self.COOLDOWN_TIME
    end
    return handled
end

function Menu:handleMainMenuKey(key)
    if key == "up" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif key == "down" then
        self.selectedIndex = math.min(4, self.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
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
            -- Join via IP
            self.state = Menu.STATE.IP_INPUT
            self.selectedDigit = 1
        elseif self.selectedIndex == 4 then
            -- Options
            self.previousState = self.state
            self.state = Menu.STATE.OPTIONS
            self.optionsSelectedIndex = 1
        end
        return true
    elseif key == "escape" or key == "z" then
        -- No escape handling for main menu - must choose an option
        return true
    end

    return false
end

function Menu:handlePauseMenuKey(key)
    if key == "up" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif key == "down" then
        self.selectedIndex = math.min(3, self.selectedIndex + 1)
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if self.selectedIndex == 1 then
            -- Resume
            self:hide()
        elseif self.selectedIndex == 2 then
            -- Options
            self.previousState = self.state
            self.state = Menu.STATE.OPTIONS
            self.optionsSelectedIndex = 1
        elseif self.selectedIndex == 3 then
            -- Main Menu
            if self.onMainMenu then self.onMainMenu() end
            self:show(Menu.STATE.MAIN)
        end
        return true
    elseif key == "escape" or key == "z" then
        self:hide()
        return true
    end
    return false
end

function Menu:handlePauseMenuGamepad(button)
    if button == "dpup" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        self.selectedIndex = math.min(3, self.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
        if self.selectedIndex == 1 then
            -- Resume
            self:hide()
        elseif self.selectedIndex == 2 then
            -- Options
            self.previousState = self.state
            self.state = Menu.STATE.OPTIONS
            self.optionsSelectedIndex = 1
        elseif self.selectedIndex == 3 then
            -- Main Menu
            if self.onMainMenu then self.onMainMenu() end
            self:show(Menu.STATE.MAIN)
        end
        return true
    elseif button == "b" or button == "back" then
        self:hide()
        return true
    end
    return false
end

function Menu:handleIPInputKey(key)
    if key == "left" then
        self.selectedDigit = math.max(1, self.selectedDigit - 1)
        return true
    elseif key == "right" then
        self.selectedDigit = math.min(12, self.selectedDigit + 1)
        return true
    elseif key == "up" then
        self.ipDigits[self.selectedDigit] = (self.ipDigits[self.selectedDigit] + 1) % 10
        return true
    elseif key == "down" then
        self.ipDigits[self.selectedDigit] = (self.ipDigits[self.selectedDigit] - 1) % 10
        if self.ipDigits[self.selectedDigit] < 0 then self.ipDigits[self.selectedDigit] = 9 end
        return true
    elseif key == "return" or key == "space" or key == "x" then
        -- Convert 12 digits back to 4 octets
        local octets = {}
        for i = 1, 4 do
            local start = (i-1)*3 + 1
            local val = self.ipDigits[start]*100 + self.ipDigits[start+1]*10 + self.ipDigits[start+2]
            table.insert(octets, math.min(255, val))
        end
        local ip = table.concat(octets, ".")
        self.state = Menu.STATE.CONNECTING
        self.selectedServer = {name = "Custom IP", ip = ip, port = 12345}
        if self.onJoin then
            self.onJoin(ip, 12345)
        end
        return true
    elseif key == "escape" or key == "z" then
        self.state = Menu.STATE.MAIN
        self.selectedIndex = 3
        return true
    end
    return false
end

function Menu:handleMainMenuGamepad(button)
    if button == "dpup" then
        self.selectedIndex = math.max(1, self.selectedIndex - 1)
        return true
    elseif button == "dpdown" then
        self.selectedIndex = math.min(4, self.selectedIndex + 1)
        return true
    elseif button == "a" or button == "start" then
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
            -- Join via IP
            self.state = Menu.STATE.IP_INPUT
            self.selectedDigit = 1
        elseif self.selectedIndex == 4 then
            -- Options
            self.previousState = self.state
            self.state = Menu.STATE.OPTIONS
            self.optionsSelectedIndex = 1
        end
        return true
    elseif button == "b" or button == "back" then
        -- No back button handling for main menu - must choose an option
        return true
    end

    return false
end

function Menu:handleIPInputGamepad(button)
    if button == "dpleft" then
        self.selectedDigit = math.max(1, self.selectedDigit - 1)
        return true
    elseif button == "dpright" then
        self.selectedDigit = math.min(12, self.selectedDigit + 1)
        return true
    elseif button == "dpup" then
        self.ipDigits[self.selectedDigit] = (self.ipDigits[self.selectedDigit] + 1) % 10
        return true
    elseif button == "dpdown" then
        self.ipDigits[self.selectedDigit] = (self.ipDigits[self.selectedDigit] - 1) % 10
        if self.ipDigits[self.selectedDigit] < 0 then self.ipDigits[self.selectedDigit] = 9 end
        return true
    elseif button == "a" then
        -- Convert 12 digits back to 4 octets
        local octets = {}
        for i = 1, 4 do
            local start = (i-1)*3 + 1
            local val = self.ipDigits[start]*100 + self.ipDigits[start+1]*10 + self.ipDigits[start+2]
            table.insert(octets, math.min(255, val))
        end
        local ip = table.concat(octets, ".")
        self.state = Menu.STATE.CONNECTING
        self.selectedServer = {name = "Custom IP", ip = ip, port = 12345}
        if self.onJoin then
            self.onJoin(ip, 12345)
        end
        return true
    elseif button == "b" or button == "back" then
        self.state = Menu.STATE.MAIN
        self.selectedIndex = 3
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
    elseif key == "return" or key == "space" or key == "x" then
        if #servers > 0 and self.selectedIndex <= #servers then
            self.selectedServer = servers[self.selectedIndex]
            self.state = Menu.STATE.CONNECTING
            
            if self.onJoin then
                self.onJoin(self.selectedServer.ip, self.selectedServer.port)
            end
        end
        return true
    elseif key == "escape" or key == "z" then
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
