-- src/ui/menu/room_code_input.lua
-- Room code input screen using digit picker

local DigitPicker = require('src.ui.components.digit_picker')

local RoomCodeInput = {}

function RoomCodeInput.init(menu)
    menu.roomCodePicker = DigitPicker.new({
        length = 6,
        charset = "0123456789",
        separators = {},
        label = "ENTER ROOM CODE"
    })
end

function RoomCodeInput.draw(menu, sw, sh, game)
    -- Use the picker's draw method
    menu.roomCodePicker:draw(game, sw, sh)
    
    -- Instructions
    if menu.fonts then love.graphics.setFont(menu.fonts.small) end
    game:drawText("Use D-PAD to enter 6-digit code", 0, sh - 50, sw, "center", {0.6, 0.6, 0.6})
    game:drawText("A/ENTER to JOIN  •  B/ESC to BACK", 0, sh - 30, sw, "center", {0.6, 0.6, 0.6})
end

function RoomCodeInput.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    -- Let picker handle navigation and input
    if menu.roomCodePicker:handleKey(key) then
        return true
    end
    
    -- Submit
    if key == "return" or key == "space" or key == "x" then
        return RoomCodeInput.submit(menu)
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 2
        return true
    end
    
    return false
end

function RoomCodeInput.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    -- Let picker handle navigation
    if menu.roomCodePicker:handleGamepad(button) then
        return true
    end
    
    -- Submit
    if button == "a" then
        return RoomCodeInput.submit(menu)
    elseif button == "b" or button == "back" then
        menu.state = Base.STATE.SUBMENU_ONLINE
        menu.selectedIndex = 2
        return true
    end
    
    return false
end

function RoomCodeInput.submit(menu)
    local code = menu.roomCodePicker:getValue()
    
    -- Validate code (must be 6 digits)
    if #code == 6 then
        if menu.onJoinOnline then
            menu.onJoinOnline(code)
        end
        return true
    end
    
    return false
end

return RoomCodeInput
