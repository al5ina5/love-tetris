-- src/game.lua
-- Main game manager for Multiplayer Tetris

local TetrisBoard = require('src.tetris_board')
local Input = require('src.systems.input')
local Client = require('src.net.client')
local Server = require('src.net.server')
local Discovery = require('src.net.discovery')
local Menu = require('src.ui.menu')
local Protocol = require('src.net.protocol')
local Audio = require('src.audio')

local Game = {
    isHost = false,
    localBoard = nil,
    remoteBoards = {}, -- Keyed by player ID
    network = nil,
    discovery = nil,
    menu = nil,
    playerId = nil,
    lastSentMove = {x=0, y=0, rot=0, type=""},
    lastSentScore = 0,
    sentGameOver = false,
    connectionTimer = 0,
    connectionTimeout = 10.0, -- 10 seconds timeout
    gameOverTimer = 0,
    activeShader = nil,
    shaderType = "OFF",
    hasTimeUniform = false,
    
    -- State machine
    state = "waiting",
    countdownTimer = 0,
    STATE = {
        WAITING = "waiting",
        COUNTDOWN = "countdown",
        PLAYING = "playing",
        GAME_OVER = "over"
    }
}

function Game:load()
    self.localBoard = TetrisBoard:new(10, 20)
    self.remoteBoards = {}
    self.network = nil
    self.isHost = false
    self.playerId = nil
    self.state = self.STATE.WAITING
    self.countdownTimer = 0
    self.sentGameOver = false
    
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
    
    self.fonts = {
        small = love.graphics.newFont('src/upheavtt.ttf', 8),
        medium = love.graphics.newFont('src/upheavtt.ttf', 12),
        large = love.graphics.newFont('src/upheavtt.ttf', 40),
        score = love.graphics.newFont('src/upheavtt.ttf', 24)
    }
    for _, f in pairs(self.fonts) do
        f:setFilter("nearest", "nearest")
    end
    
    self.canvas = love.graphics.newCanvas(320, 240)
    self.canvas:setFilter("nearest", "nearest")
    
    self.discovery = Discovery:new()
    self.menu = Menu:new(self.discovery, self.fonts)
    Audio:init()
    self.menu.onHost = function() self:becomeHost() end
    self.menu.onStopHost = function() self:stopHosting() end
    self.menu.onStartAlone = function() self:startAlone() end
    self.menu.onJoin = function(ip, port) self:connectToServer(ip, port) end
    self.menu.onMainMenu = function() self:returnToMainMenu() end
    self.menu.onSettingChanged = function(key, value) self:handleSettingChange(key, value) end
    
    -- Apply initial settings
    self:handleSettingChange("shader", self.menu.settings.shader)
    self:handleSettingChange("musicVolume", self.menu.settings.musicVolume)
    self:handleSettingChange("sfxVolume", self.menu.settings.sfxVolume)
    self:handleSettingChange("sfxVolume", self.menu.settings.sfxVolume)
    
    self.menu.onCancel = function()
        if self.network and not self.isHost then
            print("Game: Cancelling client connection")
            self.network:disconnect()
            self.network = nil
            self.connectionTimer = 0
            Audio:playMusic('menu')
        end
    end

    -- Start with menu visible
    self.menu:show()
    Audio:playMusic('menu')
end

function Game:update(dt)
    self.discovery:update(dt)
    
    -- ALWAYS poll network messages, even if menu is open
    -- This is critical for ENet to process the connection handshake
    if self.network then
        local messages = self.network:poll()
        for _, msg in ipairs(messages) do
            self:handleNetworkMessage(msg)
        end
        
        if self.isHost then
            self.discovery:setPlayerCount(1 + self:countRemotePlayers())
        end
    end

    if self.network and not self.playerId and self.network.playerId then
        self.playerId = self.network.playerId
        print("Game: Client successfully connected with playerId: " .. self.playerId)
        -- Client connected successfully, hide menu
        if not self.isHost then
            self.menu:hide()
            self.connectionTimer = 0 -- Reset timer on successful connection
        end
    elseif self.network and not self.isHost and not self.playerId then
        -- Client is trying to connect, check for timeout
        self.connectionTimer = self.connectionTimer + dt
        if math.floor(self.connectionTimer) % 2 == 0 and math.floor(self.connectionTimer) ~= math.floor(self.connectionTimer - dt) then
            print("Game: Still connecting... " .. string.format("%.1f", self.connectionTimer) .. "/" .. self.connectionTimeout .. "s")
        end
        if self.connectionTimer >= self.connectionTimeout then
            print("Game: Connection timeout after " .. self.connectionTimeout .. " seconds, returning to menu")
            if self.network then
                self.network:disconnect()
                self.network = nil
            end
            self.state = self.STATE.WAITING
            self.menu:show()
            self.connectionTimer = 0
        end
    end
    
    -- State Logic - Needs to run always for host to transition from Waiting to Countdown
    if self.state == self.STATE.WAITING then
        -- If we have an opponent, start countdown and hide menu
        local remoteCount = self:countRemotePlayers()
        if remoteCount > 0 then
            if self.isHost then
                print("Game: Host has " .. remoteCount .. " remote players, starting countdown")
                self.menu:hide()
                self:startCountdown()
            end
        end
    elseif self.state == self.STATE.COUNTDOWN then
        local oldTime = math.ceil(self.countdownTimer)
        self.countdownTimer = self.countdownTimer - dt
        local newTime = math.ceil(self.countdownTimer)
        
        if oldTime ~= newTime then
            if newTime > 0 then
                Audio:play('beep')
            elseif newTime == 0 then
                Audio:play('go')
            end
        end
        
        if self.countdownTimer <= 0 then
            self.state = self.STATE.PLAYING
            Audio:playRandomGameMusic()
        end
    elseif self.state == self.STATE.GAME_OVER then
        self.gameOverTimer = self.gameOverTimer - dt
        if self.gameOverTimer <= 0 then
            self:reset()
        end
    end

    if self.menu:isVisible() then
        self.menu:update(dt)
        return
    end

    -- Update input timers
    Input:update(dt)

    -- Playing State Logic
    if self.state == self.STATE.PLAYING then
        -- Check if anyone lost
        local anyGameOver = self.localBoard.gameOver
        for _, board in pairs(self.remoteBoards) do
            if board.gameOver then anyGameOver = true; break end
        end

        if anyGameOver then
            self.state = self.STATE.GAME_OVER
            self.gameOverTimer = 5.0
            Audio:stopMusic()
            return
        end

        local moved = false
        local rotated = false
        
        if Input:shouldRepeat("left") or Input:shouldRepeat("dpleft", true) then 
            local m = self.localBoard:move(-1, 0)
            if m then Audio:play('move') end
            moved = m or moved
        end
        if Input:shouldRepeat("right") or Input:shouldRepeat("dpright", true) then 
            local m = self.localBoard:move(1, 0)
            if m then Audio:play('move') end
            moved = m or moved
        end
        if Input:shouldRepeat("down") or Input:shouldRepeat("dpdown", true) then 
            local m = self.localBoard:move(0, 1)
            if m then 
                Audio:play('move')
                self.localBoard.score = self.localBoard.score + 1
            end
            moved = m or moved
        end
        if Input:wasKeyPressed("up") or Input:wasButtonPressed("dpup") then
            -- Hard Drop (Apotris style)
            local dropDistance = 0
            while self.localBoard:move(0, 1) do 
                dropDistance = dropDistance + 1
            end
            self.localBoard.score = self.localBoard.score + (dropDistance * 2)
            self.localBoard:lockPiece()
            moved = true
        end
        if Input:wasKeyPressed("x") or Input:wasButtonPressed("a") then 
            rotated = self.localBoard:rotate(false) -- Clockwise
            if rotated then Audio:play('rotate') end
        end
        if Input:wasKeyPressed("z") or Input:wasButtonPressed("b") then
            rotated = self.localBoard:rotate(true) -- Counter-clockwise
            if rotated then Audio:play('rotate') end
        end
        if Input:wasKeyPressed("a") or Input:wasKeyPressed("s") or Input:wasButtonPressed("leftshoulder") or Input:wasButtonPressed("rightshoulder") then
            if self.localBoard:hold() then
                Audio:play('rotate') -- Reuse rotate sound for hold for now
                moved = true
            end
        end
        if Input:wasKeyPressed("space") then
            -- Fallback hard drop for space, but 'up' is the main one now
            local dropDistance = 0
            while self.localBoard:move(0, 1) do 
                dropDistance = dropDistance + 1
            end
            self.localBoard.score = self.localBoard.score + (dropDistance * 2)
            self.localBoard:lockPiece()
            moved = true
        end

        local autoMoved = self.localBoard:update(dt)

        -- Sync if moved/rotated or if board changed (locked/cleared)
        if moved or rotated or autoMoved or self.localBoard.gridChanged then
            self:syncLocalState(self.localBoard.gridChanged)
            self.localBoard.gridChanged = false
        end
        
        -- Sync score if changed
        if self.localBoard.score ~= self.lastSentScore then
            if self.network then
                self.network:sendMessage({type = Protocol.MSG.SCORE_SYNC, data = self.localBoard.score})
            end
            self.lastSentScore = self.localBoard.score
        end
    end

    Input:postUpdate()
end

function Game:startCountdown()
    self.state = self.STATE.COUNTDOWN
    self.countdownTimer = 3.0
    Audio:play('beep')
    if self.network then
        self.network:sendMessage({type = Protocol.MSG.START_COUNTDOWN})
    end
end

function Game:startAlone()
    print("Game: Starting alone")
    self.menu:hide()
    self:startCountdown()
end

function Game:syncLocalState(forceBoardSync)
    if not self.network then return end
    
    local px, py = self.localBoard.pieceX, self.localBoard.pieceY
    local type = self.localBoard.currentPiece and self.localBoard.currentPiece.type or "I"
    local rot = self.localBoard.rotationIndex or 0
    
    -- Send piece move (unreliable)
    if self.lastSentMove.x ~= px or self.lastSentMove.y ~= py or self.lastSentMove.type ~= type or self.lastSentMove.rot ~= rot then
        self.network:sendPieceMove(type, px, py, rot)
        self.lastSentMove = {x=px, y=py, type=type, rot=rot}
    end
    
    -- Send board sync if it changed (reliable)
    if forceBoardSync then
        self.network:sendBoardSync(self.localBoard:serializeGrid())
    end
    
    -- Send game over
    if self.localBoard.gameOver and not self.sentGameOver then
        self.network:sendMessage({type = Protocol.MSG.GAME_OVER})
        self.sentGameOver = true
    end
end

function Game:handleNetworkMessage(msg)
    if msg.type == "player_joined" then
        print("Game: Player joined: " .. msg.id .. " (total remote players: " .. self:countRemotePlayers() .. ")")
        self.remoteBoards[msg.id] = TetrisBoard:new(10, 20)
        self.remoteBoards[msg.id].currentPiece = nil
        print("Game: Added remote board for " .. msg.id .. " (now " .. self:countRemotePlayers() .. " remote players)")
        
    elseif msg.type == Protocol.MSG.START_COUNTDOWN then
        if self.state == self.STATE.WAITING or self.state == self.STATE.GAME_OVER then
            if self.state == self.STATE.GAME_OVER then
                self:reset()
            end
            self.state = self.STATE.COUNTDOWN
            self.countdownTimer = 3.0
            Audio:play('beep')
        end

    elseif msg.type == Protocol.MSG.SCORE_SYNC then
        local board = self.remoteBoards[msg.id]
        if board then board.score = tonumber(msg.score) or 0 end

    elseif msg.type == Protocol.MSG.BOARD_SYNC then
        local board = self.remoteBoards[msg.id]
        if not board then
            board = TetrisBoard:new(10, 20)
            self.remoteBoards[msg.id] = board
        end
        board:deserializeGrid(msg.gridData)
        
    elseif msg.type == Protocol.MSG.PIECE_MOVE then
        local board = self.remoteBoards[msg.id]
        if not board then
            board = TetrisBoard:new(10, 20)
            self.remoteBoards[msg.id] = board
        end
        -- Update remote piece for display
        if not board.currentPiece or board.currentPiece.type ~= msg.pieceType then
            local data = TetrisBoard.PIECES[msg.pieceType]
            if data then
                board.currentPiece = { 
                    type = msg.pieceType, 
                    shape = board:copyTable(data), 
                    color = data.color 
                }
                board.rotationIndex = 0
            end
        end
        board.pieceX = msg.x
        board.pieceY = msg.y
        
        -- Apply rotation if different (without collision checks for remote)
        if board.rotationIndex ~= msg.rotation then
            -- Reset to base shape and rotate to target
            local data = TetrisBoard.PIECES[msg.pieceType]
            if data then
                board.currentPiece.shape = board:copyTable(data)
                board.rotationIndex = 0
                for i = 1, msg.rotation do
                    -- Manual rotation without collision check
                    local oldShape = board.currentPiece.shape
                    local n = #oldShape
                    local newShape = {}
                    for j = 1, n do newShape[j] = {} end
                    for y = 1, n do
                        for x = 1, n do
                            newShape[x][n - y + 1] = oldShape[y][x]
                        end
                    end
                    board.currentPiece.shape = newShape
                    board.rotationIndex = (board.rotationIndex + 1) % 4
                end
            end
        end
        
    elseif msg.type == Protocol.MSG.GAME_OVER then
        local board = self.remoteBoards[msg.id]
        if board then board.gameOver = true end
        
    elseif msg.type == "player_left" then
        print("Player left: " .. msg.id)
        self.remoteBoards[msg.id] = nil
        if self:countRemotePlayers() == 0 then
            self.state = self.STATE.WAITING
        end
    end
end

function Game:drawText(text, x, y, limit, align, color, shadowColor, outlineColor)
    color = color or {1, 1, 1}
    shadowColor = shadowColor or {0, 0, 0, 1} -- Opaque shadow
    outlineColor = outlineColor or {0, 0, 0, 1} -- Opaque outline
    
    x, y = math.floor(x), math.floor(y)
    
    -- Draw outline (thick retro style)
    love.graphics.setColor(outlineColor)
    for ox = -1, 1 do
        for oy = -1, 1 do
            if ox ~= 0 or oy ~= 0 then
                love.graphics.printf(text, x + ox, y + oy, limit, align)
            end
        end
    end
    
    -- Draw 3D-ish Shadow
    love.graphics.setColor(shadowColor)
    love.graphics.printf(text, x, y + 1, limit, align)
    
    -- Draw main text
    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, limit, align)
end

function Game:draw()
    local sw, sh = 320, 240
    local winW, winH = love.graphics.getDimensions()
    local scale = math.min(winW / sw, winH / sh)
    local ox, oy = (winW - sw * scale) / 2, (winH - sh * scale) / 2

    -- PASS 1: Render shaded elements to our low-res canvas
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
    
    if self.menu:isVisible() then
        self.menu:drawBackground(self)
    else
        local hasOpponents = self:countRemotePlayers() > 0
        local bsW, bsH = 16, 11
        local bw, bh = 10 * bsW, 20 * bsH
        
        if not hasOpponents then
            local bx = (sw - bw) / 2
            local by = 0
            self.localBoard:draw(bx, by, bsW, bsH, self, nil, self.menu.settings.ghost)
            if self.localBoard.holdPieceType then
                self.localBoard:drawPiecePreview(self.localBoard.holdPieceType, bx + 10, bh + 2, 4, 4)
            end
            self.localBoard:drawPiecePreview(self.localBoard.nextPieceType, bx + bw - 26, bh + 2, 4, 4)
        else
            -- Left half (YOU)
            local lx = 0
            local ly = 0
            self.localBoard:draw(lx, ly, bsW, bsH, self, nil, self.menu.settings.ghost)
            if self.localBoard.holdPieceType then
                self.localBoard:drawPiecePreview(self.localBoard.holdPieceType, lx + 10, bh + 2, 4, 4)
            end
            self.localBoard:drawPiecePreview(self.localBoard.nextPieceType, lx + bw - 26, bh + 2, 4, 4)
            
            -- Right half (OPPONENT)
            local count = 0
            local opponentColor = {0.5, 0.5, 0.5}
            for id, board in pairs(self.remoteBoards) do
                if count == 0 then
                    local rx = sw / 2
                    local ry = 0
                    board:draw(rx, ry, bsW, bsH, self, opponentColor)
                    board:drawPiecePreview(board.nextPieceType, rx + bw - 26, bh + 2, 4, 4)
                else
                    local miniBs = 4
                    local miniBw, miniBh = 10 * miniBs, 20 * miniBs
                    local ex = sw - miniBw - 5
                    local ey = 5 + (count - 1) * (miniBh + 10)
                    board:draw(ex, ey, miniBs, miniBs, self, opponentColor)
                end
                count = count + 1
            end
            
            -- Vertical divider
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.line(sw / 2, 0, sw / 2, sh)
        end
        
        -- Overlay backgrounds (shaded)
        if self.state == self.STATE.COUNTDOWN then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", 0, 0, sw, sh)
        elseif self.state == self.STATE.GAME_OVER then
            love.graphics.setColor(0, 0, 0, 0.8)
            love.graphics.rectangle("fill", 0, 0, sw, sh)
        end
    end
    
    love.graphics.setCanvas()
    
    -- DRAW CANVAS WITH SHADER
    love.graphics.setColor(1, 1, 1)
    if self.activeShader then
        if self.hasTimeUniform then
            self.activeShader:send("time", love.timer.getTime())
        end
        love.graphics.setShader(self.activeShader)
    end
    love.graphics.draw(self.canvas, ox, oy, 0, scale, scale)
    love.graphics.setShader()

    -- PASS 2: Render unshaded elements (UI and Text) directly to screen
    -- Apply the same transformation so UI elements are positioned correctly
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale)
    
    if self.menu:isVisible() then
        self.menu:drawForeground(self)
    else
        local hasOpponents = self:countRemotePlayers() > 0
        local bsW, bsH = 16, 11
        local bw, bh = 10 * bsW, 20 * bsH

        if not hasOpponents then
            local bx = (sw - bw) / 2
            love.graphics.setFont(self.fonts.score)
            self:drawText(tostring(self.localBoard.score), bx, bh + 2, bw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
            
            if self.state == self.STATE.WAITING then
                love.graphics.setFont(self.fonts.small)
                self:drawText("WAITING FOR OPPONENT...", bx, bh - 20, bw, "center", {0.7, 0.7, 0.7})
            end
        else
            -- Scores for multiplayer
            love.graphics.setFont(self.fonts.score)
            self:drawText(tostring(self.localBoard.score), 0, bh + 2, sw / 2, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
            
            local count = 0
            for id, board in pairs(self.remoteBoards) do
                if count == 0 then
                    self:drawText(tostring(board.score or 0), sw / 2, bh + 2, sw / 2, "center", {0.8, 0.8, 0.8})
                end
                count = count + 1
            end
        end

        -- Countdown Text
        if self.state == self.STATE.COUNTDOWN then
            love.graphics.setFont(self.fonts.large)
            local text = math.ceil(self.countdownTimer)
            if text == 0 then text = "GO!" end
            self:drawText(tostring(text), 0, sh/2 - 20, sw, "center", {1, 0.3, 0.1}, {0.3, 0, 0})
        end

        -- Game Over Text
        if self.state == self.STATE.GAME_OVER then
            love.graphics.setFont(self.fonts.large)
            local text = "GAME OVER"
            local color = {1, 0.2, 0.2}
            local shadow = {0.3, 0, 0}
            
            if self:countRemotePlayers() > 0 and not self.localBoard.gameOver then
                text = "YOU WON!"
                color = {0.2, 1, 0.2}
                shadow = {0, 0.3, 0}
            end
            self:drawText(text, 0, sh/2 - 20, sw, "center", color, shadow)
        end
    end
    
    love.graphics.pop()
end

function Game:countRemotePlayers()
    local count = 0
    for _ in pairs(self.remoteBoards) do count = count + 1 end
    return count
end

function Game:keypressed(key)
    if self.menu:isVisible() then
        if self.menu:keypressed(key) then return end
    end
    
    if key == "m" or key == "tab" or key == "escape" then
        if self.state == self.STATE.PLAYING or self.state == self.STATE.COUNTDOWN or self.state == self.STATE.GAME_OVER then
            if self.menu:isVisible() then
                self.menu:hide()
            else
                self.menu:show(self.menu.STATE.PAUSE)
            end
        else
            -- If we are in WAITING or something else, ESC might mean something else
            if key == "escape" then
                if self.menu:isVisible() then 
                    self.menu:hide() 
                else 
                    love.event.quit() 
                end
            else
                self.menu:show()
            end
        end
    elseif key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen())
    end
    
    -- Map keyboard to Input system
    Input:keyPressed(key)
end

function Game:keyreleased(key)
    Input:keyReleased(key)
end

function Game:gamepadpressed(button)
    if self.menu:isVisible() then
        if self.menu:gamepadpressed(button) then return end
    end
    
    if button == "start" then
        if self.state == self.STATE.PLAYING or self.state == self.STATE.COUNTDOWN or self.state == self.STATE.GAME_OVER then
            if self.menu:isVisible() then
                self.menu:hide()
            else
                self.menu:show(self.menu.STATE.PAUSE)
            end
        end
    end

    Input:gamepadPressed(button)
end

function Game:gamepadreleased(button)
    Input:gamepadReleased(button)
end

function Game:becomeHost()
    if self.network then self.network:disconnect() end
    self.remoteBoards = {}
    self.isHost = true
    self.network = Server:new(12345)

    if not self.network then
        print("Failed to create server, cannot host game")
        self.isHost = false
        return
    end

    self.discovery:startAdvertising("Sirtet", 12345, 4)
    self.state = self.STATE.WAITING
    -- Don't hide menu - stay in waiting screen until opponent joins
end

function Game:stopHosting()
    if not self.isHost then return end
    if self.network then self.network:disconnect(); self.network = nil end
    self.discovery:stopAdvertising()
    self.isHost = false
    self.remoteBoards = {}
    Audio:playMusic('menu')
end

function Game:connectToServer(address, port)
    if self.isHost then return end
    if self.network then self.network:disconnect() end
    self.remoteBoards = {}
    self.discovery:stopAdvertising()
    self.network = Client:new()
    print("Game: Attempting to connect to " .. address .. ":" .. port)
    self.network:connect(address or "localhost", port or 12345)
    self.state = self.STATE.WAITING
    self.connectionTimer = 0 -- Reset connection timer
end

function Game:reset()
    self.localBoard = TetrisBoard:new(10, 20)
    for id, board in pairs(self.remoteBoards) do
        self.remoteBoards[id] = TetrisBoard:new(10, 20)
        self.remoteBoards[id].currentPiece = nil
    end
    self.sentGameOver = false
    self.lastSentScore = 0
    self.lastSentMove = {x=0, y=0, rot=0, type=""}
    
    if self.isHost then
        self:startCountdown()
    else
        self.state = self.STATE.WAITING
        Audio:playMusic('menu')
    end
end

function Game:handleSettingChange(key, value)
    print("Game: Setting changed: " .. key .. " = " .. tostring(value))
    if key == "shader" then
        self.shaderType = value
        if value == "OFF" then
            self.activeShader = nil
        else
            local shaderPath = 'src.shaders.' .. string.lower(value)
            local status, shaderCode = pcall(require, shaderPath)
            if status then
                self.activeShader = love.graphics.newShader(shaderCode)
                -- Send common uniforms if they exist and ARE USED in the shader
                if self.activeShader:hasUniform("inputRes") then
                    self.activeShader:send("inputRes", {320, 240})
                end
                self.hasTimeUniform = self.activeShader:hasUniform("time")
            else
                print("Error loading shader: " .. tostring(shaderCode))
                self.activeShader = nil
            end
        end
    elseif key == "fullscreen" then
        love.window.setFullscreen(value)
    elseif key == "musicVolume" then
        Audio:setMusicVolume(value / 10)
    elseif key == "sfxVolume" then
        Audio:setSFXVolume(value / 10)
    end
end

function Game:returnToMainMenu()
    print("Game: Returning to main menu")
    if self.isHost then
        self:stopHosting()
    elseif self.network then
        self.network:disconnect()
        self.network = nil
    end
    self.remoteBoards = {}
    self.state = self.STATE.WAITING
    Audio:playMusic('menu')
end

function Game:quit()
    if self.network then self.network:disconnect() end
    if self.discovery then self.discovery:close() end
end

return Game

