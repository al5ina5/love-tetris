-- src/ui/stats.lua
-- UI Component for displaying match history and statistics

local Scores = require('src.data.scores')

local Stats = {}

function Stats.draw(menu, sw, sh, game)
    local stats = Scores.stats
    local history = Scores.history

    -- Title - match OPTIONS style
    love.graphics.setFont(game.fonts.medium)
    game:drawText("STATISTICS", 0, 60, sw, "center", {1, 1, 1})

    -- Summary Stats
    local y = 110
    local statsColor = {0.8, 1, 0.8}
    local labelColor = {0.7, 0.7, 0.7}
    
    -- High Score
    game:drawText("HIGH SCORE", 20, y, sw/2 - 40, "left", labelColor)
    game:drawText(tostring(stats.highScore), 20, y + 20, sw/2 - 40, "left", statsColor)
    
    -- Best Sprint
    local sprintText = stats.bestSprint > 0 and string.format("%.2fs", stats.bestSprint) or "N/A"
    game:drawText("BEST SPRINT", sw/2 + 20, y, sw/2 - 40, "left", labelColor)
    game:drawText(sprintText, sw/2 + 20, y + 20, sw/2 - 40, "left", statsColor)
    
    y = y + 50
    
    -- Marathon High Level
    game:drawText("MARATHON LVL", 20, y, sw/2 - 40, "left", labelColor)
    local marathonLvlText = stats.marathonHighLevel > 0 and tostring(stats.marathonHighLevel) or "N/A"
    game:drawText(marathonLvlText, 20, y + 20, sw/2 - 40, "left", statsColor)
    
    -- Marathon High Score
    game:drawText("MARATHON HI", sw/2 + 20, y, sw/2 - 40, "left", labelColor)
    local marathonScoreText = stats.marathonHighScore > 0 and tostring(stats.marathonHighScore) or "N/A"
    game:drawText(marathonScoreText, sw/2 + 20, y + 20, sw/2 - 40, "left", statsColor)
    
    y = y + 50
    
    -- Versus Stats
    game:drawText("VERSUS W/L", 20, y, sw/2 - 40, "left", labelColor)
    game:drawText(string.format("%d - %d", stats.versusWins, stats.versusLosses), 20, y + 20, sw/2 - 40, "left", statsColor)
    
    -- Total Games
    game:drawText("TOTAL GAMES", sw/2 + 20, y, sw/2 - 40, "left", labelColor)
    game:drawText(tostring(stats.totalGames), sw/2 + 20, y + 20, sw/2 - 40, "left", statsColor)

    y = y + 70
    
    -- Match History Header
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.line(20, y - 10, sw - 20, y - 10)
    game:drawText("MATCH HISTORY", 0, y, sw, "center", {1, 1, 1})
    y = y + 30

    -- Scrollable history
    local visibleCount = 6
    local historyIndex = menu.historyScrollIndex or 1
    
    if #history == 0 then
        game:drawText("NO MATCHES RECORDED", 0, y + 40, sw, "center", {0.5, 0.5, 0.5})
    else
        for i = historyIndex, math.min(#history, historyIndex + visibleCount - 1) do
            local match = history[i]
            local color = {0.8, 0.8, 0.8}
            if match.result == "WIN" or match.result == "FINISHED" then
                color = {0.6, 1, 0.6}
            elseif match.result == "LOSS" then
                color = {1, 0.6, 0.6}
            end
            
            local modeText = match.mode
            local resultText = match.result
            local detailText = ""
            
            if match.mode == "SPRINT" then
                detailText = string.format("%.2fs", match.time)
            elseif match.mode == "MARATHON" then
                detailText = string.format("LVL %d | %d", match.level or 0, match.score)
            else
                detailText = string.format("SCORE: %d", match.score)
            end
            
            local itemY = y + (i - historyIndex) * 36
            game:drawText(string.format("%s %s", modeText, resultText), 30, itemY, sw - 60, "left", color)
            game:drawText(detailText, 30, itemY, sw - 60, "right", {0.6, 0.6, 0.6})
            game:drawText(match.timestamp, 30, itemY, sw - 60, "center", {0.4, 0.4, 0.4})
        end
        
        -- Scroll indicators
        if historyIndex > 1 then
            game:drawText("^", sw - 30, y - 10, 20, "center", {1, 1, 0})
        end
        if historyIndex + visibleCount <= #history then
            game:drawText("v", sw - 30, y + (visibleCount * 36) - 30, 20, "center", {1, 1, 0})
        end
    end

    -- Back hint
    game:drawText("BACK (B/ESC)", 0, sh - 30, sw, "center", {0.5, 0.5, 0.5})
end

function Stats.handleKey(menu, key)
    local history = Scores.history
    local visibleCount = 6
    
    if key == "up" then
        menu.historyScrollIndex = math.max(1, (menu.historyScrollIndex or 1) - 1)
        return true
    elseif key == "down" then
        menu.historyScrollIndex = math.min(math.max(1, #history - visibleCount + 1), (menu.historyScrollIndex or 1) + 1)
        return true
    elseif key == "escape" or key == "z" or key == "backspace" then
        menu.state = menu.previousState or "main"
        return true
    end
    return false
end

function Stats.handleGamepad(menu, button)
    local history = Scores.history
    local visibleCount = 6
    
    if button == "dpup" then
        menu.historyScrollIndex = math.max(1, (menu.historyScrollIndex or 1) - 1)
        return true
    elseif button == "dpdown" then
        menu.historyScrollIndex = math.min(math.max(1, #history - visibleCount + 1), (menu.historyScrollIndex or 1) + 1)
        return true
    elseif button == "b" or button == "back" then
        menu.state = menu.previousState or "main"
        return true
    end
    return false
end

return Stats
