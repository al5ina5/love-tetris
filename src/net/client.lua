-- src/net/client.lua
-- Network client for Tetris
-- Connects to a server and syncs board/piece updates

local enet = require("enet")
local Protocol = require("src.net.protocol")

local Client = {}
Client.__index = Client

function Client:new()
    local self = setmetatable({}, Client)
    self.host = nil
    self.server = nil
    self.connected = false
    self.playerId = nil
    return self
end

function Client:connect(address, port)
    if self.host then self:disconnect() end
    self.host = enet.host_create()
    if not self.host then
        print("Client: ERROR - Failed to create ENet host")
        return false
    end

    local serverAddress = (address or "127.0.0.1") .. ":" .. (port or 12345)
    self.server = self.host:connect(serverAddress)
    if not self.server then
        print("Client: ERROR - Failed to initiate connection to " .. serverAddress)
        return false
    end
    print("Client: Connecting to " .. serverAddress .. "...")
    return true
end

function Client:disconnect()
    if self.server then
        self.server:disconnect_now()
        self.server = nil
    end
    if self.host then
        self.host:flush()
        self.host = nil
    end
    self.connected = false
    self.playerId = nil
    print("Disconnected from server")
end

function Client:sendBoardSync(gridData)
    if not self.connected or not self.server then return end
    self.server:send(Protocol.encode(Protocol.MSG.BOARD_SYNC, self.playerId or "?", gridData), 0, "reliable")
end

function Client:sendPieceMove(type, x, y, rot)
    if not self.connected or not self.server then return end
    self.server:send(Protocol.encode(Protocol.MSG.PIECE_MOVE, self.playerId or "?", type, x, y, rot), 0, "unreliable")
end

function Client:sendMessage(msg)
    if not self.connected or not self.server then return end
    local data
    if msg.type == Protocol.MSG.GARBAGE then
        data = Protocol.encode(msg.type, self.playerId or "?", msg.lines or 0)
    else
        data = Protocol.encode(msg.type, self.playerId or "?", msg.data or "")
    end
    self.server:send(data, 0, "reliable")
end

function Client:poll()
    local messages = {}
    if not self.host then return messages end

    local event = self.host:service(0)
    while event do
        if event.type == "connect" then
            print("Client: Connected to server!")
            self.connected = true
        elseif event.type == "receive" then
            local msg = Protocol.decode(event.data)
            print("Client: Received message type: " .. msg.type .. " from " .. (msg.id or "?"))
            if msg.type == Protocol.MSG.PLAYER_JOIN and not self.playerId then
                self.playerId = msg.id
                print("Client: Our player ID: " .. self.playerId)
            else
                -- Convert protocol types if needed, or pass through
                if msg.type == Protocol.MSG.PLAYER_JOIN then msg.type = "player_joined"
                elseif msg.type == Protocol.MSG.PLAYER_LEAVE then msg.type = "player_left"
                end
                table.insert(messages, msg)
            end
        elseif event.type == "disconnect" then
            print("Client: Disconnected from server")
            self.connected = false
            self.server = nil
            self.playerId = nil
            table.insert(messages, { type = "player_left", id = "host" })
        end
        event = self.host:service(0)
    end
    return messages
end

return Client

