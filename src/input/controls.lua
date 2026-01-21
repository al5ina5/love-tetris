-- src/controls.lua
-- Control mapping management system

local Controls = {}

-- Action definitions
Controls.ACTIONS = {
    "move_left",
    "move_right",
    "move_down",
    "hard_drop",
    "rotate_cw",
    "rotate_ccw",
    "hold",
    "pause"
}

-- Default control mappings
Controls.defaults = {
    keyboard = {
        move_left = "left",
        move_right = "right",
        move_down = "down",
        hard_drop = "up",
        rotate_cw = "x",
        rotate_ccw = "z",
        hold = "a",
        pause = "escape"
    },
    gamepad = {
        move_left = "dpleft",
        move_right = "dpright",
        move_down = "dpdown",
        hard_drop = "dpup",
        rotate_cw = "a",
        rotate_ccw = "b",
        hold = "leftshoulder",
        pause = "start"
    }
}

-- Current mappings (loaded from settings)
Controls.current = {
    keyboard = {},
    gamepad = {}
}

-- Readable names for actions
Controls.actionNames = {
    move_left = "Move Left",
    move_right = "Move Right",
    move_down = "Soft Drop",
    hard_drop = "Hard Drop",
    rotate_cw = "Rotate CW",
    rotate_ccw = "Rotate CCW",
    hold = "Hold Piece",
    pause = "Pause"
}

-- Readable names for keys/buttons
Controls.keyNames = {
    -- Keyboard
    ["return"] = "ENTER",
    ["escape"] = "ESC",
    [" "] = "SPACE",
    ["space"] = "SPACE",
    ["left"] = "LEFT",
    ["right"] = "RIGHT",
    ["up"] = "UP",
    ["down"] = "DOWN",
    ["lshift"] = "L-SHIFT",
    ["rshift"] = "R-SHIFT",
    ["lctrl"] = "L-CTRL",
    ["rctrl"] = "R-CTRL",
    ["tab"] = "TAB",
    ["backspace"] = "BACKSPACE",
    
    -- Gamepad
    ["a"] = "A",
    ["b"] = "B",
    ["x"] = "X",
    ["y"] = "Y",
    ["dpup"] = "D-UP",
    ["dpdown"] = "D-DOWN",
    ["dpleft"] = "D-LEFT",
    ["dpright"] = "D-RIGHT",
    ["leftshoulder"] = "L",
    ["rightshoulder"] = "R",
    ["leftstick"] = "L-STICK",
    ["rightstick"] = "R-STICK",
    ["start"] = "START",
    ["back"] = "BACK",
    ["guide"] = "GUIDE"
}

function Controls.init()
    -- Initialize with defaults
    for device, mappings in pairs(Controls.defaults) do
        Controls.current[device] = {}
        for action, key in pairs(mappings) do
            Controls.current[device][action] = key
        end
    end
end

function Controls.load(savedControls)
    if not savedControls then
        Controls.init()
        return
    end
    
    -- Load saved controls, falling back to defaults for missing actions
    for device, mappings in pairs(Controls.defaults) do
        Controls.current[device] = Controls.current[device] or {}
        for action, defaultKey in pairs(mappings) do
            if savedControls[device] and savedControls[device][action] then
                Controls.current[device][action] = savedControls[device][action]
            else
                Controls.current[device][action] = defaultKey
            end
        end
    end
end

function Controls.save()
    return {
        keyboard = Controls.current.keyboard,
        gamepad = Controls.current.gamepad
    }
end

function Controls.setBinding(device, action, key)
    if not Controls.current[device] then return false end
    if not Controls.defaults[device][action] then return false end
    
    Controls.current[device][action] = key
    return true
end

function Controls.getBinding(device, action)
    if not Controls.current[device] then return nil end
    return Controls.current[device][action]
end

function Controls.resetToDefaults()
    Controls.init()
end

function Controls.resetDevice(device)
    if not Controls.defaults[device] then return end
    Controls.current[device] = {}
    for action, key in pairs(Controls.defaults[device]) do
        Controls.current[device][action] = key
    end
end

function Controls.getKeyName(key)
    local name = Controls.keyNames[key]
    if name then return name end
    return string.upper(key)
end

function Controls.getActionName(action)
    return Controls.actionNames[action] or action
end

-- Check if an action is triggered
function Controls.isActionPressed(action, Input)
    -- Check keyboard
    local keyboardKey = Controls.current.keyboard[action]
    if keyboardKey and Input:wasKeyPressed(keyboardKey) then
        return true
    end
    
    -- Check gamepad
    local gamepadButton = Controls.current.gamepad[action]
    if gamepadButton and Input:wasButtonPressed(gamepadButton) then
        return true
    end
    
    return false
end

-- Check if action should repeat (for movement)
function Controls.shouldActionRepeat(action, Input)
    -- Check keyboard
    local keyboardKey = Controls.current.keyboard[action]
    if keyboardKey and Input:shouldRepeat(keyboardKey, false) then
        return true
    end
    
    -- Check gamepad
    local gamepadButton = Controls.current.gamepad[action]
    if gamepadButton and Input:shouldRepeat(gamepadButton, true) then
        return true
    end
    
    return false
end

return Controls
