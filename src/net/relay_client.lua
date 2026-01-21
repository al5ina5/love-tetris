-- src/net/relay_client.lua
-- Real-time online multiplayer client using persistent TCP sockets via Relay
-- Much faster than polling HTTP/REST

local socket = require("socket")
local json = require("src.lib.dkjson")
local Protocol = require("src.net.protocol")
local Constants = require("src.constants")

local RelayClient = {}
RelayClient.__index = RelayClient

function RelayClient:new()
    local self = setmetatable({}, RelayClient)
    self.tcp = nil
    self.roomCode = nil
    self.connected = false
    self.playerId = nil
    self.paired = false -- True when opponent is also connected to relay
    self.buffer = "" -- For handling partial TCP packets
    
    return self
end

function RelayClient:connect(roomCode, playerId)
    self.roomCode = roomCode:upper()
    self.playerId = playerId -- "host" or "client"
    
    print("RelayClient: Connecting to " .. Constants.RELAY_HOST .. ":" .. Constants.RELAY_PORT)
    
    local tcp, err = socket.tcp()
    if not tcp then
        print("RelayClient: Failed to create socket: " .. tostring(err))
        return false
    end
    
    tcp:settimeout(5) -- 5 second timeout for initial connection
    local success, connectErr = tcp:connect(Constants.RELAY_HOST, Constants.RELAY_PORT)
    
    if not success then
        print("RelayClient: Connection failed: " .. tostring(connectErr))
        return false
    end
    
    tcp:settimeout(0) -- Set to non-blocking for gameplay
    tcp:setoption("tcp-nodelay", true) -- Disable Nagle's algorithm for speed
    
    self.tcp = tcp
    self.connected = true
    
    -- Send handshake to the relay
    self.tcp:send("JOIN:" .. self.roomCode .. "\n")
    print("RelayClient: Connected and joined room " .. self.roomCode)
    
    return true
end

function RelayClient:poll()
    if not self.connected or not self.tcp then return {} end
    
    local messages = {}
    local data, err, partial = self.tcp:receive("*a") -- Receive all available data
    
    if err == "closed" then
        print("RelayClient: Connection closed by relay")
        self.connected = false
        return {}
    end
    
    local combinedData = self.buffer .. (data or partial or "")
    self.buffer = ""
    
    -- Split by newline and process messages
    for line in (combinedData .. "\n"):gmatch("(.-)\n") do
        if line == "PAIRED" then
            print("RelayClient: Opponent connected to relay!")
            self.paired = true
        elseif line ~= "" then
            local msg = Protocol.decode(line)
            if msg and msg.id ~= self.playerId then
                -- Translate protocol types to match LAN behavior
                if msg.type == Protocol.MSG.PLAYER_JOIN then 
                    msg.type = "player_joined"
                elseif msg.type == Protocol.MSG.PLAYER_LEAVE then 
                    msg.type = "player_left"
                end
                table.insert(messages, msg)
            end
        end
    end
    
    return messages
end

function RelayClient:send(data)
    if not self.connected or not self.tcp then return false end
    -- Relay protocol expects one message per line
    local success, err = self.tcp:send(data .. "\n")
    if not success then
        print("RelayClient: Send failed: " .. tostring(err))
        if err == "closed" then self.connected = false end
    end
    return success
end

-- Compatible interface with ENet client
function RelayClient:sendBoardSync(gridData)
    return self:send(Protocol.encode(Protocol.MSG.BOARD_SYNC, self.playerId, gridData))
end

function RelayClient:sendPieceMove(type, x, y, rot)
    return self:send(Protocol.encode(Protocol.MSG.PIECE_MOVE, self.playerId, type, x, y, rot))
end

function RelayClient:sendMessage(msg)
    local encoded
    if msg.type == Protocol.MSG.GARBAGE then
        encoded = Protocol.encode(msg.type, self.playerId, msg.lines or 0)
    else
        encoded = Protocol.encode(msg.type, self.playerId, msg.data or "")
    end
    return self:send(encoded)
end

function RelayClient:disconnect()
    if self.tcp then
        self.tcp:close()
        self.tcp = nil
    end
    self.connected = false
    self.roomCode = nil
    self.paired = false
    print("RelayClient: Disconnected")
end

return RelayClient
