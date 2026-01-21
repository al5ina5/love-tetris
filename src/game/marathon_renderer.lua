-- src/game/marathon_renderer.lua
-- Renders Marathon-specific HUD elements

local MarathonRenderer = {}

function MarathonRenderer.drawHUD(marathonState, board, fonts, sw, sh, drawTextFunc)
    local CONST = require('src.constants')
    
    -- Calculate positions
    local rightX = sw - 20
    local topY = 100
    local lineHeight = 40
    
    -- Time display (formatted as MM:SS.MS)
    local totalSeconds = marathonState.playTime
    local minutes = math.floor(totalSeconds / 60)
    local seconds = math.floor(totalSeconds % 60)
    local centiseconds = math.floor((totalSeconds % 1) * 100)
    local timeStr = string.format("%02d:%02d.%02d", minutes, seconds, centiseconds)
    
    drawTextFunc("TIME", rightX, topY, 200, "right", {1, 1, 1, 0.6})
    drawTextFunc(timeStr, rightX, topY + 20, 200, "right", {1, 1, 1, 1})
    
    -- Level with progress
    local levelY = topY + 80
    drawTextFunc("LEVEL", rightX, levelY, 200, "right", {1, 1, 1, 0.6})
    drawTextFunc(tostring(board.level), rightX, levelY + 20, 200, "right", {0.3, 1, 0.3, 1})
    
    -- Progress to next level (0-10 lines)
    local progress = (board.linesCleared % 10) / 10
    local barWidth = 100
    local barHeight = 6
    local barX = rightX - barWidth
    local barY = levelY + 60
    
    -- Background bar
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Progress bar
    love.graphics.setColor(0.3, 1, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
    
    -- Lines display
    local linesY = levelY + 80
    drawTextFunc("LINES", rightX, linesY, 200, "right", {1, 1, 1, 0.6})
    drawTextFunc(tostring(board.linesCleared), rightX, linesY + 20, 200, "right", {1, 1, 1, 1})
    
    -- Max combo
    local comboY = linesY + 80
    drawTextFunc("MAX COMBO", rightX, comboY, 200, "right", {1, 1, 1, 0.6})
    local comboColor = marathonState.maxCombo > 5 and {1, 0.7, 0.3, 1} or {1, 1, 1, 1}
    drawTextFunc(tostring(marathonState.maxCombo), rightX, comboY + 20, 200, "right", comboColor)
    
    -- T-spins
    local tspinTotal = MarathonRenderer.getTotalTSpins(marathonState)
    if tspinTotal > 0 then
        local tspinY = comboY + 80
        drawTextFunc("T-SPINS", rightX, tspinY, 200, "right", {1, 1, 1, 0.6})
        drawTextFunc(tostring(tspinTotal), rightX, tspinY + 20, 200, "right", {0.7, 0.3, 1, 1})
    end
end

function MarathonRenderer.getTotalTSpins(state)
    return state.tspinsSingle + state.tspinsDouble + state.tspinsTriple
end

function MarathonRenderer.drawGameOver(marathonState, board, fonts, sw, sh, drawTextFunc)
    -- Draw final statistics
    local centerX = sw / 2
    local startY = sh / 2 - 100
    local lineHeight = 35
    
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
        local y = startY + 50 + (i * lineHeight)
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
