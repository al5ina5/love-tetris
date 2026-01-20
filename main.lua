-- main.lua
-- Entry point for the LÖVE2D game (like index.js in Node.js)

local Game = require('src.game')

function love.load()
    -- Pixel-art friendly graphics settings
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Set window title (Sirtet)
    love.window.setTitle("Sirtet")

    -- Initialize game
    Game:load()
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    -- Draw the game directly using the full window space
    Game:draw()
end

-- Input event (like an event listener)
function love.keypressed(key)
    Game:keypressed(key)
end

function love.gamepadpressed(joystick, button)
    Game:gamepadpressed(button)
end

-- Clean up on exit
function love.quit()
    Game:quit()
end