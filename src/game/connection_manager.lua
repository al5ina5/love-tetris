-- src/game/connection_manager.lua
-- Manages network connections, hosting, and joining

local Client = require('src.net.client')
local Server = require('src.net.server')
local OnlineClient = require('src.net.online_client')
local RelayClient = require('src.net.relay_client')
local NetworkAdapter = require('src.net.network_adapter')
local Audio = require('src.audio')

local ConnectionManager = {}

function ConnectionManager.create()
    return {
        connectionTimer = 0,
        connectionTimeout = 10.0,
        heartbeatTimer = 0,
        heartbeatInterval = 30.0,
        onlineClient = nil
    }
end

function ConnectionManager.becomeHost(game)
    if game.network then game.network:disconnect() end
    game.remoteBoards = {}
    game.isHost = true
    game.network = Server:new(12345)

    if not game.network then
        print("Connection: Failed to create server")
        game.isHost = false
        return
    end

    game.discovery:startAdvertising("Sirtet", 12345, 4)
    game.stateManager.current = "waiting"
end

function ConnectionManager.stopHosting(game)
    if not game.isHost then return end
    if game.network then
        game.network:disconnect()
        game.network = nil
    end
    game.discovery:stopAdvertising()
    game.isHost = false
    game.remoteBoards = {}
    Audio:playMusic('menu')
end

function ConnectionManager.connectToServer(address, port, game)
    if game.isHost then return end
    if game.network then game.network:disconnect() end
    game.remoteBoards = {}
    game.discovery:stopAdvertising()
    game.network = Client:new()
    print("Connection: Attempting to connect to " .. address .. ":" .. port)
    game.network:connect(address or "localhost", port or 12345)
    game.stateManager.current = "waiting"
    game.connectionManager.connectionTimer = 0
end

function ConnectionManager.update(dt, game)
    local cm = game.connectionManager
    
    -- Check for successful client connection (LAN)
    if game.network and game.network.type == nil and not game.playerId and game.network.playerId then
        game.playerId = game.network.playerId
        print("Connection: Client connected with playerId: " .. game.playerId)
        if not game.isHost then
            game.menu:hide()
            cm.connectionTimer = 0
        end
    elseif game.network and game.network.type == nil and not game.isHost and not game.playerId then
        -- Client is trying to connect, check for timeout
        cm.connectionTimer = cm.connectionTimer + dt
        if math.floor(cm.connectionTimer) % 2 == 0 and math.floor(cm.connectionTimer) ~= math.floor(cm.connectionTimer - dt) then
            print("Connection: Still connecting... " .. string.format("%.1f", cm.connectionTimer) .. "/" .. cm.connectionTimeout .. "s")
        end
        if cm.connectionTimer >= cm.connectionTimeout then
            print("Connection: Timeout after " .. cm.connectionTimeout .. " seconds")
            if game.network then
                game.network:disconnect()
                game.network = nil
            end
            game.stateManager.current = "waiting"
            game.menu:show()
            cm.connectionTimer = 0
        end
    end
    
    -- Update discovery player count if host (LAN only)
    if game.isHost and game.network and game.network.type == nil then
        game.discovery:setPlayerCount(1 + game:countRemotePlayers())
    end
    
    -- Online-specific updates
    ConnectionManager.updateOnline(dt, game)
end

function ConnectionManager.returnToMainMenu(game)
    print("Connection: Returning to main menu")
    
    -- Clean up LAN hosting
    if game.isHost then
        ConnectionManager.stopHosting(game)
    end
    
    -- Clean up network connection
    if game.network then
        if game.network.disconnect then
            game.network:disconnect()
        end
        game.network = nil
    end
    
    -- Clean up online client
    if game.connectionManager.onlineClient then
        if game.connectionManager.onlineClient.disconnect then
            game.connectionManager.onlineClient:disconnect()
        end
        game.connectionManager.onlineClient = nil
    end
    
    -- Reset all game state
    game.remoteBoards = {}
    game.playerId = nil
    game.isHost = false
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = {x=0, y=0, rot=0, type=""}
    
    -- Reset state manager
    game.stateManager.current = "waiting"
    game.stateManager.disconnectReason = nil
    game.stateManager.disconnectPauseTimer = 0
    
    -- Reset connection manager timers
    game.connectionManager.connectionTimer = 0
    game.connectionManager.heartbeatTimer = 0
    
    Audio:playMusic('menu')
end

-- Online multiplayer functions

function ConnectionManager.hostOnline(isPublic, game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return false
    end
    
    print("Connection: Creating online room (public: " .. tostring(isPublic) .. ")")
    
    local success, onlineClient = pcall(OnlineClient.new, OnlineClient)
    if not success then
        print("Connection: Failed to initialize online client: " .. tostring(onlineClient))
        game.menu.onlineError = "Failed to initialize online client"
        return false
    end
    
    local roomSuccess, roomCode = onlineClient:createRoom(isPublic)
    
    if not roomSuccess then
        print("Connection: Failed to create online room")
        game.menu.state = game.menu.STATE.ONLINE_HOST
        return false
    end
    
    print("Connection: Online room created with code: " .. roomCode)
    
    -- Setup relay client (Socket)
    local relayClient = RelayClient:new()
    if not relayClient:connect(roomCode, "host") then
        print("Connection: Failed to connect to relay server")
        game.menu.onlineError = "Failed to connect to real-time relay server.\nCheck your internet connection."
        return false
    end

    -- Setup network adapter
    game.network = NetworkAdapter:createRelay(relayClient)
    game.isHost = true
    game.playerId = "host"
    game.connectionManager.onlineClient = onlineClient -- Keep for heartbeat
    
    -- Show waiting screen with room code
    game.menu.onlineRoomCode = roomCode
    game.menu.state = game.menu.STATE.ONLINE_WAITING
    game.stateManager.current = "waiting"
    
    return true
end

function ConnectionManager.joinOnline(roomCode, game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return false
    end
    
    print("Connection: Joining online room " .. roomCode)
    
    local success, onlineClient = pcall(OnlineClient.new, OnlineClient)
    if not success then
        print("Connection: Failed to initialize online client: " .. tostring(onlineClient))
        game.menu.onlineError = "Failed to initialize online client"
        return false
    end
    
    local joinSuccess, error = onlineClient:joinRoom(roomCode)
    
    if not joinSuccess then
        print("Connection: Failed to join online room: " .. tostring(error))
        game.menu.onlineError = "Failed to join room: " .. tostring(error)
        return false
    end
    
    print("Connection: Successfully joined online room")
    
    -- Setup relay client (Socket)
    local relayClient = RelayClient:new()
    if not relayClient:connect(roomCode, "client") then
        print("Connection: Failed to connect to relay server")
        game.menu.onlineError = "Failed to connect to real-time relay server."
        return false
    end

    -- Setup network adapter
    game.network = NetworkAdapter:createRelay(relayClient)
    game.isHost = false
    game.playerId = "client"
    game.connectionManager.onlineClient = onlineClient
    
    -- Notify relay we are ready
    local Protocol = require('src.net.protocol')
    relayClient:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, "client"))
    
    -- Switch menu to connecting state instead of hiding immediately
    -- This prevents the solo-flash and looks more professional
    local Base = require('src.ui.menu.base')
    game.menu.state = Base.STATE.CONNECTING
    game.stateManager.current = "waiting"
    
    return true
end

function ConnectionManager.refreshOnlineRooms(game)
    if not OnlineClient.isAvailable() then
        print("Connection: Online multiplayer not available (HTTPS support not found)")
        game.menu.onlineRooms = {}
        game.menu.onlineError = "Online multiplayer requires HTTPS support.\nPlease use LAN multiplayer instead."
        return
    end
    
    print("Connection: Refreshing online rooms list")
    
    local success, onlineClient = pcall(OnlineClient.new, OnlineClient)
    if not success then
        print("Connection: Failed to initialize online client: " .. tostring(onlineClient))
        game.menu.onlineRooms = {}
        game.menu.onlineError = "Failed to initialize online client"
        return
    end
    
    local rooms = onlineClient:listRooms()
    
    print("Connection: Found " .. #rooms .. " online rooms")
    game.menu.onlineRooms = rooms
end

function ConnectionManager.updateOnline(dt, game)
    local cm = game.connectionManager
    
    -- Send periodic heartbeat if hosting online
    if cm.onlineClient and game.isHost then
        cm.heartbeatTimer = cm.heartbeatTimer + dt
        if cm.heartbeatTimer >= cm.heartbeatInterval then
            cm.onlineClient:heartbeat()
            cm.heartbeatTimer = 0
        end
    end

    -- Send periodic PING to measure latency
    if game.network and game.state == "waiting" then
        game.pingTimer = game.pingTimer + dt
        if game.pingTimer >= 2.0 then -- Every 2 seconds
            local Protocol = require('src.net.protocol')
            game.network:sendMessage({
                type = Protocol.MSG.PING,
                data = tostring(love.timer.getTime())
            })
            game.pingTimer = 0
        end
    end
end

return ConnectionManager
