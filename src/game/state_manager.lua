-- src/game/state_manager.lua
-- Manages game state machine and transitions

local Audio = require('src.audio')
local Scores = require('src.data.scores')

local StateManager = {}

StateManager.STATES = {
    WAITING = "waiting",
    COUNTDOWN = "countdown",
    PLAYING = "playing",
    GAME_OVER = "over",
    DISCONNECTED_PAUSE = "disconnected_pause"
}

function StateManager.create()
    return {
        current = StateManager.STATES.WAITING,
        countdownTimer = 0,
        gameOverTimer = 0,
        disconnectPauseTimer = 0,
        disconnectReason = nil  -- "opponent_left", "connection_closed", etc.
    }
end

function StateManager.update(state, dt, game)
    if state.current == StateManager.STATES.WAITING then
        StateManager.updateWaiting(state, game)
    elseif state.current == StateManager.STATES.COUNTDOWN then
        StateManager.updateCountdown(state, dt, game)
    elseif state.current == StateManager.STATES.PLAYING then
        StateManager.updatePlaying(state, dt, game)
    elseif state.current == StateManager.STATES.GAME_OVER then
        StateManager.updateGameOver(state, dt, game)
    elseif state.current == StateManager.STATES.DISCONNECTED_PAUSE then
        StateManager.updateDisconnectedPause(state, dt, game)
    end
end

function StateManager.updateWaiting(state, game)
    -- If we have an opponent, start countdown and hide menu
    local remoteCount = game:countRemotePlayers()
    if game.isHost and remoteCount > 0 then
        print("StateManager: Host has " .. remoteCount .. " players, starting countdown")
        game.menu:hide()
        StateManager.startCountdown(state, game)
    end
end

function StateManager.updateCountdown(state, dt, game)
    local oldTime = math.ceil(state.countdownTimer)
    state.countdownTimer = state.countdownTimer - dt
    local newTime = math.ceil(state.countdownTimer)
    
    if oldTime ~= newTime then
        if newTime > 0 then
            Audio:play('beep')
        elseif newTime == 0 then
            Audio:play('go')
        end
    end
    
    if state.countdownTimer <= 0 then
        state.current = StateManager.STATES.PLAYING
        game.sprintTime = 0
        Audio:playRandomGameMusic()
    end
end

function StateManager.updatePlaying(state, dt, game)
    -- Marathon tracking
    if game.gameMode == "MARATHON" and game.marathonState then
        local MarathonState = require('src.game.marathon_state')
        MarathonState.update(game.marathonState, dt, game.localBoard)
        
        -- Track piece placements
        if game.localBoard.pieceLocked then
            MarathonState.onPiecePlaced(game.marathonState)
            game.localBoard.pieceLocked = false
        end
        
        -- Marathon ends only on death
        if game.localBoard.gameOver then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('secret')
            
            local summary = MarathonState.getSummary(game.marathonState, game.localBoard)
            Scores.addMatch("MARATHON", summary.score, summary.time, "DEATH", {
                level = summary.level,
                lines = summary.lines,
                maxCombo = summary.maxCombo,
                tspins = summary.tspins
            })
            return
        end
    end
    
    -- Sprint mode
    if game.gameMode == "SPRINT" then
        game.sprintTime = game.sprintTime + dt
        
        -- Check for death first
        if game.localBoard.gameOver then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('gameOver')
            Scores.addMatch("SPRINT", game.localBoard.score, game.sprintTime, "DEATH")
            return
        end
        
        -- Win condition: cleared 40 lines
        if game.localBoard.linesCleared >= 40 then
            StateManager.enterGameOver(state, game)
            Audio:stopMusic()
            Audio:play('secret')
            Scores.addMatch("SPRINT", game.localBoard.score, game.sprintTime, "FINISHED")
            return
        end
    end

    -- Check if anyone lost (Versus mode)
    local anyGameOver = game.localBoard.gameOver
    for id, board in pairs(game.remoteBoards) do
        if board.gameOver then
            anyGameOver = true
            break
        end
    end

    if anyGameOver and game.gameMode == "VERSUS" then
        StateManager.enterGameOver(state, game)
        Audio:stopMusic()
        
        local result = game.localBoard.gameOver and "LOSS" or "WIN"
        Scores.addMatch("VERSUS", game.localBoard.score, 0, result)
    end
end

function StateManager.updateGameOver(state, dt, game)
    -- Game over screen now waits for input to dismiss (no auto-timer)
    -- The gameOverTimer is used as a brief delay before allowing dismissal
    if state.gameOverTimer > 0 then
        state.gameOverTimer = state.gameOverTimer - dt
    end
end

function StateManager.canDismissGameOver(state)
    return state.current == StateManager.STATES.GAME_OVER and state.gameOverTimer <= 0
end

function StateManager.dismissGameOver(state, game)
    if StateManager.canDismissGameOver(state) then
        StateManager.reset(state, game)
        return true
    end
    return false
end

function StateManager.updateDisconnectedPause(state, dt, game)
    state.disconnectPauseTimer = state.disconnectPauseTimer - dt
    if state.disconnectPauseTimer <= 0 then
        StateManager.resumeAsSinglePlayer(state, game)
    end
end

function StateManager.startCountdown(state, game)
    state.current = StateManager.STATES.COUNTDOWN
    state.countdownTimer = 3.0
    Audio:play('beep')
    
    -- Always create a fresh board for the new game
    local TetrisBoard = require('src.tetris.board')
    game.localBoard = TetrisBoard:new(10, 20)
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = {x=0, y=0, rot=0, type=""}
    game.sprintTime = 0
    
    -- Initialize mode-specific state
    if game.gameMode == "MARATHON" then
        local MarathonState = require('src.game.marathon_state')
        game.marathonState = MarathonState.create(1)
    end
    
    if game.network then
        local Protocol = require('src.net.protocol')
        game.network:sendMessage({type = Protocol.MSG.START_COUNTDOWN})
    end
end

function StateManager.enterGameOver(state, game)
    state.current = StateManager.STATES.GAME_OVER
    state.gameOverTimer = 1.0  -- Brief delay before allowing dismissal
end

function StateManager.enterDisconnectedPause(state, game, reason)
    print("StateManager: Entering disconnected pause (reason: " .. tostring(reason) .. ")")
    state.current = StateManager.STATES.DISCONNECTED_PAUSE
    state.disconnectPauseTimer = 5.0  -- Give players 5 seconds to read the message
    state.disconnectReason = reason or "opponent_left"
    Audio:pauseMusic()
end

function StateManager.resumeAsSinglePlayer(state, game)
    print("StateManager: Resuming as single player")
    state.current = StateManager.STATES.PLAYING
    state.disconnectReason = nil
    
    -- Clean up network connections
    if game.network then
        game.network:disconnect()
        game.network = nil
    end
    
    -- Clean up online client
    if game.connectionManager and game.connectionManager.onlineClient then
        if game.connectionManager.onlineClient.disconnect then
            game.connectionManager.onlineClient:disconnect()
        end
        game.connectionManager.onlineClient = nil
    end
    
    -- Clear remote boards and switch to single player mode
    game.remoteBoards = {}
    game.isHost = true  -- Mark as host so game over/reset works correctly
    
    Audio:resumeMusic()
end

function StateManager.reset(state, game)
    local TetrisBoard = require('src.tetris.board')
    game.localBoard = TetrisBoard:new(10, 20)
    
    for id, board in pairs(game.remoteBoards) do
        game.remoteBoards[id] = TetrisBoard:new(10, 20)
        game.remoteBoards[id].currentPiece = nil
    end
    
    game.sentGameOver = false
    game.lastSentScore = 0
    game.lastSentMove = {x=0, y=0, rot=0, type=""}
    
    if game.isHost then
        StateManager.startCountdown(state, game)
    else
        state.current = StateManager.STATES.WAITING
        Audio:playMusic('menu')
    end
end

return StateManager
