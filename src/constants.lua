-- src/constants.lua
-- Common constants and data for the game

local Constants = {}

Constants.SW = 320
Constants.SH = 240

Constants.GRID_WIDTH = 10
Constants.GRID_HEIGHT = 20
Constants.BLOCK_SIZE_W = 16
Constants.BLOCK_SIZE_H = 11

Constants.PIECES = {
    I = {
        {0,0,0,0},
        {1,1,1,1},
        {0,0,0,0},
        {0,0,0,0},
        color = {0, 1, 1}, -- Cyan
        id = 1
    },
    J = {
        {1,0,0},
        {1,1,1},
        {0,0,0},
        color = {0, 0, 1}, -- Blue
        id = 2
    },
    L = {
        {0,0,1},
        {1,1,1},
        {0,0,0},
        color = {1, 0.5, 0}, -- Orange
        id = 3
    },
    O = {
        {1,1},
        {1,1},
        color = {1, 1, 0}, -- Yellow
        id = 4
    },
    S = {
        {0,1,1},
        {1,1,0},
        {0,0,0},
        color = {0, 1, 0}, -- Green
        id = 5
    },
    T = {
        {0,1,0},
        {1,1,1},
        {0,0,0},
        color = {0.5, 0, 1}, -- Purple
        id = 6
    },
    Z = {
        {1,1,0},
        {0,1,1},
        {0,0,0},
        color = {1, 0, 0}, -- Red
        id = 7
    },
    GARBAGE = {
        color = {0.5, 0.5, 0.5}, -- Gray
        id = 8
    }
}

-- SRS Wall Kick Data
Constants.WALL_KICKS = {
    ["01"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    ["10"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    ["12"] = {{0,0}, {1,0}, {1,1}, {0,-2}, {1,-2}},
    ["21"] = {{0,0}, {-1,0}, {-1,-1}, {0,2}, {-1,2}},
    ["23"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}},
    ["32"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    ["30"] = {{0,0}, {-1,0}, {-1,1}, {0,-2}, {-1,-2}},
    ["03"] = {{0,0}, {1,0}, {1,-1}, {0,2}, {1,2}}
}

Constants.WALL_KICKS_I = {
    ["01"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    ["10"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    ["12"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}},
    ["21"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    ["23"] = {{0,0}, {2,0}, {-1,0}, {2,-1}, {-1,2}},
    ["32"] = {{0,0}, {-2,0}, {1,0}, {-2,1}, {1,-2}},
    ["30"] = {{0,0}, {1,0}, {-2,0}, {1,2}, {-2,-1}},
    ["03"] = {{0,0}, {-1,0}, {2,0}, {-1,-2}, {2,1}}
}

-- Online multiplayer API endpoint
Constants.API_BASE_URL = "https://sirtet-multiplayer.onrender.com"
Constants.RELAY_HOST = "sirtet-multiplayer.onrender.com" 
Constants.RELAY_PORT = 12346

return Constants
