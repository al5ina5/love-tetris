-- src/tetris/renderer.lua
-- Board rendering with blocks, grid, ghost piece, and previews

local Renderer = {}

function Renderer.drawBlock(x, y, sw, sh, color)
    local r, g, b = unpack(color)
    
    -- Main fill
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", x, y, sw, sh)
    
    -- Retro border effect (highlight/shadow)
    love.graphics.setColor(r + (1-r)*0.5, g + (1-g)*0.5, b + (1-b)*0.5)
    love.graphics.rectangle("fill", x, y, sw, 1) -- Top
    love.graphics.rectangle("fill", x, y, 1, sh) -- Left
    
    love.graphics.setColor(r*0.5, g*0.5, b*0.5)
    love.graphics.rectangle("fill", x, y + sh - 1, sw, 1) -- Bottom
    love.graphics.rectangle("fill", x + sw - 1, y, 1, sh) -- Right
end

function Renderer.drawPiecePreview(board, type, offsetX, offsetY, bw, bh)
    bh = bh or bw or 10
    bw = bw or 10
    local Piece = require('src.tetris.piece')
    local data = Piece.PIECES[type]
    if not data then return end
    
    local color = data.color
    for y = 1, #data do
        for x = 1, #data[y] do
            if data[y][x] ~= 0 then
                Renderer.drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, color)
            end
        end
    end
end

function Renderer.draw(board, offsetX, offsetY, bw, bh, game, forcedColor, showGhost)
    -- Handle old signature compatibility
    if type(bw) == "table" then
        game = bw
        bw = 10
        bh = 10
    elseif type(bh) == "table" then
        showGhost = forcedColor
        forcedColor = game
        game = bh
        bh = bw
    elseif bh == nil then
        bh = bw or 10
        bw = bw or 10
    end
    
    showGhost = showGhost ~= false
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", offsetX, offsetY, board.width * bw, board.height * bh)

    -- Draw grid lines with gradient fade
    love.graphics.setLineWidth(1)
    local gridBrightness = 0.3
    local maxAlpha = 0.3
    local minAlpha = 0.09
    local fadeRatio = 0.2
    
    -- Vertical lines
    for x = 1, board.width - 1 do
        local lineX = offsetX + x * bw
        local totalHeight = board.height * bh
        local segments = 20
        
        for i = 0, segments - 1 do
            local y1 = offsetY + (i / segments) * totalHeight
            local y2 = offsetY + ((i + 1) / segments) * totalHeight
            local t = i / segments
            
            local alpha
            if t < fadeRatio then
                alpha = minAlpha + (maxAlpha - minAlpha) * (t / fadeRatio)
            elseif t > (1 - fadeRatio) then
                alpha = minAlpha + (maxAlpha - minAlpha) * ((1 - t) / fadeRatio)
            else
                alpha = maxAlpha
            end
            
            love.graphics.setColor(gridBrightness, gridBrightness, gridBrightness, alpha)
            love.graphics.line(lineX, y1, lineX, y2)
        end
    end
    
    -- Horizontal lines
    for y = 1, board.height - 1 do
        local lineY = offsetY + y * bh
        local totalWidth = board.width * bw
        local segments = 20
        
        for i = 0, segments - 1 do
            local x1 = offsetX + (i / segments) * totalWidth
            local x2 = offsetX + ((i + 1) / segments) * totalWidth
            local t = i / segments
            
            local alpha
            if t < fadeRatio then
                alpha = minAlpha + (maxAlpha - minAlpha) * (t / fadeRatio)
            elseif t > (1 - fadeRatio) then
                alpha = minAlpha + (maxAlpha - minAlpha) * ((1 - t) / fadeRatio)
            else
                alpha = maxAlpha
            end
            
            love.graphics.setColor(gridBrightness, gridBrightness, gridBrightness, alpha)
            love.graphics.line(x1, lineY, x2, lineY)
        end
    end
    
    -- Draw locked blocks
    for y = 1, board.height do
        for x = 1, board.width do
            if board.grid[y][x] ~= 0 then
                Renderer.drawBlock(offsetX + (x - 1) * bw, offsetY + (y - 1) * bh, bw, bh, forcedColor or board.grid[y][x])
            end
        end
    end
    
    -- Draw ghost piece
    if showGhost and board.currentPiece and not board.gameOver and not forcedColor then
        local Piece = require('src.tetris.piece')
        local ghostY = Piece.getGhostY(board)
        if ghostY and ghostY ~= board.pieceY then
            local r, g, b = unpack(forcedColor or board.currentPiece.color)
            love.graphics.setColor(r, g, b, 0.5)
            for y = 1, #board.currentPiece.shape do
                for x = 1, #board.currentPiece.shape[y] do
                    if board.currentPiece.shape[y][x] ~= 0 then
                        local gy = ghostY + y - 1
                        local gx = board.pieceX + x - 1
                        if gy >= 1 and gy <= board.height and gx >= 1 and gx <= board.width then
                            love.graphics.rectangle("line", offsetX + (gx - 1) * bw + 1, offsetY + (gy - 1) * bh + 1, bw - 2, bh - 2)
                        end
                    end
                end
            end
        end
    end

    -- Draw current piece
    if board.currentPiece and not board.gameOver then
        for y = 1, #board.currentPiece.shape do
            for x = 1, #board.currentPiece.shape[y] do
                if board.currentPiece.shape[y][x] ~= 0 then
                    local gy = board.pieceY + y - 1
                    local gx = board.pieceX + x - 1
                    if gy >= 1 and gy <= board.height and gx >= 1 and gx <= board.width then
                        Renderer.drawBlock(offsetX + (gx - 1) * bw, offsetY + (gy - 1) * bh, bw, bh, forcedColor or board.currentPiece.color)
                    end
                end
            end
        end
    end
    
    -- Draw game over overlay
    if board.gameOver then
        love.graphics.setColor(1, 0, 0, 0.4)
        love.graphics.rectangle("fill", offsetX, offsetY, board.width * bw, board.height * bh)
    end
end

return Renderer
