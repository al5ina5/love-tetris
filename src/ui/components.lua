-- src/ui/components.lua
-- Reusable UI components for menus

local Components = {}

-- Component: Confirmation dialog
function Components.drawDialog(game, sw, sh, title, message, options, selectedOption)
    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", sw/2 - 120, sh/2 - 60, 240, 120)
    
    -- Border
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", sw/2 - 120, sh/2 - 60, 240, 120)
    
    -- Title
    love.graphics.setFont(game.renderer.fonts.medium)
    game:drawText(title, sw/2 - 115, sh/2 - 50, 230, "center", {1, 1, 1})
    
    -- Message
    love.graphics.setFont(game.renderer.fonts.small)
    game:drawText(message, sw/2 - 115, sh/2 - 30, 230, "center", {0.8, 0.8, 0.8})
    
    -- Options
    love.graphics.setFont(game.renderer.fonts.medium)
    local optionY = sh/2 + 10
    for i, opt in ipairs(options) do
        local color = (i == selectedOption) and {1, 1, 0.5} or {0.7, 0.7, 0.7}
        local prefix = (i == selectedOption) and "> " or "  "
        game:drawText(prefix .. opt, sw/2 - 115, optionY, 230, "center", color)
        optionY = optionY + 15
    end
end

return Components
