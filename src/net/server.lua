-- src/net/server.lua
-- Network server for Blockdrop
-- Hosts the game and relays board/piece updates to all clients

local enet = require("enet")
local Protocol = require("src.net.protocol")

local Server = {}
Server.__index = Server

function Server:new(port)
    local self = setmetatable({}, Server)

    self.port = port or 12345

    -- Create server host
    self.host = enet.host_create("*:" .. self.port, 4)

    if not self.host then
        print("ERROR: Failed to create server on port " .. self.port)
        return nil
    end
    
    -- Track connected players
    self.players = {}
    self.nextPlayerId = 1
    self.playerId = "host"
    
    print("=== Blockdrop Server Started ===")
    print("Port: " .. self.port)
    
    return self
end

function Server:disconnect()
    if not self.host then return end
    for peer in pairs(self.players) do
        peer:disconnect_now()
    end
    self.host:flush()
    self.host = nil
    self.players = {}
    print("Server stopped")
end

function Server:broadcast(data, excludePeer, reliable)
    if not self.host then return end
    local flag = reliable and "reliable" or "unreliable"
    for peer in pairs(self.players) do
        if peer ~= excludePeer then
            peer:send(data, 0, flag)
        end
    end
end

function Server:sendBoardSync(gridData)
    if not self.host then return end
    self:broadcast(Protocol.encode(Protocol.MSG.BOARD_SYNC, "host", gridData), nil, true)
end

function Server:sendPieceMove(type, x, y, rot)
    if not self.host then return end
    self:broadcast(Protocol.encode(Protocol.MSG.PIECE_MOVE, "host", type, x, y, rot))
end

function Server:sendMessage(msg)
    if not self.host then return end
    -- Generic message send
    local data
    if msg.type == Protocol.MSG.GARBAGE then
        data = Protocol.encode(msg.type, msg.id or "host", msg.lines or 0)
    else
        data = Protocol.encode(msg.type, msg.id or "host", msg.data or "")
    end
    self:broadcast(data, nil, true)
end

function Server:poll()
    local messages = {}
    if not self.host then return messages end
    
    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            local playerId = "p" .. self.nextPlayerId
            self.nextPlayerId = self.nextPlayerId + 1
            self.players[event.peer] = { id = playerId }

            print("Server: Player " .. playerId .. " connected from " .. tostring(event.peer))

            -- Tell the new player their ID
            local joinMsg = Protocol.encode(Protocol.MSG.PLAYER_JOIN, playerId)
            print("Server: Sending PLAYER_JOIN to new player: " .. joinMsg)
            event.peer:send(joinMsg, 0, "reliable")

            -- Tell everyone else about the new player
            self:broadcast(Protocol.encode(Protocol.MSG.PLAYER_JOIN, playerId), event.peer, true)

            -- Tell the new player about existing players
            event.peer:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, "host"), 0, "reliable")
            for peer, p in pairs(self.players) do
                if peer ~= event.peer then
                    event.peer:send(Protocol.encode(Protocol.MSG.PLAYER_JOIN, p.id), 0, "reliable")
                end
            end

            table.insert(messages, { type = "player_joined", id = playerId })
            
        elseif event.type == "receive" then
            local msg = Protocol.decode(event.data)
            local player = self.players[event.peer]
            
            if player then
                if msg.type == Protocol.MSG.BOARD_SYNC or 
                   msg.type == Protocol.MSG.PIECE_MOVE or 
                   msg.type == Protocol.MSG.GAME_OVER or
                   msg.type == Protocol.MSG.START_COUNTDOWN or
                   msg.type == Protocol.MSG.SCORE_SYNC or
                   msg.type == Protocol.MSG.GARBAGE then
                    -- Relay to others
                    self:broadcast(event.data, event.peer, msg.type ~= Protocol.MSG.PIECE_MOVE)
                    
                    -- Notify host game
                    table.insert(messages, msg)
                end
            end
            
        elseif event.type == "disconnect" then
            local player = self.players[event.peer]
            if player then
                print("Player " .. player.id .. " disconnected")
                self:broadcast(Protocol.encode(Protocol.MSG.PLAYER_LEAVE, player.id), nil, true)
                table.insert(messages, { type = "player_left", id = player.id, disconnectReason = "opponent_left" })
                self.players[event.peer] = nil
            end
        end
        event = self.host:service(0)
    end
    
    return messages
end

return Server

