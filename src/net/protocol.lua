-- src/net/protocol.lua
-- Network message protocol for Tetris
-- Defines how messages are serialized/deserialized

local Protocol = {}

-- Message types
Protocol.MSG = {
    PLAYER_JOIN = "join",     -- New player connected
    PLAYER_LEAVE = "leave",   -- Player disconnected
    BOARD_SYNC = "board",     -- Full board state sync
    PIECE_MOVE = "move",     -- Current piece position/type update
    GAME_OVER = "over",       -- Player topped out
    START_COUNTDOWN = "scd",  -- Start the 3-2-1 timer
    SCORE_SYNC = "score",     -- Sync player score
    PING = "ping",            -- Latency check
    PONG = "pong",            -- Latency response
}

-- Serialize a message to string
function Protocol.encode(msgType, ...)
    local parts = {msgType}
    for _, v in ipairs({...}) do
        table.insert(parts, tostring(v))
    end
    return table.concat(parts, "|")
end

-- Deserialize a string back to a message table
function Protocol.decode(data)
    local parts = {}
    for part in string.gmatch(data, "[^|]+") do
        table.insert(parts, part)
    end
    
    local msgType = parts[1]
    local msg = { type = msgType, raw = data }
    
    if msgType == Protocol.MSG.PLAYER_JOIN then
        msg.id = parts[2]
        
    elseif msgType == Protocol.MSG.PLAYER_LEAVE then
        msg.id = parts[2]
        
    elseif msgType == Protocol.MSG.BOARD_SYNC then
        msg.id = parts[2]
        msg.gridData = parts[3] -- Expecting a string of color indices or similar
        
    elseif msgType == Protocol.MSG.PIECE_MOVE then
        msg.id = parts[2]
        msg.pieceType = parts[3]
        msg.x = tonumber(parts[4]) or 0
        msg.y = tonumber(parts[5]) or 0
        msg.rotation = tonumber(parts[6]) or 0
        
    elseif msgType == Protocol.MSG.GAME_OVER then
        msg.id = parts[2]
        
    elseif msgType == Protocol.MSG.SCORE_SYNC then
        msg.id = parts[2]
        msg.score = tonumber(parts[3]) or 0

    elseif msgType == Protocol.MSG.PING then
        msg.timestamp = tonumber(parts[2]) or 0
        
    elseif msgType == Protocol.MSG.PONG then
        msg.timestamp = tonumber(parts[2]) or 0
    end
    
    return msg
end

return Protocol

