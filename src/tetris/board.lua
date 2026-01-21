-- src/tetris/board.lua
-- Tetris board core - coordinates all tetris modules

local Piece = require('src.tetris.piece')
local Scoring = require('src.tetris.scoring')
local Renderer = require('src.tetris.renderer')

local Board = {}
Board.__index = Board

-- Expose constants for backwards compatibility
Board.PIECES = Piece.PIECES
Board.WALL_KICKS = Piece.WALL_KICKS
Board.WALL_KICKS_I = Piece.WALL_KICKS_I

function Board:new(width, height)
    local self = setmetatable({}, Board)
    self.width = width or 10
    self.height = height or 20
    
    -- Initialize grid
    self.grid = {}
    for y = 1, self.height do
        self.grid[y] = {}
        for x = 1, self.width do
            self.grid[y][x] = 0
        end
    end
    
    -- Piece state
    self.currentPiece = nil
    self.pieceX = 0
    self.pieceY = 0
    self.rotationIndex = 0
    self.bag = Piece.initBag()
    self.nextQueue = Piece.initQueue(self.bag)
    self.nextPieceType = table.remove(self.nextQueue, 1)
    table.insert(self.nextQueue, Piece.getRandomType(self.bag))
    
    self.holdPieceType = nil
    self.canHold = true
    
    -- Game state
    self.gameOver = false
    self.score = 0
    self.level = 1
    self.linesCleared = 0
    self.linesForNextLevel = 10
    self.gridChanged = false
    self.combo = -1
    self.lastWasTSpin = false
    
    -- Timing
    self.dropTimer = 0
    self.dropSpeed = 1.0
    self.lockTimer = 0
    self.lockDelay = 0.5
    self.isWaitingToLock = false
    self.lastMoveWasRotation = false
    
    -- Garbage
    self.pendingGarbage = 0
    
    Scoring.updateDropSpeed(self)
    Piece.spawn(self)
    
    return self
end

function Board:update(dt)
    if self.gameOver then return false end
    
    local changed = false
    
    -- Check if piece is touching ground
    if Piece.checkCollision(self, self.pieceX, self.pieceY + 1) then
        if not self.isWaitingToLock then
            self.isWaitingToLock = true
            self.lockTimer = 0
        end
        
        self.lockTimer = self.lockTimer + dt
        if self.lockTimer >= self.lockDelay then
            Scoring.lockPiece(self)
            changed = true
        end
    else
        self.isWaitingToLock = false
        self.lockTimer = 0
        
        self.dropTimer = self.dropTimer + dt
        if self.dropTimer >= self.dropSpeed then
            if Piece.move(self, 0, 1) then
                changed = true
            end
            self.dropTimer = 0
        end
    end
    
    return changed
end

-- Public API methods that delegate to modules
function Board:move(dx, dy)
    return Piece.move(self, dx, dy)
end

function Board:rotate(ccw)
    return Piece.rotate(self, ccw)
end

function Board:hold()
    return Piece.hold(self)
end

function Board:lockPiece()
    Scoring.lockPiece(self)
end

function Board:receiveGarbage(lines)
    Scoring.receiveGarbage(self, lines)
end

function Board:getGhostY()
    return Piece.getGhostY(self)
end

function Board:draw(offsetX, offsetY, bw, bh, game, forcedColor, showGhost)
    Renderer.draw(self, offsetX, offsetY, bw, bh, game, forcedColor, showGhost)
end

function Board:drawPiecePreview(type, offsetX, offsetY, bw, bh)
    Renderer.drawPiecePreview(self, type, offsetX, offsetY, bw, bh)
end

function Board:copyTable(t)
    return Piece.copyTable(t)
end

function Board:serializeGrid()
    local data = {}
    for y = 1, self.height do
        for x = 1, self.width do
            local cell = self.grid[y][x]
            if type(cell) == "table" then
                local found = false
                for type, piece in pairs(Piece.PIECES) do
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

function Board:deserializeGrid(str)
    local i = 1
    for y = 1, self.height do
        for x = 1, self.width do
            local char = str:sub(i, i)
            if char == "0" then
                self.grid[y][x] = 0
            elseif Piece.PIECES[char] then
                self.grid[y][x] = Piece.PIECES[char].color
            else
                self.grid[y][x] = {0.5, 0.5, 0.5}
            end
            i = i + 1
        end
    end
end

return Board
