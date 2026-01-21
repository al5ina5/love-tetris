-- src/game/marathon_renderer.lua
-- Renders Marathon-specific HUD elements

local MarathonRenderer = {}

function MarathonRenderer.drawHUD(marathonState, board, fonts, sw, sh, drawTextFunc)
    local CONST = require('src.constants')
    
    -- Calculate positions (doubled for 640x480)
    local rightX = sw - 40
    local topY = 200
    local lineHeight = 80
    
    -- Time display (formatted as MM:SS.MS)
    local totalSeconds = marathonState.playTime
    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)
    local centiseconds = math.floor((totalSeconds % 1) * 100)
    local timeStr = string.format("%02d:%02d.%02d", minutes, seconds, centiseconds)
    
    drawTextFunc("TIME", rightX, topY, 400, "right", {1, 1, 1, 0.6})
    drawTextFunc(timeStr, rightX, topY + 40, 400, "right", {1, 1, 1, 1})
    
    -- Level with progress
    local levelY = topY + 100
    drawTextFunc("LEVEL", rightX, levelY, 400, "right", {1, 1, 1, 0.6})
    drawTextFunc(tostring(board.level), rightX, levelY + 40, 400, "right", {0.3, 1, 0.3, 1})
    
    -- Progress to next level (0-10 lines)
    local progress = (board.linesCleared % 10) / 10
    local barWidth = 200
    local barHeight = 12
    local barX = rightX - barWidth
    local barY = levelY + 100
    
    -- Background bar
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Progress bar
    love.graphics.setColor(0.3, 1, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
    
    -- Lines display
    local linesY = levelY + 130
    drawTextFunc("LINES", rightX, linesY, 400, "right", {1, 1, 1, 0.6})
    drawTextFunc(tostring(board.linesCleared), rightX, linesY + 40, 400, "right", {1, 1, 1, 1})
    
    -- Max combo
    local comboY = linesY + 100
    drawTextFunc("MAX COMBO", rightX, comboY, 400, "right", {1, 1, 1, 0.6})
    local comboColor = marathonState.maxCombo > 5 and {1, 0.7, 0.3, 1} or {1, 1, 1, 1}
    drawTextFunc(tostring(marathonState.maxCombo), rightX, comboY + 40, 400, "right", comboColor)
    
    -- T-spins
    local tspinTotal = MarathonRenderer.getTotalTSpins(marathonState)
    if tspinTotal > 0 then
        local tspinY = comboY + 100
        drawTextFunc("T-SPINS", rightX, tspinY, 400, "right", {1, 1, 1, 0.6})
        drawTextFunc(tostring(tspinTotal), rightX, tspinY + 40, 400, "right", {0.7, 0.3, 1, 1})
    end
end

function MarathonRenderer.getTotalTSpins(state)
    return state.tspinsSingle + state.tspinsDouble + state.tspinsTriple
end

function MarathonRenderer.drawGameOver(marathonState, board, fonts, sw, sh, drawTextFunc)
    -- Draw final statistics (doubled for 640x480)
    local centerX = sw / 2
    local startY = sh / 2 - 200
    local lineHeight = 70
    
    drawTextFunc("MARATHON COMPLETE", centerX, startY, 600, "center", {1, 1, 1, 1})
    
    local stats = {
        {"SCORE", board.score},
        {"LEVEL", board.level},
        {"LINES", board.linesCleared},
        {"TIME", MarathonRenderer.formatTime(marathonState.playTime)},
        {"MAX COMBO", marathonState.maxCombo}
    }
    
    local tspinTotal = MarathonRenderer.getTotalTSpins(marathonState)
    if tspinTotal > 0 then
        table.insert(stats, {"T-SPINS", tspinTotal})
    end
    
    for i, stat in ipairs(stats) do
        local y = startY + 100 + (i * lineHeight)
        drawTextFunc(stat[1] .. ": " .. tostring(stat[2]), centerX, y, 600, "center", {1, 1, 1, 0.8})
    end
end

function MarathonRenderer.formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    local centiseconds = math.floor((seconds % 1) * 100)
    return string.format("%02d:%02d.%02d", minutes, secs, centiseconds)
end

return MarathonRenderer
