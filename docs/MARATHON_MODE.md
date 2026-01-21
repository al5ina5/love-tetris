# Marathon Mode Implementation

## Overview

Marathon mode is a classic endless Tetris mode where players survive as long as possible while the difficulty gradually increases. The game continues until the board fills up (game over).

## Game Mechanics

### Core Features

1. **Endless Gameplay**
   - Play indefinitely until death (board fills up)
   - No line goal - pure survival challenge
   - Progressive difficulty increase

2. **Level Progression**
   - Start at Level 1
   - Level up every 10 lines cleared
   - Drop speed increases with each level: `speed = max(0.05, 1.0 * (0.8 ^ (level - 1)))`
   - Scoring multiplier increases with level

3. **Scoring System**
   - Standard Tetris scoring (inherited from existing system)
   - Line clear bonuses:
     - Single: 100 × level
     - Double: 300 × level
     - Triple: 500 × level
     - Tetris (4 lines): 800 × level
   - T-spin bonuses:
     - T-spin Single: 800 × level (2 garbage)
     - T-spin Double: 1200 × level (4 garbage)
     - T-spin Triple: 1600 × level (6 garbage)
   - Combo bonuses: 50 × combo × level
   - Soft drop: 1 point per cell
   - Hard drop: 2 points per cell

4. **Statistics Tracked**
   - Final Score
   - Final Level Reached
   - Total Lines Cleared
   - Total Time Played
   - Max Combo Achieved
   - Total T-spins Performed
   - Total Pieces Placed

### HUD Display

Marathon mode displays real-time statistics during gameplay:

- **Time**: Running timer (MM:SS.CS format)
- **Level**: Current level with visual prominence
- **Progress Bar**: Visual indicator of lines until next level (0-10)
- **Lines**: Total lines cleared
- **Max Combo**: Highest combo achieved in current run
- **T-spins**: Total T-spins performed (if any)
- **Score**: Standard score display at bottom

### Game Over Screen

When a Marathon run ends, the following summary is displayed:

- "MARATHON COMPLETE" title
- Final Score
- Final Level Reached
- Total Lines Cleared
- Total Time
- Max Combo
- T-spins (if performed)

## Implementation Details

### Architecture

The implementation follows the modular architecture established in the refactoring:

```
src/
├── game/
│   ├── modes.lua              # Game mode configurations
│   ├── marathon_state.lua     # Marathon state tracking
│   ├── marathon_renderer.lua  # Marathon HUD rendering
│   ├── state_manager.lua      # Extended for Marathon
│   └── renderer.lua            # Integrated Marathon HUD
├── ui/menu/
│   ├── main_menu.lua           # Added Marathon option
│   └── stats_screen.lua        # Marathon statistics display
├── tetris/
│   └── scoring.lua             # Enhanced T-spin tracking
└── data/
    └── scores.lua              # Marathon statistics persistence
```

### Key Modules

#### 1. **modes.lua** (New)
Centralized game mode configuration system. Defines properties for all game modes:
- Mode identification
- Single/multiplayer flag
- Time tracking requirements
- End conditions
- Statistics to track

Benefits:
- Easy to add new game modes
- Consistent mode handling
- Self-documenting mode properties

#### 2. **marathon_state.lua** (New)
Manages Marathon-specific state and statistics:
- Time tracking
- Max combo tracking
- T-spin type counting (single/double/triple)
- Piece placement counting
- Summary generation for game over

#### 3. **marathon_renderer.lua** (New)
Handles Marathon HUD rendering:
- Time display with proper formatting
- Level display with visual emphasis
- Progress bar to next level
- Statistics display (lines, combo, T-spins)
- Game over summary screen

#### 4. **State Manager** (Modified)
Extended to support Marathon mode:
- Marathon state initialization on countdown
- Marathon state updates during gameplay
- Marathon-specific game over handling
- Statistics recording

#### 5. **Scoring System** (Enhanced)
Added T-spin type tracking:
- Sets `lastTSpinType` field on board
- Tracks "single", "double", "triple" T-spins
- Used by Marathon state for detailed statistics

#### 6. **Scores System** (Enhanced)
Extended to handle Marathon statistics:
- Flexible extra data storage (key=value format)
- Marathon-specific high scores:
  - High Score
  - Highest Level
  - Most Lines Cleared
- Backward compatible with existing save format

#### 7. **Stats Screen** (Enhanced)
Displays Marathon statistics:
- Marathon high level and high score in summary
- Marathon match history with level and score
- Proper formatting for Marathon entries

### Data Persistence

Marathon statistics are saved in `history.txt` with the format:

```
MODE|SCORE|TIME|RESULT|TIMESTAMP|EXTRA_DATA
```

Extra data for Marathon includes:
```
level=15,lines=142,maxCombo=8,tspins=5
```

This format is:
- Backward compatible with existing saves
- Flexible for future mode additions
- Human-readable for debugging

## Usage

### Accessing Marathon Mode

1. Launch game
2. Select "SINGLE PLAYER" from main menu
3. Select "MARATHON"
4. Game begins after 3-2-1 countdown

### Controls

Marathon uses standard Tetris controls (defined in Controls system):
- Move: Left/Right arrows or D-pad
- Rotate: Z/X or A/B buttons
- Hard Drop: Space or gamepad button
- Soft Drop: Down arrow or D-pad down
- Hold: C or gamepad button
- Pause: Escape or Start button

### Viewing Statistics

1. Select "STATS" from main menu
2. View Marathon high scores in summary section
3. Scroll through match history to see past Marathon runs
4. Marathon entries show: "MARATHON DEATH | LVL X | SCORE"

## Design Principles

### Modularity
- Each component has a single, clear responsibility
- Marathon logic is self-contained in dedicated modules
- Minimal changes to existing code

### Extensibility
- Easy to add new game modes following the same pattern
- Mode configuration system allows quick mode additions
- Statistics system is flexible for future enhancements

### Maintainability
- Small, focused files (avg ~100 lines)
- Clear separation of concerns
- Well-documented interfaces

### Consistency
- Follows established code patterns
- Matches existing Sprint/Versus architecture
- Uses existing rendering and audio systems

## Future Enhancements

Potential additions to Marathon mode:

1. **Starting Level Selection**
   - Let players choose starting level (1-15)
   - Affects initial difficulty and scoring

2. **Marathon B-Type**
   - Start with pre-filled garbage rows
   - Configurable handicap height
   - Goal: Clear X lines from starting position

3. **Milestone Celebrations**
   - Visual/audio feedback at level milestones (5, 10, 15, 20)
   - Achievement system for special accomplishments
   - Particle effects on level up

4. **Leaderboard Filters**
   - Separate leaderboards for different starting levels
   - Daily/weekly/all-time high scores
   - Compare statistics with friends

5. **Marathon Challenges**
   - Time attack variants (reach level 15 in X minutes)
   - No-hold mode (hardcore variant)
   - Speed Marathon (faster initial speed)

## Technical Notes

### Performance
- No performance impact compared to other modes
- Efficient state tracking (updates only on changes)
- Minimal rendering overhead

### Compatibility
- Works with all existing shaders and visual effects
- Compatible with all control schemes
- Integrates with pause system

### Testing Checklist

- ✅ Marathon appears in single-player menu
- ✅ Countdown starts Marathon state tracking
- ✅ Level progression works (every 10 lines)
- ✅ Drop speed increases properly
- ✅ Time tracking is accurate
- ✅ Combo tracking works
- ✅ T-spin tracking works
- ✅ Game over triggers correctly
- ✅ Statistics are saved properly
- ✅ Stats screen displays Marathon records
- ✅ Match history shows Marathon details
- ✅ HUD displays all statistics correctly
- ✅ Game over screen shows summary
- ✅ No linter errors

## Credits

Implementation follows the modular architecture established in the [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md) document.

Marathon mechanics are based on classic Tetris guidelines with modern enhancements.
