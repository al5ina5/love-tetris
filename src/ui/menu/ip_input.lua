-- src/ui/menu/ip_input.lua
-- IP address input screen with digit editor

local IPInput = {}

function IPInput.draw(menu, sw, sh, game)
    game:drawText("JOIN BY IP", 0, 30, sw, "center", {1, 1, 1})
    
    local digitWidth = 14
    local spacing = 2
    local groupSpacing = 12
    local totalWidth = (digitWidth * 12) + (spacing * 8) + (groupSpacing * 3)
    local startX = (sw - totalWidth) / 2
    local y = sh / 2 - 10
    
    for i = 1, 12 do
        local group = math.floor((i-1) / 3)
        local groupOffset = group * groupSpacing
        local x = startX + (i - 1) * (digitWidth + spacing) + groupOffset
        local isSelected = (i == menu.selectedDigit)
        
        if isSelected then
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", x - 2, y - 5, digitWidth + 4, 30)
            
            game:drawText("^", x, y - 20, digitWidth, "center", {1, 1, 0.5})
            game:drawText("v", x, y + 25, digitWidth, "center", {1, 1, 0.5})
        end
        
        love.graphics.setColor(1, 1, 1)
        game:drawText(tostring(menu.ipDigits[i]), x, y, digitWidth, "center", isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8})
        
        if i % 3 == 0 and i < 12 then
            game:drawText(".", x + digitWidth, y, groupSpacing, "center", {0.5, 0.5, 0.5})
        end
    end
end

function IPInput.handleKey(menu, key)
    local Base = require('src.ui.menu.base')
    
    if key == "left" then
        menu.selectedDigit = math.max(1, menu.selectedDigit - 1)
        return true
    elseif key == "right" then
        menu.selectedDigit = math.min(12, menu.selectedDigit + 1)
        return true
    elseif key == "up" then
        menu.ipDigits[menu.selectedDigit] = (menu.ipDigits[menu.selectedDigit] + 1) % 10
        return true
    elseif key == "down" then
        menu.ipDigits[menu.selectedDigit] = (menu.ipDigits[menu.selectedDigit] - 1) % 10
        if menu.ipDigits[menu.selectedDigit] < 0 then menu.ipDigits[menu.selectedDigit] = 9 end
        return true
    elseif key == "backspace" then
        if menu.selectedDigit > 1 then
            menu.selectedDigit = menu.selectedDigit - 1
        end
        return true
    elseif key == "." or key == "kp." then
        local currentOctet = math.floor((menu.selectedDigit - 1) / 3)
        if currentOctet < 3 then
            menu.selectedDigit = (currentOctet + 1) * 3 + 1
        end
        return true
    end

    -- Number keys
    local digit = tonumber(key)
    if not digit and key:sub(1, 2) == "kp" then
        digit = tonumber(key:sub(3))
    end

    if digit then
        menu.ipDigits[menu.selectedDigit] = digit
        menu.selectedDigit = math.min(12, menu.selectedDigit + 1)
        return true
    end

    if key == "return" or key == "space" or key == "x" then
        return IPInput.submit(menu)
    elseif key == "escape" or key == "z" then
        menu.state = Base.STATE.SUBMENU_MULTIPLAYER
        menu.selectedIndex = 3  -- JOIN BY IP is 3rd in multiplayer submenu
        return true
    end
    return false
end

function IPInput.handleGamepad(menu, button)
    local Base = require('src.ui.menu.base')
    
    if button == "dpleft" then
        menu.selectedDigit = math.max(1, menu.selectedDigit - 1)
        return true
    elseif button == "dpright" then
        menu.selectedDigit = math.min(12, menu.selectedDigit + 1)
        return true
    elseif button == "dpup" then
        menu.ipDigits[menu.selectedDigit] = (menu.ipDigits[menu.selectedDigit] + 1) % 10
        return true
    elseif button == "dpdown" then
        menu.ipDigits[menu.selectedDigit] = (menu.ipDigits[menu.selectedDigit] - 1) % 10
        if menu.ipDigits[menu.selectedDigit] < 0 then menu.ipDigits[menu.selectedDigit] = 9 end
        return true
    elseif button == "a" then
        return IPInput.submit(menu)
    elseif button == "b" or button == "back" then
        menu.state = Base.STATE.SUBMENU_MULTIPLAYER
        menu.selectedIndex = 3  -- JOIN BY IP is 3rd in multiplayer submenu
        return true
    end
    return false
end

function IPInput.submit(menu)
    local Base = require('src.ui.menu.base')
    
    -- Convert 12 digits to IP address
    local octets = {}
    for i = 1, 4 do
        local start = (i-1)*3 + 1
        local val = menu.ipDigits[start]*100 + menu.ipDigits[start+1]*10 + menu.ipDigits[start+2]
        table.insert(octets, math.min(255, val))
    end
    local ip = table.concat(octets, ".")
    menu.state = Base.STATE.CONNECTING
    menu.selectedServer = {name = "Custom IP", ip = ip, port = 12345}
    
    -- Save the last IP
    if menu.onSettingChanged then
        menu.onSettingChanged("lastIP", ip)
    end

    if menu.onJoin then
        menu.onJoin(ip, 12345)
    end
    return true
end

return IPInput
