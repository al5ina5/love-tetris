-- src/ui/controls.lua
-- Modular controls customization screen for the menu system

local Controls = require('src.input.controls')
local Components = require('src.ui.components')

local ControlsUI = {}

function ControlsUI.init(menu)
    menu.controlsSelectedIndex = 1
    menu.controlsScrollOffset = 0
    menu.controlsWaitingForInput = false
    menu.controlsCurrentDevice = "keyboard" -- "keyboard" or "gamepad"
    menu.controlsSelectedAction = nil
    menu.controlsShowDialog = false
    menu.controlsDialogOption = 1
    
    ControlsUI.buildItems(menu)
end

function ControlsUI.buildItems(menu)
    local items = {}
    
    -- Device selector at top
    table.insert(items, {
        type = "device_selector",
        name = "CONTROLLER",
        getDisplay = function()
            return menu.controlsCurrentDevice == "keyboard" and "KEYBOARD" or "GAMEPAD"
        end
    })
    
    -- Separator for spacing
    table.insert(items, { type = "separator" })
    
    -- Action bindings
    for _, action in ipairs(Controls.ACTIONS) do
        table.insert(items, {
            type = "keybind",
            action = action,
            device = menu.controlsCurrentDevice,
            name = Controls.getActionName(action),
            getValue = function()
                local key = Controls.getBinding(menu.controlsCurrentDevice, action)
                return Controls.getKeyName(key)
            end
        })
    end
    
    -- Separator
    table.insert(items, { type = "separator" })
    
    -- Reset current controller
    table.insert(items, {
        type = "action",
        name = "RESET " .. (menu.controlsCurrentDevice == "keyboard" and "KEYBOARD" or "GAMEPAD"),
        action = "reset_device"
    })
    
    table.insert(items, { type = "back", name = "BACK" })
    
    menu.controlsItems = items
    
    -- Keep selection valid when rebuilding (device switch)
    if menu.controlsSelectedIndex > #items then
        menu.controlsSelectedIndex = 1
    end
end

function ControlsUI.draw(menu, sw, sh, game)
    -- Draw dialog if active
    if menu.controlsShowDialog then
        ControlsUI.drawDialog(menu, sw, sh, game)
        return
    end
    
    -- Title - match OPTIONS style
    game:drawText("CONTROLS", 0, 30, sw, "center", {1, 1, 1})
    
    -- Draw items - match OPTIONS style (startY=60, spacing=18)
    local startY = 60
    local spacing = 18
    local visibleCount = 9  -- Adjusted for spacing
    
    -- Smooth scrolling: keep selected item visible with minimal movement
    if menu.controlsSelectedIndex > menu.controlsScrollOffset + visibleCount then
        menu.controlsScrollOffset = menu.controlsScrollOffset + 1
    elseif menu.controlsSelectedIndex <= menu.controlsScrollOffset then
        menu.controlsScrollOffset = math.max(0, menu.controlsScrollOffset - 1)
    end
    
    local y = startY
    for i = menu.controlsScrollOffset + 1, math.min(#menu.controlsItems, menu.controlsScrollOffset + visibleCount) do
        local item = menu.controlsItems[i]
        local isSelected = (i == menu.controlsSelectedIndex)
        local color = isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8}
        local prefix = isSelected and "> " or "  "
        
        if item.type == "device_selector" then
            -- Device selector - match OPTIONS style
            local text = prefix .. item.name
            game:drawText(text, 20, y, sw - 40, "left", color)
            game:drawText(item.getDisplay(), 20, y, sw - 60, "right", color)
        elseif item.type == "keybind" then
            -- Match OPTIONS style: simple left-aligned name, right-aligned value
            local text = prefix .. item.name
            game:drawText(text, 20, y, sw - 40, "left", color)
            
            local valueText = item.getValue()
            if menu.controlsWaitingForInput and isSelected then
                valueText = "PRESS KEY..."
                color = {1, 0.5, 0.5}
            end
            game:drawText(valueText, 20, y, sw - 60, "right", color)
        elseif item.type == "action" or item.type == "back" then
            game:drawText(prefix .. item.name, 20, y, sw - 40, "left", color)
        elseif item.type == "separator" then
            y = y - 8 -- Just add space, no visual
        end
        
        y = y + spacing
    end
    
    -- Scroll indicators - match OPTIONS clean style
    if menu.controlsScrollOffset > 0 then
        game:drawText("^", sw - 20, startY - 15, 10, "center", {1, 1, 0.5})
    end
    if menu.controlsScrollOffset + visibleCount < #menu.controlsItems then
        game:drawText("v", sw - 20, startY + visibleCount * spacing - 5, 10, "center", {1, 1, 0.5})
    end
end

function ControlsUI.drawDialog(menu, sw, sh, game)
    -- First draw the controls menu in the background
    game:drawText("CONTROLS", 0, 30, sw, "center", {1, 1, 1})
    
    local startY = 60
    local spacing = 18
    local visibleCount = 9
    
    local y = startY
    for i = menu.controlsScrollOffset + 1, math.min(#menu.controlsItems, menu.controlsScrollOffset + visibleCount) do
        local item = menu.controlsItems[i]
        local isSelected = (i == menu.controlsSelectedIndex)
        local color = {0.5, 0.5, 0.5} -- Dimmed
        local prefix = isSelected and "> " or "  "
        
        if item.type == "device_selector" then
            local text = prefix .. item.name
            game:drawText(text, 20, y, sw - 40, "left", color)
            game:drawText(item.getDisplay(), 20, y, sw - 60, "right", color)
        elseif item.type == "keybind" then
            local text = prefix .. item.name
            game:drawText(text, 20, y, sw - 40, "left", color)
            game:drawText(item.getValue(), 20, y, sw - 60, "right", color)
        elseif item.type == "action" or item.type == "back" then
            game:drawText(prefix .. item.name, 20, y, sw - 40, "left", color)
        elseif item.type == "separator" then
            y = y - 8
        end
        
        y = y + spacing
    end
    
    -- Then draw the dialog on top
    Components.drawDialog(
        game, sw, sh,
        "RESET CONTROLS",
        "Are you sure?",
        {"YES", "NO"},
        menu.controlsDialogOption
    )
end

function ControlsUI.handleKey(menu, key, onSettingChanged)
    local onControlsChanged = menu.onControlsChanged or onSettingChanged
    
    -- Handle dialog
    if menu.controlsShowDialog then
        return ControlsUI.handleDialogKey(menu, key, onControlsChanged)
    end
    
    -- Waiting for key binding
    if menu.controlsWaitingForInput then
        if key == "escape" then
            menu.controlsWaitingForInput = false
            menu.controlsSelectedAction = nil
            return true
        end
        
        -- Bind the key
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item and item.type == "keybind" then
            Controls.setBinding(item.device, item.action, key)
            menu.controlsWaitingForInput = false
            menu.controlsSelectedAction = nil
            if onControlsChanged then
                onControlsChanged()
            end
        end
        return true
    end
    
    -- Normal navigation
    if key == "up" then
        repeat
            menu.controlsSelectedIndex = math.max(1, menu.controlsSelectedIndex - 1)
            local item = menu.controlsItems[menu.controlsSelectedIndex]
        until not item or (item.type ~= "section" and item.type ~= "separator")
        return true
    elseif key == "down" then
        repeat
            menu.controlsSelectedIndex = math.min(#menu.controlsItems, menu.controlsSelectedIndex + 1)
            local item = menu.controlsItems[menu.controlsSelectedIndex]
        until not item or (item.type ~= "section" and item.type ~= "separator")
        return true
    elseif key == "left" or key == "right" then
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item and item.type == "device_selector" then
            menu.controlsCurrentDevice = (menu.controlsCurrentDevice == "keyboard") and "gamepad" or "keyboard"
            ControlsUI.buildItems(menu)
            return true
        end
    elseif key == "return" or key == "space" then
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item then
            if item.type == "device_selector" then
                menu.controlsCurrentDevice = (menu.controlsCurrentDevice == "keyboard") and "gamepad" or "keyboard"
                ControlsUI.buildItems(menu)
                return true
            elseif item.type == "keybind" then
                menu.controlsWaitingForInput = true
                menu.controlsSelectedAction = item.action
                return true
            elseif item.type == "action" then
                if item.action == "reset_device" then
                    menu.controlsShowDialog = true
                    menu.controlsDialogOption = 2 -- Default to NO
                    menu.controlsDialogAction = "reset_device"
                end
                return true
            elseif item.type == "back" then
                return ControlsUI.back(menu)
            end
        end
    elseif key == "escape" or key == "z" then
        return ControlsUI.back(menu)
    end
    
    return false
end

function ControlsUI.handleDialogKey(menu, key, onControlsChanged)
    if key == "left" or key == "right" then
        menu.controlsDialogOption = (menu.controlsDialogOption == 1) and 2 or 1
        return true
    elseif key == "return" or key == "space" or key == "x" then
        if menu.controlsDialogOption == 1 then
            -- YES - reset the current device
            if menu.controlsDialogAction == "reset_device" then
                Controls.resetDevice(menu.controlsCurrentDevice)
                ControlsUI.buildItems(menu)
                if onControlsChanged then
                    onControlsChanged()
                end
            end
        end
        menu.controlsShowDialog = false
        menu.controlsDialogAction = nil
        return true
    elseif key == "escape" or key == "z" then
        menu.controlsShowDialog = false
        menu.controlsDialogAction = nil
        return true
    end
    return false
end

function ControlsUI.handleGamepad(menu, button, onSettingChanged)
    local onControlsChanged = menu.onControlsChanged or onSettingChanged
    
    -- Handle dialog
    if menu.controlsShowDialog then
        return ControlsUI.handleDialogGamepad(menu, button, onControlsChanged)
    end
    
    -- Waiting for gamepad binding
    if menu.controlsWaitingForInput then
        if button == "back" then
            menu.controlsWaitingForInput = false
            menu.controlsSelectedAction = nil
            return true
        end
        
        -- Bind the button
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item and item.type == "keybind" then
            Controls.setBinding(item.device, item.action, button)
            menu.controlsWaitingForInput = false
            menu.controlsSelectedAction = nil
            if onControlsChanged then
                onControlsChanged()
            end
        end
        return true
    end
    
    -- Normal navigation
    if button == "dpup" then
        repeat
            menu.controlsSelectedIndex = math.max(1, menu.controlsSelectedIndex - 1)
            local item = menu.controlsItems[menu.controlsSelectedIndex]
        until not item or (item.type ~= "section" and item.type ~= "separator")
        return true
    elseif button == "dpdown" then
        repeat
            menu.controlsSelectedIndex = math.min(#menu.controlsItems, menu.controlsSelectedIndex + 1)
            local item = menu.controlsItems[menu.controlsSelectedIndex]
        until not item or (item.type ~= "section" and item.type ~= "separator")
        return true
    elseif button == "dpleft" or button == "dpright" then
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item and item.type == "device_selector" then
            menu.controlsCurrentDevice = (menu.controlsCurrentDevice == "keyboard") and "gamepad" or "keyboard"
            ControlsUI.buildItems(menu)
            return true
        end
    elseif button == "a" or button == "start" then
        local item = menu.controlsItems[menu.controlsSelectedIndex]
        if item then
            if item.type == "device_selector" then
                menu.controlsCurrentDevice = (menu.controlsCurrentDevice == "keyboard") and "gamepad" or "keyboard"
                ControlsUI.buildItems(menu)
                return true
            elseif item.type == "keybind" then
                menu.controlsWaitingForInput = true
                menu.controlsSelectedAction = item.action
                return true
            elseif item.type == "action" then
                if item.action == "reset_device" then
                    menu.controlsShowDialog = true
                    menu.controlsDialogOption = 2
                    menu.controlsDialogAction = "reset_device"
                end
                return true
            elseif item.type == "back" then
                return ControlsUI.back(menu)
            end
        end
    elseif button == "b" or button == "back" then
        return ControlsUI.back(menu)
    end
    
    return false
end

function ControlsUI.handleDialogGamepad(menu, button, onControlsChanged)
    if button == "dpleft" or button == "dpright" then
        menu.controlsDialogOption = (menu.controlsDialogOption == 1) and 2 or 1
        return true
    elseif button == "a" then
        if menu.controlsDialogOption == 1 then
            -- YES - reset the current device
            if menu.controlsDialogAction == "reset_device" then
                Controls.resetDevice(menu.controlsCurrentDevice)
                ControlsUI.buildItems(menu)
                if onControlsChanged then
                    onControlsChanged()
                end
            end
        end
        menu.controlsShowDialog = false
        menu.controlsDialogAction = nil
        return true
    elseif button == "b" or button == "back" then
        menu.controlsShowDialog = false
        menu.controlsDialogAction = nil
        return true
    end
    return false
end

function ControlsUI.back(menu)
    -- Return to options menu
    menu.state = menu.STATE.OPTIONS
    menu.optionsSelectedIndex = 1 -- CONTROLS item position in options (now at top)
    return true
end

return ControlsUI
