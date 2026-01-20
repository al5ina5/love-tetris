local TetrisBoard = {}
TetrisBoard.__index = TetrisBoard

local Audio = require('src.audio')

TetrisBoard.PIECES = {
    I = {
        {0,0,0,0},
        {1,1,1,1},
        {0,0,0,0},
        {0,0,0,0},
        color = {0, 1, 1} -- Cyan
    },
    J = {
        {1,0,0},
        {1,1,1},
        {0,0,0},
        color = {0, 0, 1} -- Blue
    },
    L = {
        {0,0,1},
        {1,1,1},
        {0,0,0},
        color = {1, 0.5, 0} -- Orange
    },
    O = {
        {1,1},
        {1,1},
        color = {1, 1, 0} -- Yellow
    },
    S = {
        {0,1,1},
        {1,1,0},
        {0,0,0},
        color = {0, 1, 0} -- Green
    },
    T = {
        {0,1,0},
        {1,1,1},
        {0,0,0},
        color = {0.5, 0, 1} -- Purple
    },
    Z = {
        {1,1,0},
        {0,1,1},
        {0,0,0},
        color = {1, 0, 0} -- Red
    }
}

-- SRS Wall Kick Data
-- 0: spawn, 1: 90deg CW, 2: 180deg, 3: 90deg CCW
-- Values are (x, y) where positive y is UP in Tetris Guideline, 
-- but in our grid positive y is DOWN. So we invert y.
TetrisBoard.WALL_KICKS = {
    -- 0->1
    ["01"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    -- 1->0
    ["10"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    -- 1->2
    ["12"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    -- 2->1
    ["21"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    -- 2->3
    ["23"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}},
    -- 3->2
    ["32"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    -- 3->0
    ["30"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    -- 0->3
    ["03"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}}
}

TetrisBoard.WALL_KICKS_I = {
    -- 0->1
    ["01"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    -- 1->0
    ["10"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    -- 1->2
    ["12"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}},
    -- 2->1
    ["21"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    -- 2->3
    ["23"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    -- 3->2
    ["32"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    -- 3->0
    ["30"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    -- 0->3
    ["03"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}}
}

function TetrisBoard:new(width, height)
    local self = setmetatable({}, TetrisBoard)
    self.width = width or 10
    self.height = height or 20
    self.grid = {}
    for y = 1, self.height do
        self.grid[y] = {}
        for x = 1, self.width do
            self.grid[y][x] = 0
        end
    end
    
    self.currentPiece = nil
    self.pieceX = 0
    self.pieceY = 0
    self.rotationIndex = 0 -- 0-3
    self.bag = {}
    self.nextPieceType = self:getRandomPieceType()
    
    self.holdPieceType = nil
    self.canHold = true
    
    self.gameOver = false
    self.score = 0
    self.level = 1
    self.linesCleared = 0
    self.linesForNextLevel = 10
    self.gridChanged = false
    
    self.dropTimer = 0
    self.dropSpeed = 1.0 -- seconds per drop
    
    self.lockTimer = 0
    self.lockDelay = 0.5 -- 500ms lock delay
    self.isWaitingToLock = false
    
    self:updateDropSpeed()
    self:spawnPiece()
    
    return self
end

function TetrisBoard:updateDropSpeed()
    -- Standard-ish gravity: levels 1-15
    -- Level 1: 1.0s, Level 15: ~0.05s
    self.dropSpeed = math.max(0.05, 1.0 * (0.8 ^ (self.level - 1)))
end

function TetrisBoard:getRandomPieceType()
    if #self.bag == 0 then
        self.bag = {"I", "J", "L", "O", "S", "T", "Z"}
        -- Shuffle the bag
        for i = #self.bag, 2, -1 do
            local j = love.math.random(i)
            self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
        end
    end
    return table.remove(self.bag)
end

function TetrisBoard:spawnPiece(type)
    type = type or self.nextPieceType
    if type == self.nextPieceType then
        self.nextPieceType = self:getRandomPieceType()
    end
    
    self.currentPiece = {
        type = type,
        shape = self:copyTable(TetrisBoard.PIECES[type]),
        color = TetrisBoard.PIECES[type].color
    }
    
    self.pieceX = math.floor(self.width / 2) - math.floor(#self.currentPiece.shape[1] / 2)
    self.pieceY = 1
    self.rotationIndex = 0
    self.canHold = true
    
    if self:checkCollision(self.pieceX, self.pieceY) then
        self.gameOver = true
        Audio:play('gameOver')
    end
end

function TetrisBoard:copyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = self:copyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function TetrisBoard:checkCollision(px, py, shape)
    shape = shape or self.currentPiece.shape
    for y = 1, #shape do
        for x = 1, #shape[y] do
            if shape[y][x] ~= 0 then
                local worldX = px + x - 1
                local worldY = py + y - 1
                
                if worldX < 1 or worldX > self.width or worldY > self.height then
                    return true
                end
                
                if worldY >= 1 and self.grid[worldY][worldX] ~= 0 then
                    return true
                end
            end
        end
    end
    return false
end

function TetrisBoard:rotate(ccw)
    local oldShape = self.currentPiece.shape
    local n = #oldShape
    local newShape = {}
    for i = 1, n do newShape[i] = {} end
    
    if ccw then
        for y = 1, n do
            for x = 1, n do
                newShape[n - x + 1][y] = oldShape[y][x]
            end
        end
    else
        for y = 1, n do
            for x = 1, n do
                newShape[x][n - y + 1] = oldShape[y][x]
            end
        end
    end
    
    local oldRotation = self.rotationIndex
    local newRotation = (oldRotation + (ccw and -1 or 1)) % 4
    if newRotation < 0 then newRotation = 3 end
    
    local kickData = self.currentPiece.type == "I" and TetrisBoard.WALL_KICKS_I or TetrisBoard.WALL_KICKS
    local testKey = tostring(oldRotation) .. tostring(newRotation)
    local kicks = kickData[testKey] or {{0,0}}
    
    for _, kick in ipairs(kicks) do
        local dx, dy = kick[1], -kick[2] -- Invert y because our grid is positive-down
        if not self:checkCollision(self.pieceX + dx, self.pieceY + dy, newShape) then
            self.pieceX = self.pieceX + dx
            self.pieceY = self.pieceY + dy
            self.currentPiece.shape = newShape
            self.rotationIndex = newRotation
            
            -- Reset lock delay on successful rotation
            if self.isWaitingToLock then
                self.lockTimer = 0
            end
            
            return true
        end
    end
    
    return false
end

function TetrisBoard:move(dx, dy, forceLock)
    if not self:checkCollision(self.pieceX + dx, self.pieceY + dy) then
        self.pieceX = self.pieceX + dx
        self.pieceY = self.pieceY + dy
        
        -- Reset lock delay on successful move
        if self.isWaitingToLock then
            self.lockTimer = 0
        end
        
        return true
    end
    
    if dy > 0 and forceLock then
        self:lockPiece()
    end
    return false
end

function TetrisBoard:hold()
    if not self.canHold then return false end
    
    local oldHoldType = self.holdPieceType
    self.holdPieceType = self.currentPiece.type
    
    if oldHoldType then
        self:spawnPiece(oldHoldType)
    else
        self:spawnPiece()
    end
    
    self.canHold = false
    return true
end

function TetrisBoard:lockPiece()
    for y = 1, #self.currentPiece.shape do
        for x = 1, #self.currentPiece.shape[y] do
            if self.currentPiece.shape[y][x] ~= 0 then
                local gy = self.pieceY + y - 1
                local gx = self.pieceX + x - 1
                if gy >= 1 and gy <= self.height then
                    self.grid[gy][gx] = self.currentPiece.color
                end
            end
        end
    end
    
    local cleared = self:clearLines()
    self.gridChanged = true
    if not cleared then
        Audio:play('lock')
    end
    
    self.lockTimer = 0
    self.isWaitingToLock = false
    self:spawnPiece()
end

function TetrisBoard:clearLines()
    local linesToRemove = {}
    for y = self.height, 1, -1 do
        local full = true
        for x = 1, self.width do
            if self.grid[y][x] == 0 then
                full = false
                break
            end
        end
        if full then
            table.insert(linesToRemove, y)
        end
    end
    
    for _, y in ipairs(linesToRemove) do
        table.remove(self.grid, y)
        local newRow = {}
        for x = 1, self.width do newRow[x] = 0 end
        table.insert(self.grid, 1, newRow)
        self.linesCleared = self.linesCleared + 1
    end
    
    if #linesToRemove > 0 then
        local multipliers = {100, 300, 500, 800}
        local points = multipliers[math.min(#linesToRemove, 4)] * self.level
        self.score = self.score + points
        
        self.linesCleared = self.linesCleared + #linesToRemove
        if self.linesCleared >= self.linesForNextLevel then
            self.level = self.level + 1
            self.linesForNextLevel = self.linesForNextLevel + 10
            self:updateDropSpeed()
            Audio:play('item')
        end
        
        if #linesToRemove >= 4 then
            Audio:play('secret')
        else
            Audio:play('clear')
        end
        return true
    end
    return false
end

function TetrisBoard:update(dt)
    if self.gameOver then return false end
    
    local changed = false
    
    -- Check if piece is touching anything below
    if self:checkCollision(self.pieceX, self.pieceY + 1) then
        if not self.isWaitingToLock then
            self.isWaitingToLock = true
            self.lockTimer = 0
        end
        
        self.lockTimer = self.lockTimer + dt
        if self.lockTimer >= self.lockDelay then
            self:lockPiece()
            changed = true
        end
    else
        self.isWaitingToLock = false
        self.lockTimer = 0
        
        self.dropTimer = self.dropTimer + dt
        if self.dropTimer >= self.dropSpeed then
            if self:move(0, 1) then
                changed = true
            end
            self.dropTimer = 0
        end
    end
    
    return changed
end

function TetrisBoard:getGhostY()
    if not self.currentPiece then return nil end
    
    local ghostY = self.pieceY
    while not self:checkCollision(self.pieceX, ghostY + 1) do
        ghostY = ghostY + 1
    end
    return ghostY
end

function TetrisBoard:drawBlock(x, y, sw, sh, color)
    local r, g, b = unpack(color)
    
    -- Main fill
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", x, y, sw, sh)
    
    -- Retro border effect (highlight/shadow)
    -- Top and Left highlight
    love.graphics.setColor(r + (1-r)*0.5, g + (1-g)*0.5, b + (1-b)*0.5)
    love.graphics.rectangle("fill", x, y, sw, 1) -- Top
    love.graphics.rectangle("fill", x, y, 1, sh) -- Left
    
    -- Bottom and Right shadow
    love.graphics.setColor(r*0.5, g*0.5, b*0.5)
    love.graphics.rectangle("fill", x, y + sh - 1, sw, 1) -- Bottom
    love.graphics.rectangle("fill", x + sw - 1, y, 1, sh) -- Right
end

function TetrisBoard:drawPiecePreview(type, offsetX, offsetY, bw, bh)
    bh = bh or bw or 10
    bw = bw or 10
    local data = TetrisBoard.PIECES[type]
    if not data then return end
    
    local color = data.color
    for y = 1, #data do
        for x = 1, #data[y] do
            if data[y][x] ~= 0 then
                self:drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, color)
            end
        end
    end
end

function TetrisBoard:draw(offsetX, offsetY, bw, bh, game, forcedColor, showGhost)
    if type(bw) == "table" then
        -- Handle old signature: draw(offsetX, offsetY, game)
        game = bw
        bw = 10
        bh = 10
    elseif type(bh) == "table" then
        -- Handle old signature: draw(offsetX, offsetY, bs, game, ...)
        showGhost = forcedColor
        forcedColor = game
        game = bh
        bh = bw
    elseif bh == nil then
        bh = bw or 10
        bw = bw or 10
    end
    
    showGhost = showGhost ~= false -- Default to true
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", offsetX, offsetY, self.width * bw, self.height * bh)

    -- Draw subtle grid lines
    love.graphics.setColor(0.2, 0.2, 0.2, 0.1)
    love.graphics.setLineWidth(1)
    for x = 1, self.width - 1 do
        local lineX = offsetX + x * bw
        love.graphics.line(lineX, offsetY, lineX, offsetY + self.height * bh)
    end
    for y = 1, self.height - 1 do
        local lineY = offsetY + y * bh
        love.graphics.line(offsetX, lineY, offsetX + self.width * bw, lineY)
    end
    
    -- Draw locked blocks
    for y = 1, self.height do
        for x = 1, self.width do
            if self.grid[y][x] ~= 0 then
                self:drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, forcedColor or self.grid[y][x])
            end
        end
    end
    
    -- Draw ghost piece
    if showGhost and self.currentPiece and not self.gameOver and not forcedColor then
        local ghostY = self:getGhostY()
        if ghostY and ghostY ~= self.pieceY then
            local r, g, b = unpack(forcedColor or self.currentPiece.color)
            love.graphics.setColor(r, g, b, 0.2)
            for y = 1, #self.currentPiece.shape do
                for x = 1, #self.currentPiece.shape[y] do
                    if self.currentPiece.shape[y][x] ~= 0 then
                        local gy = ghostY + y - 1
                        local gx = self.pieceX + x - 1
                        if gy >= 1 and gy <= self.height and gx >= 1 and gx <= self.width then
                            love.graphics.rectangle("line", offsetX + (gx - 1) * bw + 1, offsetY + (gy - 1) * bh + 1, bw - 2, bh - 2)
                        end
                    end
                end
            end
        end
    end

    -- Draw current piece
    if self.currentPiece and not self.gameOver then
        for y = 1, #self.currentPiece.shape do
            for x = 1, #self.currentPiece.shape[y] do
                if self.currentPiece.shape[y][x] ~= 0 then
                    local gy = self.pieceY + y - 1
                    local gx = self.pieceX + x - 1
                    if gy >= 1 and gy <= self.height and gx >= 1 and gx <= self.width then
                        self:drawBlock(offsetX + (gx - 1) * bw, offsetY + (gy - 1) * bh, bw, bh, forcedColor or self.currentPiece.color)
                    end
                end
            end
        end
    end
    
    -- Draw Game Over
    if self.gameOver then
        love.graphics.setColor(1, 0, 0, 0.4)
        love.graphics.rectangle("fill", offsetX, offsetY, self.width * bw, self.height * bh)
    end
end

function TetrisBoard:serializeGrid()
    local data = {}
    for y = 1, self.height do
        for x = 1, self.width do
            local cell = self.grid[y][x]
            if type(cell) == "table" then
                -- Map color back to a simple char for brevity
                -- Just for simplicity let's use a digit 1-7 or 0
                local found = false
                for type, piece in pairs(TetrisBoard.PIECES) do
                    if piece.color[1] == cell[1] and piece.color[2] == cell[2] and piece.color[3] == cell[3] then
                        table.insert(data, type)
                        found = true
                        break
                    end
                end
                if not found then table.insert(data, "X") end
            else
                table.insert(data, "0")
            end
        end
    end
    return table.concat(data)
end

function TetrisBoard:deserializeGrid(str)
    local i = 1
    for y = 1, self.height do
        for x = 1, self.width do
            local char = str:sub(i, i)
            if char == "0" then
                self.grid[y][x] = 0
            elseif TetrisBoard.PIECES[char] then
                self.grid[y][x] = TetrisBoard.PIECES[char].color
            else
                self.grid[y][x] = {0.5, 0.5, 0.5} -- Unknown
            end
            i = i + 1
        end
    end
end

return TetrisBoard
