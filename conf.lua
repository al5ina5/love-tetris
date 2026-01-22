function love.conf(t)
    t.window.title = "Blockdrop"
    t.window.width = 1280   -- 640 * 2 for better visibility
    t.window.height = 960   -- 480 * 2
    t.window.vsync = 1
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 480
    
    -- Game identity (for save files)
    t.identity = "blockdrop"
    
    -- CRT Effect
    t.crt = true
    _G.CRT_ENABLED = t.crt
end
