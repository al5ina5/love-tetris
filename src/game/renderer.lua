-- src/game/renderer.lua
-- Handles all rendering logic: canvas, shaders, fonts, scaling, and drawing

local FX = require('src.fx')

local Renderer = {}

function Renderer.init()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
    
    -- Create fonts optimized for sharp scaling
    local fonts = {
        small = love.graphics.newFont('assets/fonts/upheavtt.ttf', 12),
        medium = love.graphics.newFont('assets/fonts/upheavtt.ttf', 18),
        large = love.graphics.newFont('assets/fonts/upheavtt.ttf', 40),
        score = love.graphics.newFont('assets/fonts/upheavtt.ttf', 30)
    }
    
    for _, f in pairs(fonts) do
        f:setFilter("nearest", "nearest")
    end
    
    local canvas = love.graphics.newCanvas(320, 240)
    canvas:setFilter("nearest", "nearest")
    
    return {
        fonts = fonts,
        canvas = canvas,
        activeShader = nil,
        hasTimeUniform = false,
        screenWidth = 320,
        screenHeight = 240
    }
end

function Renderer.loadShader(shaderType)
    if shaderType == "OFF" then
        return nil, false
    end
    
    local shaderPath = 'src.shaders.' .. string.lower(shaderType)
    local status, shaderCode = pcall(require, shaderPath)
    if not status then
        print("Error loading shader: " .. tostring(shaderCode))
        return nil, false
    end
    
    local shader = love.graphics.newShader(shaderCode)
    if shader:hasUniform("inputRes") then
        shader:send("inputRes", {320, 240})
    end
    local hasTime = shader:hasUniform("time")
    
    return shader, hasTime
end

function Renderer.drawText(text, x, y, limit, align, color, shadowColor, outlineColor, fonts)
    color = color or {1, 1, 1}
    shadowColor = shadowColor or {0, 0, 0, 1}
    outlineColor = outlineColor or {0, 0, 0, 1}
    
    x, y = math.floor(x + 0.5), math.floor(y + 0.5)
    limit = math.floor(limit + 0.5)
    
    -- Outline (thick retro style)
    love.graphics.setColor(outlineColor)
    for ox = -1, 1 do
        for oy = -1, 1 do
            if ox ~= 0 or oy ~= 0 then
                love.graphics.printf(text, x + ox, y + oy, limit, align)
            end
        end
    end
    
    -- Shadow
    love.graphics.setColor(shadowColor)
    love.graphics.printf(text, x, y + 1, limit, align)
    
    -- Main text
    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, limit, align)
end

function Renderer.draw(state, game)
    local sw, sh = state.screenWidth, state.screenHeight
    local winW, winH = love.graphics.getDimensions()
    
    -- Integer scaling for crisp pixel-art
    local scale = math.floor(math.min(winW / sw, winH / sh))
    if scale < 1 then scale = 1 end
    
    local ox, oy = (winW - sw * scale) / 2, (winH - sh * scale) / 2

    -- PASS 1: Render to canvas (with shader effects)
    love.graphics.setCanvas(state.canvas)
    love.graphics.clear()
    
    if game.menu:isVisible() then
        game.menu:drawBackground(game)
    else
        Renderer.drawGameplay(state, game, sw, sh)
    end
    
    love.graphics.setCanvas()
    
    -- PASS 2: Draw canvas to screen with shader
    love.graphics.setColor(1, 1, 1)
    if state.activeShader then
        if state.hasTimeUniform then
            state.activeShader:send("time", love.timer.getTime())
        end
        love.graphics.setShader(state.activeShader)
    end
    
    local sx, sy = FX:getShake()
    love.graphics.draw(state.canvas, ox + sx, oy + sy, 0, scale, scale)
    love.graphics.setShader()
    
    -- FX Pass
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale)
    FX:drawParticles()
    FX:drawFlash(sw, sh)
    love.graphics.pop()

    -- PASS 3: UI elements (unshaded)
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale)
    
    if game.menu:isVisible() then
        game.menu:drawForeground(game)
    else
        Renderer.drawGameUI(state, game, sw, sh)
    end
    
    love.graphics.pop()
end

function Renderer.drawGameplay(state, game, sw, sh)
    local hasOpponents = game:countRemotePlayers() > 0
    local isNetworked = game.network ~= nil
    local bsW, bsH = 16, 11
    local bw, bh = 10 * bsW, 20 * bsH
    
    if not hasOpponents and not isNetworked then
        -- Single player layout
        local bx = (sw - bw) / 2
        local by = 0
        game.localBoard:draw(bx, by, bsW, bsH, game, nil, game.menu.settings.ghost)
        
        -- Hold piece
        if game.localBoard.holdPieceType then
            game.localBoard:drawPiecePreview(game.localBoard.holdPieceType, bx - 40, 20, 8, 8)
        end
        
        -- Next queue (3 pieces)
        for i, pieceType in ipairs({game.localBoard.nextPieceType, game.localBoard.nextQueue[1], game.localBoard.nextQueue[2]}) do
            game.localBoard:drawPiecePreview(pieceType, bx + bw + 10, 20 + (i-1)*35, 8, 8)
        end
    else
        -- Multiplayer layout
        local lx, ly = 0, 0
        game.localBoard:draw(lx, ly, bsW, bsH, game, nil, game.menu.settings.ghost)
        
        -- Hold piece (small)
        if game.localBoard.holdPieceType then
            game.localBoard:drawPiecePreview(game.localBoard.holdPieceType, lx + 10, bh + 2, 4, 4)
        end
        
        -- Next pieces (small)
        for i, pieceType in ipairs({game.localBoard.nextPieceType, game.localBoard.nextQueue[1], game.localBoard.nextQueue[2]}) do
            game.localBoard:drawPiecePreview(pieceType, lx + bw - 26, bh + 2 + (i-1)*15, 4, 4)
        end
        
        -- Opponent boards
        local count = 0
        local opponentColor = {0.5, 0.5, 0.5}
        for id, board in pairs(game.remoteBoards) do
            if count == 0 then
                local rx, ry = sw / 2, 0
                board:draw(rx, ry, bsW, bsH, game, opponentColor)
                board:drawPiecePreview(board.nextPieceType, rx + bw - 26, bh + 2, 4, 4)
            else
                local miniBs = 4
                local miniBw, miniBh = 10 * miniBs, 20 * miniBs
                local ex = sw - miniBw - 5
                local ey = 5 + (count - 1) * (miniBh + 10)
                board:draw(ex, ey, miniBs, miniBs, game, opponentColor)
            end
            count = count + 1
        end
        
        -- If networked but no board data yet, show a placeholder label
        if count == 0 and isNetworked then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("WAITING FOR HOST...", sw * 0.75, sh / 2, sw / 2, "center", {0.5, 0.5, 0.5})
        end
        
        -- Vertical divider
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.line(sw / 2, 0, sw / 2, sh)
    end
    
    -- Overlay backgrounds
    if game.state == "countdown" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    elseif game.state == "over" or game.state == "disconnected_pause" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end
end

function Renderer.drawGameUI(state, game, sw, sh)
    local hasOpponents = game:countRemotePlayers() > 0
    local isNetworked = game.network ~= nil
    local bsW, bsH = 16, 11
    local bw, bh = 10 * bsW, 20 * bsH
    
    if not hasOpponents and not isNetworked then
        -- Single player UI
        local bx = (sw - bw) / 2
        love.graphics.setFont(state.fonts.score)
        Renderer.drawText(tostring(game.localBoard.score), bx, bh + 2, bw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        
        if game.gameMode == "SPRINT" then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText("LINES: " .. game.localBoard.linesCleared .. "/40", bx, 5, bw, "center", {1, 1, 1})
            Renderer.drawText(string.format("TIME: %.2f", game.sprintTime), bx, 20, bw, "center", {1, 1, 1})
        elseif game.gameMode == "MARATHON" and game.marathonState then
            love.graphics.setFont(state.fonts.medium)
            local MarathonRenderer = require('src.game.marathon_renderer')
            local drawFunc = function(text, x, y, limit, align, color)
                Renderer.drawText(text, x, y, limit, align, color, nil, nil, state.fonts)
            end
            MarathonRenderer.drawHUD(game.marathonState, game.localBoard, state.fonts, sw, sh, drawFunc)
        end

        if game.localBoard.combo > 0 then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText("COMBO x" .. game.localBoard.combo, bx - 60, bh - 20, 60, "right", {1, 0.5, 0.5})
        end
        
        if game.state == "waiting" then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("WAITING FOR OPPONENT...", bx, bh - 20, bw, "center", {0.7, 0.7, 0.7})
        end
    else
        -- Multiplayer UI
        love.graphics.setFont(state.fonts.score)
        Renderer.drawText(tostring(game.localBoard.score), 0, bh - 15, sw / 2, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        
        if game.localBoard.pendingGarbage > 0 then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("GARBAGE: " .. game.localBoard.pendingGarbage, 0, bh - 25, sw / 2, "center", {1, 0, 0})
        end
        
        local count = 0
        for id, board in pairs(game.remoteBoards) do
            if count == 0 then
                Renderer.drawText(tostring(board.score or 0), sw / 2, bh - 15, sw / 2, "center", {0.8, 0.8, 0.8})
            end
            count = count + 1
        end
    end

    -- Countdown
    if game.state == "countdown" then
        love.graphics.setFont(state.fonts.large)
        local text = math.ceil(game.stateManager.countdownTimer)
        if text == 0 then text = "GO!" end
        Renderer.drawText(tostring(text), 0, sh/2 - 20, sw, "center", {1, 0.3, 0.1}, {0.3, 0, 0})
    end

    -- Game Over
    if game.state == "over" then
        love.graphics.setFont(state.fonts.large)
        local text = "GAME OVER"
        local color = {1, 0.2, 0.2}
        local shadow = {0.3, 0, 0}
        
        if game.gameMode == "SPRINT" and game.localBoard.linesCleared >= 40 then
            text = "SPRINT FINISHED!"
            color = {0.2, 1, 0.2}
            shadow = {0, 0.3, 0}
        elseif game.gameMode == "MARATHON" then
            text = "MARATHON COMPLETE"
            color = {0.2, 1, 0.2}
            shadow = {0, 0.3, 0}
        elseif game:countRemotePlayers() > 0 and not game.localBoard.gameOver then
            text = "YOU WON!"
            color = {0.2, 1, 0.2}
            shadow = {0, 0.3, 0}
        end
        Renderer.drawText(text, 0, sh/2 - 20, sw, "center", color, shadow)
        
        if game.gameMode == "SPRINT" then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText(string.format("FINAL TIME: %.2f", game.sprintTime), 0, sh/2 + 25, sw, "center", {1, 1, 1})
        elseif game.gameMode == "MARATHON" and game.marathonState then
            love.graphics.setFont(state.fonts.medium)
            local MarathonState = require('src.game.marathon_state')
            local summary = MarathonState.getSummary(game.marathonState, game.localBoard)
            local timeStr = string.format("%02d:%02d.%02d", 
                math.floor(summary.time / 60),
                math.floor(summary.time % 60),
                math.floor((summary.time % 1) * 100))
            Renderer.drawText("LEVEL " .. summary.level .. " | " .. summary.lines .. " LINES", 0, sh/2 + 10, sw, "center", {1, 1, 1})
            Renderer.drawText("TIME: " .. timeStr, 0, sh/2 + 30, sw, "center", {1, 1, 1})
        end
    end

    -- Disconnected Pause
    if game.state == "disconnected_pause" then
        love.graphics.setFont(state.fonts.large)
        Renderer.drawText("DISCONNECTED", 0, sh/2 - 20, sw, "center", {1, 0.5, 0}, {0.3, 0.1, 0})
        love.graphics.setFont(state.fonts.medium)
        Renderer.drawText("RESUMING IN SINGLE PLAYER...", 0, sh/2 + 25, sw, "center", {0.8, 0.8, 0.8})
    end
end

return Renderer
