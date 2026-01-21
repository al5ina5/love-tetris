-- src/game/input_handler.lua
-- Handles all keyboard and gamepad input for gameplay

local Controls = require('src.input.controls')
local Input = require('src.input.input_state')
local StateManager = require('src.game.state_manager')

local InputHandler = {}

function InputHandler.keypressed(key, game)
    -- Ignore GUI/Command/Super keys - they're OS-level shortcuts, not game input
    if key == "lgui" or key == "rgui" then
        return
    end
    
    -- Update input state first so Controls can check it
    Input:keyPressed(key)
    
    -- Check for game over dismissal (any key dismisses after delay)
    if game.state == "over" and not game.menu:isVisible() then
        if StateManager.dismissGameOver(game.stateManager, game) then
            return
        end
    end
    
    -- During disconnected pause, allow skipping with any key
    if game.state == "disconnected_pause" and not game.menu:isVisible() then
        StateManager.resumeAsSinglePlayer(game.stateManager, game)
        return
    end
    
    if game.menu:isVisible() then
        -- When menu is visible, only process menu input
        -- Don't fall through to game controls even if key wasn't handled
        game.menu:keypressed(key, game)
        return
    end
    
    -- Check pause action through Controls system only (when menu not visible)
    if Controls.isActionPressed("pause", Input) then
        InputHandler.handlePause(game)
    end
end

function InputHandler.keyreleased(key, game)
    Input:keyReleased(key)
end

function InputHandler.gamepadpressed(button, game)
    -- Update input state first so Controls can check it
    Input:gamepadPressed(button)
    
    -- Check for game over dismissal (any button dismisses after delay)
    if game.state == "over" and not game.menu:isVisible() then
        if StateManager.dismissGameOver(game.stateManager, game) then
            return
        end
    end
    
    -- During disconnected pause, allow skipping with any button
    if game.state == "disconnected_pause" and not game.menu:isVisible() then
        StateManager.resumeAsSinglePlayer(game.stateManager, game)
        return
    end
    
    if game.menu:isVisible() then
        if game.menu:gamepadpressed(button, game) then return end
    end
    
    -- Check pause action through Controls system only
    if Controls.isActionPressed("pause", Input) then
        InputHandler.handlePause(game)
    end
end

function InputHandler.gamepadreleased(button, game)
    Input:gamepadReleased(button)
end

function InputHandler.handlePause(game)
    if game.state == "playing" or game.state == "countdown" or game.state == "over" then
        if game.menu:isVisible() then
            game.menu:hide()
        else
            game.menu:show(game.menu.STATE.PAUSE)
        end
    else
        -- In WAITING or other states
        if game.menu:isVisible() then
            game.menu:hide()
        else
            game.menu:show()
        end
    end
end

return InputHandler
