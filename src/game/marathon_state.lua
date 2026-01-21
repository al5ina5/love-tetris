-- src/game/marathon_state.lua
-- Tracks Marathon-specific state and statistics

local MarathonState = {}

function MarathonState.create(startLevel)
    return {
        startLevel = startLevel or 1,
        maxCombo = 0,
        tspinsSingle = 0,
        tspinsDouble = 0,
        tspinsTriple = 0,
        playTime = 0,
        piecesPlaced = 0
    }
end

function MarathonState.update(state, dt, board)
    state.playTime = state.playTime + dt
    
    -- Track max combo
    if board.combo > state.maxCombo then
        state.maxCombo = board.combo
    end
    
    -- Track T-spins (if board has the tracking data)
    if board.lastTSpinType then
        if board.lastTSpinType == "single" then
            state.tspinsSingle = state.tspinsSingle + 1
        elseif board.lastTSpinType == "double" then
            state.tspinsDouble = state.tspinsDouble + 1
        elseif board.lastTSpinType == "triple" then
            state.tspinsTriple = state.tspinsTriple + 1
        end
        board.lastTSpinType = nil
    end
end

function MarathonState.onPiecePlaced(state)
    state.piecesPlaced = state.piecesPlaced + 1
end

function MarathonState.getSummary(state, board)
    return {
        score = board.score,
        level = board.level,
        lines = board.linesCleared,
        time = state.playTime,
        maxCombo = state.maxCombo,
        tspins = state.tspinsSingle + state.tspinsDouble + state.tspinsTriple,
        piecesPlaced = state.piecesPlaced
    }
end

function MarathonState.getTotalTSpins(state)
    return state.tspinsSingle + state.tspinsDouble + state.tspinsTriple
end

return MarathonState
