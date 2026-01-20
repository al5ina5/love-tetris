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
    
    self.fonts = {
        small = love.graphics.newFont(10),
        medium = love.graphics.newFont(12),
        large = love.graphics.newFont(60)
    }
    
    self.discovery = Discovery:new()
    self.menu = Menu:new(self.discovery)
    Audio:init()
    self.menu.onHost = function() self:becomeHost() end
    self.menu.onStopHost = function() self:stopHosting() end
    self.menu.onJoin = function(ip, port) self:connectToServer(ip, port) end
    self.menu.onCancel = function()
        if self.network and not self.isHost then
            print("Game: Cancelling client connection")
            self.network:disconnect()
            self.network = nil
            self.connectionTimer = 0
        end
    end

    -- Start with menu visible
    self.menu:show()
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

    -- Playing State Logic
    if self.state == self.STATE.PLAYING then
        -- Check if anyone lost
        local anyGameOver = self.localBoard.gameOver
        for _, board in pairs(self.remoteBoards) do
            if board.gameOver then anyGameOver = true; break end
        end

        if anyGameOver then
            self.state = self.STATE.GAME_OVER
            self.gameOverTimer = 3.0
            return
        end

        local moved = false
        local rotated = false
        
        if Input:wasPressed("left") then 
            local m = self.localBoard:move(-1, 0)
            if m then Audio:play('move') end
            moved = m or moved
        end
        if Input:wasPressed("right") then 
            local m = self.localBoard:move(1, 0)
            if m then Audio:play('move') end
            moved = m or moved
        end
        if Input:wasPressed("down") then 
            local m = self.localBoard:move(0, 1)
            if m then Audio:play('move') end
            moved = m or moved
        end
        if Input:wasPressed("up") then 
            rotated = self.localBoard:rotate()
            if rotated then Audio:play('rotate') end
        end
        if Input:wasPressed("space") then
            -- Simple hard drop
            while self.localBoard:move(0, 1) do 
            end
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

    Input:update()
end

function Game:startCountdown()
    self.state = self.STATE.COUNTDOWN
    self.countdownTimer = 3.0
    Audio:play('beep')
    if self.network then
        self.network:sendMessage({type = Protocol.MSG.START_COUNTDOWN})
    end
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

function Game:draw()
    local sw, sh = love.graphics.getDimensions()
    local hasOpponents = self:countRemotePlayers() > 0
    
    -- Maximize board size to use vertical space, leaving room for score and padding
    local bs = math.floor((sh - 80) / 20)
    local bw, bh = 10 * bs, 20 * bs
    
    if not hasOpponents then
        -- Centered layout for solo play/waiting
        local bx, by = (sw - bw) / 2, (sh - bh) / 2 + 15 -- Offset down for score
        
        self.localBoard:draw(bx, by, bs)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(self.fonts.medium)
        love.graphics.printf("YOU: " .. self.localBoard.score, 0, by - 25, sw, "center")
        
        if self.state == self.STATE.WAITING then
            love.graphics.printf("WAITING FOR OPPONENT...", 0, by + bh + 10, sw, "center")
        end
    else
        -- 50/50 Screen Layout
        -- Left half (YOU)
        local lx = (sw / 2 - bw) / 2
        local ly = (sh - bh) / 2 + 15
        self.localBoard:draw(lx, ly, bs)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(self.fonts.small)
        love.graphics.printf("YOU: " .. self.localBoard.score, 0, ly - 20, sw / 2, "center")
        
        -- Right half (OPPONENT)
        local count = 0
        local remoteCount = self:countRemotePlayers()
        local opponentColor = {0.5, 0.5, 0.5}
        for id, board in pairs(self.remoteBoards) do
            if count == 0 then
                -- Primary opponent
                local rx = sw / 2 + (sw / 2 - bw) / 2
                local ry = (sh - bh) / 2 + 15
                board:draw(rx, ry, bs, opponentColor)
                love.graphics.printf("OPPONENT: " .. (board.score or 0), sw / 2, ry - 20, sw / 2, "center")
            else
                -- Small previews for additional players if they exist
                -- Stack them on the right side if there's space
                local miniBs = math.floor(bs / 2)
                local miniBw, miniBh = 10 * miniBs, 20 * miniBs
                local ex = sw - miniBw - 10
                local ey = 10 + (count - 1) * (miniBh + 20)
                board:draw(ex, ey, miniBs, opponentColor)
            end
            count = count + 1
        end
        
        -- Vertical divider
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.line(sw / 2, 0, sw / 2, sh)
    end
    
    -- Overlay for Countdown
    if self.state == self.STATE.COUNTDOWN then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(self.fonts.large)
        local text = math.ceil(self.countdownTimer)
        if text == 0 then text = "GO!" end
        love.graphics.printf(tostring(text), 0, sh/2 - 30, sw, "center")
    end
    
    -- Menu (always on top)
    self.menu:draw()
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
    
    if key == "m" or key == "tab" then
        self.menu:show()
    elseif key == "f" then
        love.window.setFullscreen(not love.window.getFullscreen())
    elseif key == "escape" then
        if self.menu:isVisible() then self.menu:hide() else love.event.quit() end
    end
    
    -- Map keyboard to Input system
    Input:keyPressed(key)
end

function Game:gamepadpressed(button)
    -- Handle gamepad if needed, but for now just keyboard
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
    end
end

function Game:quit()
    if self.network then self.network:disconnect() end
    if self.discovery then self.discovery:close() end
end

return Game

