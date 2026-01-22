-- src/systems/input.lua
-- Input handling with DAS/ARR
-- Supports keyboard and gamepad with action mapping

local Input = {
    keysJustPressed = {},
    buttonsJustPressed = {},
    keyTimers = {},
    buttonTimers = {},
    lastPressTimes = {},
    throttleDelay = 0.05, -- 50ms throttle to prevent double-clicks
    das = 0.167, -- Delay before auto-shift starts
    arr = 0.033, -- Auto-repeat rate
}

-- Check if any gamepad is down
local function isGamepadDown(button)
    local joysticks = love.joystick.getJoysticks()
    for _, joystick in ipairs(joysticks) do
        -- Only check if it's a valid gamepad button name to avoid errors
        -- LÖVE's isGamepadDown is generally safe but let's be careful
        local success, down = pcall(joystick.isGamepadDown, joystick, button)
        if success and down then
            return true
        end
    end
    return false
end

function Input:update(dt)
    -- Update repeat timers for held keys
    for key, _ in pairs(self.keyTimers) do
        if love.keyboard.isDown(key) then
            self.keyTimers[key] = self.keyTimers[key] + dt
        else
            self.keyTimers[key] = nil
        end
    end
    -- Update repeat timers for held buttons
    for button, _ in pairs(self.buttonTimers) do
        if isGamepadDown(button) then
            self.buttonTimers[button] = self.buttonTimers[button] + dt
        else
            self.buttonTimers[button] = nil
        end
    end
end

function Input:postUpdate()
    self.keysJustPressed = {}
    self.buttonsJustPressed = {}
end

function Input:wasKeyPressed(key)
    return self.keysJustPressed[key] == true
end

function Input:wasButtonPressed(button)
    return self.buttonsJustPressed[button] == true
end

-- Returns true if the key/button was just pressed OR if auto-repeat should trigger
function Input:shouldRepeat(keyOrButton, isGamepad)
    if isGamepad then
        if self:wasButtonPressed(keyOrButton) then return true end
        local timer = self.buttonTimers[keyOrButton]
        if timer and timer >= self.das then
            local repeatTime = timer - self.das
            if repeatTime >= self.arr then
                self.buttonTimers[keyOrButton] = self.das
                return true
            end
        end
    else
        if self:wasKeyPressed(keyOrButton) then return true end
        local timer = self.keyTimers[keyOrButton]
        if timer and timer >= self.das then
            local repeatTime = timer - self.das
            if repeatTime >= self.arr then
                self.keyTimers[keyOrButton] = self.das
                return true
            end
        end
    end
    
    return false
end

function Input:keyPressed(key)
    local now = love.timer.getTime()
    if self.lastPressTimes[key] and (now - self.lastPressTimes[key]) < self.throttleDelay then
        return
    end
    self.lastPressTimes[key] = now
    self.keysJustPressed[key] = true
    self.keyTimers[key] = 0
end

function Input:keyReleased(key)
    self.keyTimers[key] = nil
end

function Input:gamepadPressed(button)
    local now = love.timer.getTime()
    if self.lastPressTimes[button] and (now - self.lastPressTimes[button]) < self.throttleDelay then
        return
    end
    self.lastPressTimes[button] = now
    self.buttonsJustPressed[button] = true
    self.buttonTimers[button] = 0
end

function Input:gamepadReleased(button)
    self.buttonTimers[button] = nil
end

return Input
