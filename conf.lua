function love.conf(t)
    t.window.title = "Sirtet"
    t.window.width = 640   -- 320 * 2 for better visibility
    t.window.height = 480  -- 240 * 2
    t.window.vsync = 1
    t.window.resizable = true
    t.window.minwidth = 320
    t.window.minheight = 240
    
    -- Game identity (for save files)
    t.identity = "sirtet"
    
    -- CRT Effect
    t.crt = true
    _G.CRT_ENABLED = t.crt
end
