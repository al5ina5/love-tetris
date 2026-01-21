-- src/ui/menu/background.lua
-- Animated falling blocks background for menus

local TetrisBoard = require('src.tetris.board')

local Background = {}

function Background.init()
    local blocks = {}
    local pieceTypes = {"I", "J", "L", "O", "S", "T", "Z"}
    
    for i = 1, 25 do
        local sizeX, sizeY = 16, 11
        local type = pieceTypes[love.math.random(#pieceTypes)]
        table.insert(blocks, {
            type = type,
            color = TetrisBoard.PIECES[type].color,
            x = math.floor(love.math.random(0, 320 / sizeX)) * sizeX,
            y = math.floor(love.math.random(-20, 240 / sizeY)) * sizeY,
            speed = love.math.random(2, 6) * 0.1,
            moveTimer = 0,
            rotation = love.math.random(0, 3),
            opacity = love.math.random(15, 35) / 100,
            sizeX = sizeX,
            sizeY = sizeY
        })
    end
    
    return blocks
end

function Background.update(blocks, dt)
    for _, block in ipairs(blocks) do
        block.moveTimer = block.moveTimer + dt
        if block.moveTimer >= block.speed then
            block.moveTimer = 0
            block.y = block.y + block.sizeY
            
            if block.y > 240 then
                block.y = -block.sizeY * 4
                block.x = math.floor(love.math.random(0, 320 / block.sizeX)) * block.sizeX
                block.speed = love.math.random(2, 6) * 0.1
                block.opacity = love.math.random(15, 35) / 100
                
                local pieceTypes = {"I", "J", "L", "O", "S", "T", "Z"}
                block.type = pieceTypes[love.math.random(#pieceTypes)]
                block.color = TetrisBoard.PIECES[block.type].color
            end
        end
    end
end

function Background.draw(blocks)
    -- Darken background
    love.graphics.setColor(0, 0, 0, 1.0)
    love.graphics.rectangle("fill", 0, 0, 320, 240)
    
    -- Draw falling blocks
    for _, block in ipairs(blocks) do
        local data = TetrisBoard.PIECES[block.type]
        if data then
            local r, g, b = unpack(block.color or {0, 0.8, 0.2})
            love.graphics.setColor(r, g, b, block.opacity)
            
            local shape = data
            for y = 1, #shape do
                for x = 1, #shape[y] do
                    if shape[y][x] ~= 0 then
                        local drawX, drawY = x-1, y-1
                        if block.rotation == 1 then
                            drawX, drawY = #shape-y, x-1
                        elseif block.rotation == 2 then
                            drawX, drawY = #shape-x, #shape-y
                        elseif block.rotation == 3 then
                            drawX, drawY = y-1, #shape-x
                        end
                        
                        love.graphics.rectangle("fill",
                            block.x + drawX * block.sizeX,
                            block.y + drawY * block.sizeY,
                            block.sizeX - 1, block.sizeY - 1)
                    end
                end
            end
        end
    end
end

return Background
