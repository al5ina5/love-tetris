-- src/game/network_handler.lua
-- Handles all network message processing and synchronization

local Protocol = require('src.net.protocol')
local Audio = require('src.audio')

local NetworkHandler = {}

function NetworkHandler.handleMessage(msg, game)
    print("NetworkHandler: Received message type: " .. tostring(msg.type) .. " from " .. tostring(msg.id))
    if msg.type == "player_joined" then
        NetworkHandler.handlePlayerJoined(msg, game)
    elseif msg.type == Protocol.MSG.START_COUNTDOWN then
        NetworkHandler.handleStartCountdown(msg, game)
    elseif msg.type == Protocol.MSG.SCORE_SYNC then
        NetworkHandler.handleScoreSync(msg, game)
    elseif msg.type == Protocol.MSG.BOARD_SYNC then
        NetworkHandler.handleBoardSync(msg, game)
    elseif msg.type == Protocol.MSG.PIECE_MOVE then
        NetworkHandler.handlePieceMove(msg, game)
    elseif msg.type == Protocol.MSG.GAME_OVER then
        NetworkHandler.handleGameOver(msg, game)
    elseif msg.type == Protocol.MSG.GARBAGE then
        NetworkHandler.handleGarbage(msg, game)
    elseif msg.type == Protocol.MSG.PING then
        -- Reply with PONG and the same timestamp
        if game.network then
            game.network:sendMessage({
                type = Protocol.MSG.PONG,
                data = tostring(msg.timestamp)
            })
        end
    elseif msg.type == Protocol.MSG.PONG then
        -- Calculate RTT
        if msg.timestamp and msg.timestamp > 0 then
            local rtt = love.timer.getTime() - msg.timestamp
            -- Rolling average for smoothness
            game.latency = (game.latency * 0.8) + (rtt * 0.2)
            print(string.format("Network: Measured RTT: %.1fms (compensated: %.1fms)", rtt * 1000, (game.latency / 2) * 1000))
        end
    elseif msg.type == "player_left" then
        NetworkHandler.handlePlayerLeft(msg, game)
    else
        print("NetworkHandler: Unknown message type: " .. tostring(msg.type))
    end
end

function NetworkHandler.handlePlayerJoined(msg, game)
    print("Network: Player joined: " .. msg.id)
    local TetrisBoard = require('src.tetris.board')
    game.remoteBoards[msg.id] = TetrisBoard:new(10, 20)
    game.remoteBoards[msg.id].currentPiece = nil
    print("Network: Added remote board for " .. msg.id .. " (now " .. game:countRemotePlayers() .. " remote players)")

    -- If we are the host, tell the new player that we are here too
    if game.isHost and game.network and msg.id ~= "host" then
        game.network:sendMessage({type = Protocol.MSG.PLAYER_JOIN})
    end

    -- If we are the client and just discovered the host, hide the "Connecting..." menu
    -- so we can see the split-screen layout with "WAITING FOR HOST..."
    if not game.isHost and game.menu:isVisible() then
        game.menu:hide()
    end
end

function NetworkHandler.handleStartCountdown(msg, game)
    if game.state == "waiting" or game.state == "over" then
        if game.state == "over" then
            local StateManager = require('src.game.state_manager')
            StateManager.reset(game.stateManager, game)
        end
        game.stateManager.current = "countdown"
        
        -- Apply latency compensation: subtract one-way trip time (RTT / 2)
        local compensation = game.latency / 2
        game.stateManager.countdownTimer = 3.0 - compensation
        
        print(string.format("Network: Starting countdown with %.1fms compensation", compensation * 1000))
        Audio:play('beep')

        -- Hide menu if it's still visible (important for online clients)
        if game.menu:isVisible() then
            game.menu:hide()
        end
    end
end

function NetworkHandler.handleScoreSync(msg, game)
    local board = game.remoteBoards[msg.id]
    if board then
        board.score = tonumber(msg.score) or 0
    end
end

function NetworkHandler.handleBoardSync(msg, game)
    local TetrisBoard = require('src.tetris.board')
    local board = game.remoteBoards[msg.id]
    if not board then
        board = TetrisBoard:new(10, 20)
        game.remoteBoards[msg.id] = board
    end
    board:deserializeGrid(msg.gridData)
end

function NetworkHandler.handlePieceMove(msg, game)
    local TetrisBoard = require('src.tetris.board')
    local board = game.remoteBoards[msg.id]
    if not board then
        board = TetrisBoard:new(10, 20)
        game.remoteBoards[msg.id] = board
    end
    
    -- Update remote piece for display
    if not board.currentPiece or board.currentPiece.type ~= msg.pieceType then
        local data = TetrisBoard.PIECES[msg.pieceType]
        if data then
            board.currentPiece = {
                type = msg.pieceType,
                shape = board:copyTable(data),
                color = data.color
            }
            board.rotationIndex = 0
        end
    end
    board.pieceX = msg.x
    board.pieceY = msg.y
    
    -- Apply rotation if different
    if board.rotationIndex ~= msg.rotation then
        local data = TetrisBoard.PIECES[msg.pieceType]
        if data then
            board.currentPiece.shape = board:copyTable(data)
            board.rotationIndex = 0
            for i = 1, msg.rotation do
                local oldShape = board.currentPiece.shape
                local n = #oldShape
                local newShape = {}
                for j = 1, n do newShape[j] = {} end
                for y = 1, n do
                    for x = 1, n do
                        newShape[x][n - y + 1] = oldShape[y][x]
                    end
                end
                board.currentPiece.shape = newShape
                board.rotationIndex = (board.rotationIndex + 1) % 4
            end
        end
    end
end

function NetworkHandler.handleGameOver(msg, game)
    local board = game.remoteBoards[msg.id]
    if board then
        board.gameOver = true
    end
end

function NetworkHandler.handleGarbage(msg, game)
    print("Network: Received " .. msg.lines .. " garbage lines from " .. msg.id)
    if game.localBoard then
        game.localBoard:receiveGarbage(msg.lines)
    end
end

function NetworkHandler.handlePlayerLeft(msg, game)
    print("Network: Player left: " .. msg.id)
    game.remoteBoards[msg.id] = nil
    
    if game:countRemotePlayers() == 0 then
        if game.state == "playing" then
            print("Network: Last opponent left during game, pausing")
            local StateManager = require('src.game.state_manager')
            StateManager.enterDisconnectedPause(game.stateManager, game)
        else
            game.stateManager.current = "waiting"
        end
    end
end

function NetworkHandler.syncLocalState(game)
    if not game.network then return end
    
    local px, py = game.localBoard.pieceX, game.localBoard.pieceY
    local type = game.localBoard.currentPiece and game.localBoard.currentPiece.type or "I"
    local rot = game.localBoard.rotationIndex or 0
    
    -- Send piece move (unreliable)
    if game.lastSentMove.x ~= px or game.lastSentMove.y ~= py or game.lastSentMove.type ~= type or game.lastSentMove.rot ~= rot then
        game.network:sendPieceMove(type, px, py, rot)
        game.lastSentMove = {x=px, y=py, type=type, rot=rot}
    end
    
    -- Send board sync if changed (reliable)
    if game.localBoard.gridChanged then
        game.network:sendBoardSync(game.localBoard:serializeGrid())
        game.localBoard.gridChanged = false
    end
    
    -- Send game over
    if game.localBoard.gameOver and not game.sentGameOver then
        game.network:sendMessage({type = Protocol.MSG.GAME_OVER})
        game.sentGameOver = true
    end
end

function NetworkHandler.syncScore(game)
    if not game.network then return end
    
    if game.localBoard.score ~= game.lastSentScore then
        game.network:sendMessage({type = Protocol.MSG.SCORE_SYNC, data = game.localBoard.score})
        game.lastSentScore = game.localBoard.score
    end
end

function NetworkHandler.sendGarbage(game, lines)
    if game.network then
        game.network:sendMessage({
            type = Protocol.MSG.GARBAGE,
            lines = lines
        })
    end
end

return NetworkHandler
