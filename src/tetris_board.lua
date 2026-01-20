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
    self.nextPieceType = self:getRandomPieceType()
    
    self.gameOver = false
    self.score = 0
    self.linesCleared = 0
    self.gridChanged = false
    
    self.dropTimer = 0
    self.dropSpeed = 1.0 -- seconds per drop
    
    self.lockTimer = 0
    self.lockDelay = 0.5 -- 500ms lock delay
    self.isWaitingToLock = false
    
    self:spawnPiece()
    
    return self
end

function TetrisBoard:getRandomPieceType()
    local types = {"I", "J", "L", "O", "S", "T", "Z"}
    return types[love.math.random(#types)]
end

function TetrisBoard:spawnPiece()
    local type = self.nextPieceType
    self.nextPieceType = self:getRandomPieceType()
    
    self.currentPiece = {
        type = type,
        shape = self:copyTable(TetrisBoard.PIECES[type]),
        color = TetrisBoard.PIECES[type].color
    }
    
    self.pieceX = math.floor(self.width / 2) - math.floor(#self.currentPiece.shape[1] / 2)
    self.pieceY = 1
    self.rotationIndex = 0
    
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

function TetrisBoard:rotate()
    local oldShape = self.currentPiece.shape
    local n = #oldShape
    local newShape = {}
    for i = 1, n do newShape[i] = {} end
    
    for y = 1, n do
        for x = 1, n do
            newShape[x][n - y + 1] = oldShape[y][x]
        end
    end
    
    if not self:checkCollision(self.pieceX, self.pieceY, newShape) then
        self.currentPiece.shape = newShape
        self.rotationIndex = (self.rotationIndex + 1) % 4
        
        -- Reset lock delay on successful rotation
        if self.isWaitingToLock then
            self.lockTimer = 0
        end
        
        return true
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
        self.score = self.score + (#linesToRemove * 100)
        Audio:play('clear')
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

function TetrisBoard:draw(offsetX, offsetY, blockSize, forcedColor, showGhost)
    showGhost = showGhost ~= false -- Default to true
    blockSize = blockSize or 10
    
    -- Draw background (no border as requested)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", offsetX, offsetY, self.width * blockSize, self.height * blockSize)

    -- Draw faint grid lines to help visualize landing positions
    love.graphics.setColor(0.3, 0.3, 0.3, 0.2)
    love.graphics.setLineWidth(1)
    -- Vertical lines
    for x = 1, self.width - 1 do
        local lineX = offsetX + x * blockSize
        love.graphics.line(lineX, offsetY, lineX, offsetY + self.height * blockSize)
    end
    -- Horizontal lines
    for y = 1, self.height - 1 do
        local lineY = offsetY + y * blockSize
        love.graphics.line(offsetX, lineY, offsetX + self.width * blockSize, lineY)
    end
    
    -- Draw locked blocks
    for y = 1, self.height do
        for x = 1, self.width do
            if self.grid[y][x] ~= 0 then
                love.graphics.setColor(forcedColor or self.grid[y][x])
                love.graphics.rectangle("fill", offsetX + (x - 1) * blockSize, offsetY + (y - 1) * blockSize, blockSize, blockSize)
            end
        end
    end
    
    -- Draw ghost piece
    if showGhost and self.currentPiece and not self.gameOver and not forcedColor then
        local ghostY = self:getGhostY()
        if ghostY and ghostY ~= self.pieceY then
            local r, g, b = unpack(forcedColor or self.currentPiece.color)
            love.graphics.setColor(r, g, b, 0.2) -- Very faint
            for y = 1, #self.currentPiece.shape do
                for x = 1, #self.currentPiece.shape[y] do
                    if self.currentPiece.shape[y][x] ~= 0 then
                        local gy = ghostY + y - 1
                        local gx = self.pieceX + x - 1
                        if gy >= 1 and gy <= self.height and gx >= 1 and gx <= self.width then
                            love.graphics.rectangle("fill", offsetX + (gx - 1) * blockSize, offsetY + (gy - 1) * blockSize, blockSize, blockSize)
                        end
                    end
                end
            end
        end
    end

    -- Draw current piece
    if self.currentPiece and not self.gameOver then
        love.graphics.setColor(forcedColor or self.currentPiece.color)
        for y = 1, #self.currentPiece.shape do
            for x = 1, #self.currentPiece.shape[y] do
                if self.currentPiece.shape[y][x] ~= 0 then
                    local gy = self.pieceY + y - 1
                    local gx = self.pieceX + x - 1
                    -- Only draw if within visible bounds (both x and y)
                    if gy >= 1 and gy <= self.height and gx >= 1 and gx <= self.width then
                        love.graphics.rectangle("fill", offsetX + (gx - 1) * blockSize, offsetY + (gy - 1) * blockSize, blockSize, blockSize)
                    end
                end
            end
        end
    end
    
    -- Draw Game Over
    if self.gameOver then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle("fill", offsetX, offsetY, self.width * blockSize, self.height * blockSize)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("GAME OVER", offsetX, offsetY + (self.height * blockSize) / 2, self.width * blockSize, "center")
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
