-- src/game/renderer.lua
-- Handles all rendering logic: canvas, shaders, fonts, scaling, and drawing

local FX = require('src.fx')

local Renderer = {}

function Renderer.init()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setLineStyle("rough")
    
    -- Create fonts optimized for sharp scaling (Press Start 2P - OFL licensed)
    local fonts = {
        small = love.graphics.newFont('assets/fonts/PressStart2P-Regular.ttf', 12),
        medium = love.graphics.newFont('assets/fonts/PressStart2P-Regular.ttf', 16),
        large = love.graphics.newFont('assets/fonts/PressStart2P-Regular.ttf', 32),
        score = love.graphics.newFont('assets/fonts/PressStart2P-Regular.ttf', 24)
    }
    
    for _, f in pairs(fonts) do
        f:setFilter("nearest", "nearest")
    end
    
    local canvas = love.graphics.newCanvas(640, 480)
    canvas:setFilter("nearest", "nearest")
    
    return {
        fonts = fonts,
        canvas = canvas,
        activeShader = nil,
        hasTimeUniform = false,
        screenWidth = 640,
        screenHeight = 480
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
        shader:send("inputRes", {640, 480})
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
    local isDisconnectedPause = game.state == "disconnected_pause"
    local bsW, bsH = 32, 22
    local bw, bh = 10 * bsW, 20 * bsH
    
    -- Calculate preview positions to prevent overflow (canvas height is 480)
    local previewY = sh - 40
    
    -- During disconnected pause, render as single player (no ghost board)
    if not hasOpponents and (not isNetworked or isDisconnectedPause) then
        -- Single player layout
        local bx = (sw - bw) / 2
        local by = 0
        game.localBoard:draw(bx, by, bsW, bsH, game, nil, game.menu.settings.ghost)
        
        -- Hold piece
        if game.localBoard.holdPieceType then
            game.localBoard:drawPiecePreview(game.localBoard.holdPieceType, bx - 80, 40, 16, 16)
        end
        
        -- Next queue (3 pieces)
        for i, pieceType in ipairs({game.localBoard.nextPieceType, game.localBoard.nextQueue[1], game.localBoard.nextQueue[2]}) do
            game.localBoard:drawPiecePreview(pieceType, bx + bw + 20, 40 + (i-1)*70, 16, 16)
        end
    else
        -- Multiplayer layout
        local lx, ly = 0, 0
        game.localBoard:draw(lx, ly, bsW, bsH, game, nil, game.menu.settings.ghost)
        
        -- Hold piece (small) - position at bottom within canvas bounds
        if game.localBoard.holdPieceType then
            game.localBoard:drawPiecePreview(game.localBoard.holdPieceType, lx + 20, previewY, 8, 8)
        end
        
        -- Next pieces (small) - position at bottom within canvas bounds
        for i, pieceType in ipairs({game.localBoard.nextPieceType, game.localBoard.nextQueue[1], game.localBoard.nextQueue[2]}) do
            game.localBoard:drawPiecePreview(pieceType, lx + bw - 52, previewY - (3-i)*30, 8, 8)
        end
        
        -- Opponent boards
        local count = 0
        local opponentColor = {0.5, 0.5, 0.5}
        for id, board in pairs(game.remoteBoards) do
            if count == 0 then
                local rx, ry = sw / 2, 0
                board:draw(rx, ry, bsW, bsH, game, opponentColor)
                -- Position opponent piece preview at bottom within canvas bounds
                board:drawPiecePreview(board.nextPieceType, rx + bw - 52, previewY, 8, 8)
            else
                local miniBs = 8
                local miniBw, miniBh = 10 * miniBs, 20 * miniBs
                local ex = sw - miniBw - 10
                local ey = 10 + (count - 1) * (miniBh + 20)
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
    local bsW, bsH = 32, 22
    local bw, bh = 10 * bsW, 20 * bsH
    
    -- Calculate UI positions once to prevent overflow (canvas height is 480)
    local scoreY = sh - 70
    local previewY = sh - 40
    
    if not hasOpponents and not isNetworked then
        -- Single player UI
        local bx = (sw - bw) / 2
        
        -- Don't draw score here during game over (it's shown in the game over overlay)
        if game.state ~= "over" then
            love.graphics.setFont(state.fonts.score)
            Renderer.drawText(tostring(game.localBoard.score), bx, scoreY, bw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        end
        
        if game.gameMode == "SPRINT" then
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText("LINES: " .. game.localBoard.linesCleared .. "/40", bx, 10, bw, "center", {1, 1, 1})
            Renderer.drawText(string.format("TIME: %.2f", game.sprintTime), bx, 45, bw, "center", {1, 1, 1})
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
            Renderer.drawText("COMBO x" .. game.localBoard.combo, bx - 120, bh - 40, 120, "right", {1, 0.5, 0.5})
        end
        
    else
        -- Multiplayer UI
        love.graphics.setFont(state.fonts.score)
        Renderer.drawText(tostring(game.localBoard.score), 0, scoreY, sw / 2, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        
        if game.localBoard.pendingGarbage > 0 then
            love.graphics.setFont(state.fonts.small)
            Renderer.drawText("GARBAGE: " .. game.localBoard.pendingGarbage, 0, bh - 50, sw / 2, "center", {1, 0, 0})
        end
        
        local count = 0
        for id, board in pairs(game.remoteBoards) do
            if count == 0 then
                Renderer.drawText(tostring(board.score or 0), sw / 2, scoreY, sw / 2, "center", {0.8, 0.8, 0.8})
            end
            count = count + 1
        end
    end

    -- Countdown
    if game.state == "countdown" then
        love.graphics.setFont(state.fonts.large)
        local text = math.ceil(game.stateManager.countdownTimer)
        if text == 0 then text = "GO!" end
        Renderer.drawText(tostring(text), 0, sh/2 - 40, sw, "center", {1, 0.3, 0.1}, {0.3, 0, 0})
    end

    -- Game Over
    if game.state == "over" then
        love.graphics.setFont(state.fonts.large)
        local color = {1, 0.2, 0.2}
        local shadow = {0.3, 0, 0}
        
        if game.gameMode == "SPRINT" and game.localBoard.linesCleared >= 40 then
            Renderer.drawText("SPRINT", 0, sh/2 - 100, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            Renderer.drawText("FINISHED!", 0, sh/2 - 30, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            love.graphics.setFont(state.fonts.medium)
            Renderer.drawText(string.format("FINAL TIME: %.2f", game.sprintTime), 0, sh/2 + 60, sw, "center", {1, 1, 1})
        elseif game.gameMode == "MARATHON" and game.marathonState then
            Renderer.drawText("MARATHON", 0, sh/2 - 140, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            Renderer.drawText("COMPLETE", 0, sh/2 - 70, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
            
            love.graphics.setFont(state.fonts.medium)
            local MarathonState = require('src.game.marathon_state')
            local summary = MarathonState.getSummary(game.marathonState, game.localBoard)
            local timeStr = string.format("%02d:%02d.%02d", 
                math.floor(summary.time / 60),
                math.floor(summary.time % 60),
                math.floor((summary.time % 1) * 100))
            
            local statsY = sh/2 + 20
            Renderer.drawText("LEVEL " .. summary.level, 0, statsY, sw, "center", {1, 1, 1})
            Renderer.drawText("LINES " .. summary.lines, 0, statsY + 40, sw, "center", {1, 1, 1})
            Renderer.drawText("TIME " .. timeStr, 0, statsY + 80, sw, "center", {1, 1, 1})
            
            love.graphics.setFont(state.fonts.score)
            Renderer.drawText(tostring(game.localBoard.score), 0, statsY + 130, sw, "center", {1, 0.9, 0.3}, {0.4, 0.2, 0})
        elseif game:countRemotePlayers() > 0 and not game.localBoard.gameOver then
            Renderer.drawText("YOU WON!", 0, sh/2 - 40, sw, "center", {0.2, 1, 0.2}, {0, 0.3, 0})
        else
            Renderer.drawText("GAME OVER", 0, sh/2 - 40, sw, "center", color, shadow)
        end
        
        -- Show "press any key" hint after delay
        local StateManager = require('src.game.state_manager')
        if StateManager.canDismissGameOver(game.stateManager) then
            love.graphics.setFont(state.fonts.small)
            local alpha = 0.5 + 0.3 * math.sin(love.timer.getTime() * 3)
            Renderer.drawText("PRESS ANY KEY", 0, sh - 40, sw, "center", {1, 1, 1, alpha})
        end
    end

    -- Disconnected Pause
    if game.state == "disconnected_pause" then
        love.graphics.setFont(state.fonts.large)
        
        -- Choose message based on disconnect reason
        local reason = game.stateManager.disconnectReason or "opponent_left"
        local mainText = "OPPONENT LEFT"
        local subText = "Rage quit? Crashed? Who knows :P"
        
        if reason == "connection_closed" then
            mainText = "CONNECTION LOST"
            subText = "Network hiccup... it happens"
        end
        
        Renderer.drawText(mainText, 0, sh/2 - 80, sw, "center", {1, 0.5, 0}, {0.3, 0.1, 0})
        
        love.graphics.setFont(state.fonts.small)
        Renderer.drawText(subText, 0, sh/2 - 10, sw, "center", {0.7, 0.7, 0.7})
        
        love.graphics.setFont(state.fonts.medium)
        local timeLeft = math.ceil(game.stateManager.disconnectPauseTimer)
        Renderer.drawText("Continuing solo in " .. timeLeft .. "...", 0, sh/2 + 60, sw, "center", {0.8, 0.8, 0.8})
        
        -- Hint to skip
        love.graphics.setFont(state.fonts.small)
        local alpha = 0.5 + 0.3 * math.sin(love.timer.getTime() * 3)
        Renderer.drawText("Press any key to continue now", 0, sh/2 + 110, sw, "center", {1, 1, 1, alpha})
    end
end

return Renderer
