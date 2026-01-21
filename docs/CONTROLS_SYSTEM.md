# Controls Customization System

> **UPDATE**: Controls have been integrated into the Options menu as a submenu. Access via **Main Menu → OPTIONS → CONTROLS** or **Pause Menu → OPTIONS → CONTROLS**.

## Overview

A fully modular, reusable controls customization system has been added to Sirtet. The system follows the existing architecture pattern (Options, Stats) and provides comprehensive key rebinding for both keyboard and gamepad. Controls are now organized as a setting within the Options menu for better UX.

---

## Architecture

### Core Components

1. **`src/controls.lua`** - Control mapping management
   - Defines all game actions
   - Manages default and current mappings
   - Provides save/load functionality
   - Offers helper functions for action checking

2. **`src/ui/components.lua`** - Reusable UI components
   - List renderer with selection
   - Setting renderer (toggle, slider, select, keybind)
   - Section headers
   - Scroll indicators
   - Help text
   - Confirmation dialogs

3. **`src/ui/controls.lua`** - Controls submenu UI module
   - Device selector (keyboard/gamepad)
   - Action binding interface
   - Reset options (per-device or all)
   - Confirmation dialogs
   - Accessible through Options menu
   - Follows the Options/Stats module pattern

---

## Features

### ✅ Implemented

- **Dual Device Support**: Separate mappings for keyboard and gamepad
- **8 Customizable Actions**:
  - Move Left
  - Move Right
  - Soft Drop
  - Hard Drop
  - Rotate CW (Clockwise)
  - Rotate CCW (Counter-clockwise)
  - Hold Piece
  - Pause

- **User-Friendly Interface**:
  - Device switcher to toggle between keyboard/gamepad bindings
  - Real-time key capture ("Press key..." prompt)
  - Readable key names (e.g., "ESC" instead of "escape")
  - Scrollable action list
  - Confirmation dialogs for reset operations

- **Persistence**: Settings saved in Lua table format
- **Reset Options**: Reset individual device or all controls to defaults
- **Integration**: Accessible from main menu, pause menu, and options

---

## Usage

### For Players

1. Navigate to **Main Menu → OPTIONS → CONTROLS** or **Pause Menu → OPTIONS → CONTROLS**
2. Select **DEVICE** to switch between keyboard and gamepad
3. Navigate to an action and press **ENTER**
4. Press the desired key/button to bind it
5. Use **RESET KEYBOARD/GAMEPAD** to restore defaults for one device
6. Use **RESET ALL TO DEFAULTS** to restore all bindings

### For Developers

#### Adding a New Action

1. Add to `Controls.ACTIONS` array:
```lua
Controls.ACTIONS = {
    -- ... existing actions
    "new_action",
}
```

2. Add default bindings:
```lua
Controls.defaults = {
    keyboard = {
        -- ... existing
        new_action = "key",
    },
    gamepad = {
        -- ... existing
        new_action = "button",
    }
}
```

3. Add readable name:
```lua
Controls.actionNames = {
    -- ... existing
    new_action = "New Action Name",
}
```

4. Use in game logic:
```lua
if Controls.isActionPressed("new_action", Input) then
    -- Do something
end

-- Or for repeated actions (movement):
if Controls.shouldActionRepeat("new_action", Input) then
    -- Do something repeatedly
end
```

#### Creating Reusable UI Components

Use the `Components` module for consistent UI across menus:

```lua
local Components = require('src.ui.components')

-- Draw a list
Components.drawList(game, sw, sh, "Title", "Subtitle", items, selectedIndex)

-- Draw a setting
Components.drawSetting(game, x, y, width, "Name", value, "toggle", isSelected)

-- Draw section header
Components.drawSectionHeader(game, "Section Name", y, sw)

-- Draw help text
Components.drawHelpText(game, "Press ESC to back", sw, sh)

-- Draw confirmation dialog
Components.drawDialog(game, sw, sh, "Title", "Message", {"YES", "NO"}, selectedOption)
```

---

## Technical Details

### Control Mapping Flow

```
User Input → Input System → Controls Module → Game Logic
                 ↓
            Key/Button
                 ↓
         Controls.isActionPressed("action", Input)
                 ↓
         Checks both keyboard and gamepad mappings
                 ↓
            Returns true/false
```

### Settings Storage

Controls are stored in `settings.txt` as a Lua table:

```lua
{
  ["controls"] = {
    ["keyboard"] = {
      ["move_left"] = "left",
      ["move_right"] = "right",
      -- ...
    },
    ["gamepad"] = {
      ["move_left"] = "dpleft",
      ["move_right"] = "dpright",
      -- ...
    },
  },
  -- ... other settings
}
```

### Module Pattern

The controls UI follows the established pattern:

```lua
local ControlsUI = {}

function ControlsUI.init(menu) end
function ControlsUI.buildItems(menu) end
function ControlsUI.draw(menu, sw, sh, game) end
function ControlsUI.handleKey(menu, key) end
function ControlsUI.handleGamepad(menu, button) end
function ControlsUI.back(menu) end

return ControlsUI
```

---

## Files Modified

1. **New Files**:
   - `src/controls.lua` - Core control mapping system
   - `src/ui/components.lua` - Reusable UI components
   - `src/ui/controls.lua` - Controls menu UI module

2. **Updated Files**:
   - `src/settings.lua` - Enhanced to support complex data structures (Lua table serialization)
   - `src/ui/menu.lua` - Added CONTROLS state and menu entries
   - `src/game.lua` - Integrated Controls system, replaced hardcoded keys with action checks
   - `src/ui/options.lua` - Fixed back button index

---

## Design Principles

1. **Modularity**: Each component has a single responsibility
2. **Reusability**: UI components can be used across different menus
3. **Consistency**: Follows existing Options/Stats module pattern
4. **Extensibility**: Easy to add new actions or UI components
5. **User-Friendly**: Clear visual feedback and readable key names
6. **Data-Driven**: Actions and defaults defined in tables, not code

---

## Future Enhancements

- **Multiple Control Profiles**: Save/load different control schemes
- **Conflict Detection**: Warn when binding a key already in use
- **Advanced Actions**: Support for key combinations (e.g., Ctrl+Z)
- **Touchscreen Support**: Touch control customization for mobile
- **Per-Mode Controls**: Different bindings for different game modes
- **Import/Export**: Share control schemes with other players

---

## Testing Checklist

- [ ] Can rebind all actions for keyboard
- [ ] Can rebind all actions for gamepad
- [ ] Settings persist after restart
- [ ] Reset keyboard works correctly
- [ ] Reset gamepad works correctly
- [ ] Reset all works correctly
- [ ] Pause action works from both devices
- [ ] No key conflicts cause issues
- [ ] Menu navigation works with custom controls
- [ ] Help text updates correctly
- [ ] Dialogs work properly

---

## Credits

Built following the existing architecture pattern established in `Options.lua` and `Stats.lua`.
Designed for maximum modularity and reusability across the Sirtet codebase.
