-- src/game/input_handler.lua
-- Handles all keyboard and gamepad input for gameplay

local Controls = require('src.input.controls')
local Input = require('src.input.input_state')

local InputHandler = {}

function InputHandler.keypressed(key, game)
    -- Update input state first so Controls can check it
    Input:keyPressed(key)
    
    if game.menu:isVisible() then
        if game.menu:keypressed(key, game) then return end
    end
    
    -- Check pause action through Controls system only
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
