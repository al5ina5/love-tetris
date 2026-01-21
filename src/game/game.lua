-- src/game/game.lua
-- Main game coordinator - ties together all game modules

local TetrisBoard = require('src.tetris.board')
local Input = require('src.input.input_state')
local Discovery = require('src.net.discovery')
local Menu = require('src.ui.menu')
local Audio = require('src.audio')
local FX = require('src.fx')
local Controls = require('src.input.controls')
local Settings = require('src.data.settings')
local Scores = require('src.data.scores')

local Renderer = require('src.game.renderer')
local StateManager = require('src.game.state_manager')
local InputHandler = require('src.game.input_handler')
local NetworkHandler = require('src.game.network_handler')
local SettingsHandler = require('src.game.settings_handler')
local ConnectionManager = require('src.game.connection_manager')

local Game = {
    isHost = false,
    localBoard = nil,
    remoteBoards = {},
    network = nil,
    discovery = nil,
    menu = nil,
    playerId = nil,
    lastSentMove = {x=0, y=0, rot=0, type=""},
    lastSentScore = 0,
    sentGameOver = false,
    gameMode = "VERSUS", -- "VERSUS" or "SPRINT"
    sprintTime = 0,
    
    -- Sub-modules
    renderer = nil,
    stateManager = nil,
    connectionManager = nil,
    latency = 0,
    pingTimer = 0
}

-- Expose state for convenience
function Game:getState()
    return self.stateManager.current
end

-- Setter for cleaner API
function Game:setState(newState)
    self.stateManager.current = newState
end

-- Backwards compatibility property (getter)
setmetatable(Game, {
    __index = function(t, k)
        if k == "state" then
            return rawget(t, "stateManager") and rawget(t, "stateManager").current
        end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        if k == "state" then
            if rawget(t, "stateManager") then
                rawget(t, "stateManager").current = v
            end
        else
            rawset(t, k, v)
        end
    end
})

function Game:load()
    local savedSettings = Settings.load()
    
    -- Initialize controls
    Controls.load(savedSettings.controls)
    
    -- Initialize sub-modules
    self.renderer = Renderer.init()
    self.stateManager = StateManager.create()
    self.connectionManager = ConnectionManager.create()
    
    self.localBoard = TetrisBoard:new(10, 20)
    self.remoteBoards = {}
    self.network = nil
    self.isHost = false
    self.playerId = nil
    self.sentGameOver = false
    
    self.discovery = Discovery:new()
    self.menu = Menu:new(self.discovery, self.renderer.fonts)
    
    Scores.load()

    -- Sync menu settings with saved settings
    for k, v in pairs(savedSettings) do
        self.menu.settings[k] = v
    end
    if savedSettings.lastIP then
        self.menu:setIPFromText(savedSettings.lastIP)
    end

    Audio:init()
    
    -- Setup menu callbacks
    self.menu.onHost = function() ConnectionManager.becomeHost(self) end
    self.menu.onStopHost = function() ConnectionManager.stopHosting(self) end
    self.menu.onStartAlone = function() self:startAlone() end
    self.menu.onJoin = function(ip, port) ConnectionManager.connectToServer(ip, port, self) end
    self.menu.onMainMenu = function() ConnectionManager.returnToMainMenu(self) end
    self.menu.onSettingChanged = function(key, value)
        SettingsHandler.handleChange(key, value, self, self.renderer)
    end
    self.menu.onControlsChanged = function()
        SettingsHandler.handleControlsChange(self)
    end
    self.menu.onCancel = function()
        print("Game: Cancel requested")
        
        -- Handle online multiplayer cleanup
        if self.connectionManager.onlineClient then
            print("Game: Disconnecting online client")
            if self.connectionManager.onlineClient.disconnect then
                self.connectionManager.onlineClient:disconnect()
            end
            self.connectionManager.onlineClient = nil
        end
        
        -- Handle regular network cleanup
        if self.network then
            print("Game: Disconnecting network")
            if self.network.disconnect then
                self.network:disconnect()
            end
            self.network = nil
        end
        
        -- Reset state
        self.isHost = false
        self.playerId = nil
        self.remoteBoards = {}
        self.connectionManager.connectionTimer = 0
        self.stateManager.current = "waiting"
        Audio:playMusic('menu')
    end
    -- Online multiplayer callbacks
    self.menu.onHostOnline = function(isPublic)
        ConnectionManager.hostOnline(isPublic, self)
    end
    self.menu.onJoinOnline = function(roomCode)
        ConnectionManager.joinOnline(roomCode, self)
    end
    self.menu.onRefreshOnlineRooms = function()
        ConnectionManager.refreshOnlineRooms(self)
    end
    
    -- Apply initial settings
    SettingsHandler.handleChange("shader", self.menu.settings.shader, self, self.renderer)
    SettingsHandler.handleChange("musicVolume", self.menu.settings.musicVolume, self, self.renderer)
    SettingsHandler.handleChange("sfxVolume", self.menu.settings.sfxVolume, self, self.renderer)
    SettingsHandler.handleChange("fullscreen", self.menu.settings.fullscreen, self, self.renderer)
    SettingsHandler.handleChange("ghost", self.menu.settings.ghost, self, self.renderer)
    
    self.menu:show()
    Audio:playMusic('menu')
end

function Game:update(dt)
    self.discovery:update(dt)
    FX:update(dt)
    
    -- ALWAYS poll network messages
    if self.network then
        local messages = self.network:poll()
        for _, msg in ipairs(messages) do
            NetworkHandler.handleMessage(msg, self)
        end
    end

    -- Update connection manager
    ConnectionManager.update(dt, self)
    
    -- State machine updates (run even when menu visible for waiting state)
    StateManager.update(self.stateManager, dt, self)

    if self.menu:isVisible() then
        self.menu:update(dt)
        return
    end

    if self.stateManager.current == StateManager.STATES.DISCONNECTED_PAUSE then
        return -- Skip normal game logic while paused
    end

    -- Update input timers
    Input:update(dt)

    -- Playing state logic
    if self.stateManager.current == StateManager.STATES.PLAYING then
        self:updatePlaying(dt)
    end

    Input:postUpdate()
end

function Game:updatePlaying(dt)
    local moved = false
    local rotated = false
    
    -- Movement input
    if Controls.shouldActionRepeat("move_left", Input) then
        local m = self.localBoard:move(-1, 0)
        if m then Audio:play('move') end
        moved = m or moved
    end
    if Controls.shouldActionRepeat("move_right", Input) then
        local m = self.localBoard:move(1, 0)
        if m then Audio:play('move') end
        moved = m or moved
    end
    if Controls.shouldActionRepeat("move_down", Input) then
        local m = self.localBoard:move(0, 1)
        if m then
            Audio:play('move')
            self.localBoard.score = self.localBoard.score + 1
        end
        moved = m or moved
    end
    
    -- Hard drop
    if Controls.isActionPressed("hard_drop", Input) then
        local dropDistance = 0
        while self.localBoard:move(0, 1) do
            dropDistance = dropDistance + 1
        end
        self.localBoard.score = self.localBoard.score + (dropDistance * 2)
        self.localBoard:lockPiece()
        moved = true
    end
    
    -- Rotation
    if Controls.isActionPressed("rotate_cw", Input) then
        rotated = self.localBoard:rotate(false)
        if rotated then Audio:play('rotate') end
    end
    if Controls.isActionPressed("rotate_ccw", Input) then
        rotated = self.localBoard:rotate(true)
        if rotated then Audio:play('rotate') end
    end
    
    -- Hold
    if Controls.isActionPressed("hold", Input) then
        if self.localBoard:hold() then
            Audio:play('rotate')
            moved = true
        end
    end

    local autoMoved = self.localBoard:update(dt)

    -- Sync network state
    if moved or rotated or autoMoved then
        NetworkHandler.syncLocalState(self)
    end

    -- Handle garbage sending
    if self.localBoard.garbageToNotify then
        NetworkHandler.sendGarbage(self, self.localBoard.garbageToNotify)
        self.localBoard.garbageToNotify = nil
    end
    
    -- Sync score
    NetworkHandler.syncScore(self)
end

function Game:startAlone()
    print("Game: Starting alone")
    self.menu:hide()
    StateManager.startCountdown(self.stateManager, self)
end

function Game:draw()
    Renderer.draw(self.renderer, self)
end

function Game:drawText(text, x, y, limit, align, color, shadowColor, outlineColor)
    Renderer.drawText(text, x, y, limit, align, color, shadowColor, outlineColor, self.renderer.fonts)
end

function Game:countRemotePlayers()
    local count = 0
    for _ in pairs(self.remoteBoards) do count = count + 1 end
    return count
end

function Game:keypressed(key)
    InputHandler.keypressed(key, self)
end

function Game:keyreleased(key)
    InputHandler.keyreleased(key, self)
end

function Game:gamepadpressed(button)
    InputHandler.gamepadpressed(button, self)
end

function Game:gamepadreleased(button)
    InputHandler.gamepadreleased(button, self)
end

function Game:quit()
    if self.network then self.network:disconnect() end
    if self.discovery then self.discovery:close() end
end

return Game
