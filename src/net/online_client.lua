-- src/net/online_client.lua
-- Online multiplayer matchmaker client for the Render service
-- Handles room creation, listing, and joining via REST API

local json = require("src.lib.dkjson")
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

function OnlineClient:new()
    if not OnlineClient.isAvailable() then
        error("Online multiplayer requires HTTPS support (install lua-sec or ensure curl/wget is available)")
    end
    
    local self = setmetatable({}, OnlineClient)
    self.roomCode = nil
    self.connected = false
    self.apiUrl = Constants.API_BASE_URL
    self.httpMethod = hasLuaSec and "luasec" or "simple"
    
    return self
end

-- Helper: Make HTTP request
function OnlineClient:httpRequest(method, url, body)
    if self.httpMethod == "luasec" then
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
        
        local ok, code = https.request(request)
        if not ok then return false, "Request failed: " .. tostring(code) end
        
        local responseBody = table.concat(response)
        if code >= 200 and code < 300 then
            local success, data = pcall(json.decode, responseBody)
            return success, data
        else
            return false, "HTTP " .. code
        end
    else
        return SimpleHTTP.request(method, url, body)
    end
end

-- Matchmaking API
function OnlineClient:createRoom(isPublic)
    local success, response = self:httpRequest("POST", self.apiUrl .. "/api/create-room", json.encode({ isPublic = isPublic or false }))
    if not success then return false end
    self.roomCode = response.roomCode
    return true, self.roomCode
end

function OnlineClient:joinRoom(roomCode)
    local success = self:httpRequest("POST", self.apiUrl .. "/api/join-room", json.encode({ roomCode = roomCode:upper() }))
    if not success then return false end
    self.roomCode = roomCode:upper()
    return true
end

function OnlineClient:listRooms()
    local success, response = self:httpRequest("GET", self.apiUrl .. "/api/list-rooms")
    if not success then return {} end
    return response.rooms or {}
end

function OnlineClient:heartbeat()
    if not self.roomCode then return false end
    return self:httpRequest("POST", self.apiUrl .. "/api/heartbeat", json.encode({ roomCode = self.roomCode }))
end

function OnlineClient:disconnect()
    self.roomCode = nil
    self.connected = false
end

return OnlineClient
