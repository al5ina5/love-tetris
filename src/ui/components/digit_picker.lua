-- src/ui/components/digit_picker.lua
-- Reusable digit/character picker component for gamepad-friendly input

local DigitPicker = {}
DigitPicker.__index = DigitPicker

-- Create a new digit picker
-- config: {
--   length: number of digits/characters
--   charset: string of allowed characters (e.g., "0123456789" or "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
--   separators: table of {position = separator_char} (e.g., {[3]=".", [6]=".", [9]="."} for IP)
--   label: title text
-- }
function DigitPicker.new(config)
    local picker = {
        length = config.length or 6,
        charset = config.charset or "0123456789",
        separators = config.separators or {},
        label = config.label or "ENTER CODE",
        
        values = {},  -- Current digit values (indices into charset)
        selectedIndex = 1,  -- Currently selected position
    }
    
    -- Initialize all values to first character in charset
    for i = 1, picker.length do
        picker.values[i] = 1
    end
    
    setmetatable(picker, DigitPicker)
    return picker
end

-- Get current value as string
function DigitPicker:getValue()
    local result = ""
    for i = 1, self.length do
        result = result .. self.charset:sub(self.values[i], self.values[i])
    end
    return result
end

-- Set value from string
function DigitPicker:setValue(str)
    for i = 1, math.min(#str, self.length) do
        local char = str:sub(i, i)
        local pos = self.charset:find(char, 1, true)
        if pos then
            self.values[i] = pos
        end
    end
end

-- Move to next/previous digit
function DigitPicker:moveLeft()
    self.selectedIndex = math.max(1, self.selectedIndex - 1)
end

function DigitPicker:moveRight()
    self.selectedIndex = math.min(self.length, self.selectedIndex + 1)
end

-- Cycle current digit up/down
function DigitPicker:cycleUp()
    self.values[self.selectedIndex] = self.values[self.selectedIndex] % #self.charset + 1
end

function DigitPicker:cycleDown()
    self.values[self.selectedIndex] = self.values[self.selectedIndex] - 1
    if self.values[self.selectedIndex] < 1 then
        self.values[self.selectedIndex] = #self.charset
    end
end

-- Handle keyboard input (returns true if handled)
function DigitPicker:handleKey(key)
    if key == "left" then
        self:moveLeft()
        return true
    elseif key == "right" then
        self:moveRight()
        return true
    elseif key == "up" then
        self:cycleUp()
        return true
    elseif key == "down" then
        self:cycleDown()
        return true
    elseif key == "backspace" then
        if self.selectedIndex > 1 then
            self.selectedIndex = self.selectedIndex - 1
        end
        return true
    end
    
    -- Direct character input
    local char = key:upper()
    if #key == 1 then
        local pos = self.charset:find(char, 1, true)
        if pos then
            self.values[self.selectedIndex] = pos
            self.selectedIndex = math.min(self.length, self.selectedIndex + 1)
            return true
        end
    end
    
    -- Numpad support
    local digit = tonumber(key)
    if not digit and key:sub(1, 2) == "kp" then
        digit = tonumber(key:sub(3))
    end
    if digit then
        local digitChar = tostring(digit)
        local pos = self.charset:find(digitChar, 1, true)
        if pos then
            self.values[self.selectedIndex] = pos
            self.selectedIndex = math.min(self.length, self.selectedIndex + 1)
            return true
        end
    end
    
    return false
end

-- Handle gamepad input (returns true if handled)
function DigitPicker:handleGamepad(button)
    if button == "dpleft" then
        self:moveLeft()
        return true
    elseif button == "dpright" then
        self:moveRight()
        return true
    elseif button == "dpup" then
        self:cycleUp()
        return true
    elseif button == "dpdown" then
        self:cycleDown()
        return true
    end
    return false
end

-- Draw the picker
function DigitPicker:draw(game, sw, sh)
    -- Draw label
    game:drawText(self.label, 0, 60, sw, "center", {1, 1, 1})
    
    local digitWidth = 28
    local spacing = 4
    
    -- Calculate total width including separators
    local totalWidth = (digitWidth * self.length) + (spacing * (self.length - 1))
    for _, sep in pairs(self.separators) do
        totalWidth = totalWidth + 20
    end
    
    local startX = (sw - totalWidth) / 2
    local y = sh / 2 - 20
    
    local xOffset = 0
    for i = 1, self.length do
        local x = startX + xOffset
        local isSelected = (i == self.selectedIndex)
        
        -- Highlight selected digit
        if isSelected then
            love.graphics.setColor(0.3, 0.3, 0.5)
            love.graphics.rectangle("fill", x - 4, y - 10, digitWidth + 8, 60)
            
            -- Up/down arrows
            game:drawText("^", x, y - 40, digitWidth, "center", {1, 1, 0.5})
            game:drawText("v", x, y + 50, digitWidth, "center", {1, 1, 0.5})
        end
        
        -- Draw digit/character
        love.graphics.setColor(1, 1, 1)
        local char = self.charset:sub(self.values[i], self.values[i])
        game:drawText(char, x, y, digitWidth, "center", isSelected and {1, 1, 0.5} or {0.8, 0.8, 0.8})
        
        xOffset = xOffset + digitWidth + spacing
        
        -- Draw separator if configured
        if self.separators[i] then
            local sepX = x + digitWidth + spacing
            game:drawText(self.separators[i], sepX, y, 20, "center", {0.5, 0.5, 0.5})
            xOffset = xOffset + 20
        end
    end
end

return DigitPicker
