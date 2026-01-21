-- src/net/online_client.lua
-- Online multiplayer client using Ably via REST API
-- Supports both lua-sec (preferred) and system commands (curl/wget) as fallback

local json = require("src.lib.dkjson")
local Protocol = require("src.net.protocol")
local Constants = require("src.constants")

-- Try to load HTTPS support (lua-sec - preferred method)
local https
local ltn12
local hasLuaSec = pcall(function()
    https = require("ssl.https")
    ltn12 = require("ltn12")
end)

-- Fallback: Try simple HTTP (curl/wget)
local SimpleHTTP
local hasSimpleHTTP = false
if not hasLuaSec then
    local success, module = pcall(require, "src.net.simple_http")
    if success then
        SimpleHTTP = module
        hasSimpleHTTP = SimpleHTTP.isAvailable()
    end
end

local OnlineClient = {}
OnlineClient.__index = OnlineClient

-- Check if online multiplayer is available
function OnlineClient.isAvailable()
    return hasLuaSec or hasSimpleHTTP
end

-- Get method name for logging
function OnlineClient.getMethod()
    if hasLuaSec then
        return "lua-sec"
    elseif hasSimpleHTTP then
        local _, method = SimpleHTTP.isAvailable()
        return method or "simple_http"
    end
    return "none"
end

function OnlineClient:new()
    if not OnlineClient.isAvailable() then
        error("Online multiplayer requires HTTPS support (install lua-sec or ensure curl/wget is available)")
    end
    
    local self = setmetatable({}, OnlineClient)
    self.roomCode = nil
    self.channelName = nil
    self.ablyToken = nil
    self.connected = false
    self.playerId = nil
    self.lastMessageTime = 0
    self.messageHistory = {}
    self.apiUrl = Constants.API_BASE_URL
    self.httpMethod = hasLuaSec and "luasec" or "simple"
    
    print("OnlineClient: Using " .. OnlineClient.getMethod() .. " for HTTPS")
    
    return self
end

-- Helper: Make HTTP request (lua-sec version)
function OnlineClient:httpRequestLuaSec(method, url, body)
    local response = {}
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = body and tostring(#body) or "0"
    }
    
    local request = {
        url = url,
        method = method,
        headers = headers,
        source = body and ltn12.source.string(body) or nil,
        sink = ltn12.sink.table(response)
    }
    
    local ok, code, responseHeaders = https.request(request)
    
    if not ok then
        return false, "Request failed: " .. tostring(code)
    end
    
    local responseBody = table.concat(response)
    
    if code >= 200 and code < 300 then
        local success, data = pcall(json.decode, responseBody)
        if success then
            return true, data
        else
            return false, "Failed to parse JSON response"
        end
    else
        return false, "HTTP " .. code .. ": " .. responseBody
    end
end

-- Helper: Make HTTP request (uses appropriate method)
function OnlineClient:httpRequest(method, url, body)
    if self.httpMethod == "luasec" then
        return self:httpRequestLuaSec(method, url, body)
    else
        -- Use simple HTTP (curl/wget)
        return SimpleHTTP.request(method, url, body)
    end
end

-- Create a new room
function OnlineClient:createRoom(isPublic)
    local body = json.encode({
        isPublic = isPublic or false
    })
    
    local success, response = self:httpRequest(
        "POST",
        self.apiUrl .. "/api/create-room",
        body
    )
    
    if not success then
        print("OnlineClient: Failed to create room: " .. tostring(response))
        return false
    end
    
    self.roomCode = response.roomCode
    self.connected = true
    
    print("OnlineClient: Room created: " .. self.roomCode)
    return true, self.roomCode
end

-- Join an existing room
function OnlineClient:joinRoom(roomCode)
    local body = json.encode({
        roomCode = roomCode:upper()
    })
    
    local success, response = self:httpRequest(
        "POST",
        self.apiUrl .. "/api/join-room",
        body
    )
    
    if not success then
        print("OnlineClient: Failed to join room: " .. tostring(response))
        return false, response
    end
    
    self.roomCode = roomCode:upper()
    self.connected = true
    
    print("OnlineClient: Joined room: " .. self.roomCode)
    return true
end

-- List public rooms
function OnlineClient:listRooms()
    local success, response = self:httpRequest(
        "GET",
        self.apiUrl .. "/api/list-rooms",
        nil
    )
    
    if not success then
        print("OnlineClient: Failed to list rooms: " .. tostring(response))
        return {}
    end
    
    return response.rooms or {}
end

-- Send heartbeat to keep room alive
function OnlineClient:heartbeat()
    if not self.roomCode then return false end
    
    local body = json.encode({
        roomCode = self.roomCode
    })
    
    local success, response = self:httpRequest(
        "POST",
        self.apiUrl .. "/api/heartbeat",
        body
    )
    
    return success
end

-- Publish a message to Ably (lua-sec version)
function OnlineClient:publishLuaSec(messageType, ...)
    local data = Protocol.encode(messageType, self.playerId, ...)
    
    local body = json.encode({
        name = "game_message",
        data = data
    })
    
    local url = string.format(
        "https://rest.ably.io/channels/%s/messages",
        self.channelName:gsub(":", "%%3A")
    )
    
    local response = {}
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. self.ablyToken,
        ["Content-Length"] = tostring(#body)
    }
    
    local request = {
        url = url,
        method = "POST",
        headers = headers,
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response)
    }
    
    local ok, code = https.request(request)
    
    if not ok or code >= 400 then
        print("OnlineClient: Failed to publish message, code: " .. tostring(code))
        return false
    end
    
    return true
end

-- Publish a message to Ably (curl version)
function OnlineClient:publishCurl(messageType, ...)
    local data = Protocol.encode(messageType, self.playerId, ...)
    
    local body = json.encode({
        name = "game_message",
        data = data
    })
    
    local url = string.format(
        "https://rest.ably.io/channels/%s/messages",
        self.channelName:gsub(":", "%%3A")
    )
    
    -- Use SimpleHTTP but with custom headers for Authorization
    local tempFile = os.tmpname()
    local tempStatusFile = os.tmpname()
    local tempBodyFile = os.tmpname()
    
    local f = io.open(tempBodyFile, "w")
    f:write(body)
    f:close()
    
    local cmd = string.format(
        "curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer %s' -d @%s '%s' -o %s -w '%%{http_code}' > %s 2>/dev/null",
        self.ablyToken, tempBodyFile, url, tempFile, tempStatusFile
    )
    
    os.execute(cmd)
    
    -- Read status
    local statusFile = io.open(tempStatusFile, "r")
    local httpCode = statusFile and statusFile:read("*a"):match("(%d+)") or "500"
    if statusFile then statusFile:close() end
    
    -- Cleanup
    os.remove(tempFile)
    os.remove(tempStatusFile)
    os.remove(tempBodyFile)
    
    local code = tonumber(httpCode) or 500
    if code >= 400 then
        print("OnlineClient: Failed to publish message, code: " .. tostring(code))
        return false
    end
    
    return true
end

-- Publish a message to Ably
function OnlineClient:publish(messageType, ...)
    if not self.connected or not self.channelName or not self.ablyToken then
        return false
    end
    
    if self.httpMethod == "luasec" then
        return self:publishLuaSec(messageType, ...)
    else
        return self:publishCurl(messageType, ...)
    end
end

-- Poll for new messages from Ably (lua-sec version)
function OnlineClient:pollLuaSec()
    local messages = {}
    
    local url = string.format(
        "https://rest.ably.io/channels/%s/messages?limit=100&start=%d",
        self.channelName:gsub(":", "%%3A"),
        self.lastMessageTime
    )
    
    local response = {}
    local headers = {
        ["Authorization"] = "Bearer " .. self.ablyToken
    }
    
    local request = {
        url = url,
        method = "GET",
        headers = headers,
        sink = ltn12.sink.table(response)
    }
    
    local ok, code = https.request(request)
    
    if not ok or code >= 400 then
        return messages
    end
    
    local responseBody = table.concat(response)
    local success, data = pcall(json.decode, responseBody)
    
    if not success or not data or not data.items then
        return messages
    end
    
    -- Process messages
    for _, item in ipairs(data.items) do
        if item.data and item.id then
            local msg = Protocol.decode(item.data)
            print("OnlineClient: Received message type=" .. tostring(msg.type) .. " from=" .. tostring(msg.id) .. " self=" .. tostring(self.playerId))
            if msg.id ~= self.playerId then
                -- Translate protocol types to match LAN behavior
                if msg.type == Protocol.MSG.PLAYER_JOIN then 
                    print("OnlineClient: Translating 'join' to 'player_joined'")
                    msg.type = "player_joined"
                elseif msg.type == Protocol.MSG.PLAYER_LEAVE then 
                    msg.type = "player_left"
                end
                table.insert(messages, msg)
            else
                print("OnlineClient: Ignoring message from self")
            end
            
            if item.timestamp and item.timestamp > self.lastMessageTime then
                self.lastMessageTime = item.timestamp
            end
        end
    end
    
    if #messages > 0 then
        print("OnlineClient: Returning " .. #messages .. " messages")
    end
    
    return messages
end

-- Poll for new messages from Ably (curl version)
function OnlineClient:pollCurl()
    local messages = {}
    
    local url = string.format(
        "https://rest.ably.io/channels/%s/messages?limit=100&start=%d",
        self.channelName:gsub(":", "%%3A"),
        self.lastMessageTime
    )
    
    local tempFile = os.tmpname()
    
    local cmd = string.format(
        "curl -s -H 'Authorization: Bearer %s' '%s' -o %s 2>/dev/null",
        self.ablyToken, url, tempFile
    )
    
    os.execute(cmd)
    
    local f = io.open(tempFile, "r")
    if not f then
        os.remove(tempFile)
        return messages
    end
    
    local responseBody = f:read("*a")
    f:close()
    os.remove(tempFile)
    
    local success, data = pcall(json.decode, responseBody)
    
    if not success or not data or not data.items then
        return messages
    end
    
    -- Process messages
    for _, item in ipairs(data.items) do
        if item.data and item.id then
            local msg = Protocol.decode(item.data)
            print("OnlineClient: Received message type=" .. tostring(msg.type) .. " from=" .. tostring(msg.id) .. " self=" .. tostring(self.playerId))
            if msg.id ~= self.playerId then
                -- Translate protocol types to match LAN behavior
                if msg.type == Protocol.MSG.PLAYER_JOIN then 
                    print("OnlineClient: Translating 'join' to 'player_joined'")
                    msg.type = "player_joined"
                elseif msg.type == Protocol.MSG.PLAYER_LEAVE then 
                    msg.type = "player_left"
                end
                table.insert(messages, msg)
            else
                print("OnlineClient: Ignoring message from self")
            end
            
            if item.timestamp and item.timestamp > self.lastMessageTime then
                self.lastMessageTime = item.timestamp
            end
        end
    end
    
    if #messages > 0 then
        print("OnlineClient: Returning " .. #messages .. " messages")
    end
    
    return messages
end

-- Poll for new messages from Ably
function OnlineClient:poll()
    local messages = {}
    
    if not self.connected or not self.channelName or not self.ablyToken then
        return messages
    end
    
    if self.httpMethod == "luasec" then
        return self:pollLuaSec()
    else
        return self:pollCurl()
    end
end

-- Compatible interface with ENet client
function OnlineClient:sendBoardSync(gridData)
    return self:publish(Protocol.MSG.BOARD_SYNC, gridData)
end

function OnlineClient:sendPieceMove(type, x, y, rot)
    return self:publish(Protocol.MSG.PIECE_MOVE, type, x, y, rot)
end

function OnlineClient:sendMessage(msg)
    if msg.type == Protocol.MSG.GARBAGE then
        return self:publish(msg.type, msg.lines or 0)
    else
        return self:publish(msg.type, msg.data or "")
    end
end

function OnlineClient:disconnect()
    self.connected = false
    self.roomCode = nil
    self.channelName = nil
    self.ablyToken = nil
    self.playerId = nil
    print("OnlineClient: Disconnected")
end

return OnlineClient
