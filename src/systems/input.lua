-- src/systems/input.lua
-- Input handling for Tetris

local Input = {
    keysJustPressed = {},
}

function Input:update()
    self.keysJustPressed = {}
end

function Input:isDown(key)
    return love.keyboard.isDown(key)
end

function Input:wasPressed(key)
    return self.keysJustPressed[key] == true
end

function Input:keyPressed(key)
    self.keysJustPressed[key] = true
end

function Input:keyReleased(key)
    -- Not strictly needed for basic Tetris but here for completeness
end

return Input

