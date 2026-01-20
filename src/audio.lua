local Audio = {
    sounds = {}
}

local function generateSquareWave(freq, duration, volume, decay)
    local rate = 44100
    local length = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(length, rate, 16, 1)
    
    local phase = 0
    for i = 0, length - 1 do
        local v = volume or 0.1
        if decay then
            v = v * (1 - i / length)
        end
        
        phase = phase + (freq * 2 * math.pi / rate)
        -- Square wave
        local sample = math.sin(phase) > 0 and v or -v
        soundData:setSample(i, sample)
    end
    
    return love.audio.newSource(soundData, "static")
end

local function generateDing(freqs, duration, volume)
    local rate = 44100
    local length = math.floor(rate * duration)
    local soundData = love.sound.newSoundData(length, rate, 16, 1)
    
    local phase = 0
    local numFreqs = #freqs
    for i = 0, length - 1 do
        local v = (volume or 0.1) * (1 - i / length)
        
        -- Determine which frequency to use based on time
        local freqIdx = math.floor((i / length) * numFreqs) + 1
        freqIdx = math.min(freqIdx, numFreqs)
        local freq = freqs[freqIdx]
        
        phase = phase + (freq * 2 * math.pi / rate)
        local sample = math.sin(phase) > 0 and v or -v
        soundData:setSample(i, sample)
    end
    
    return love.audio.newSource(soundData, "static")
end

function Audio:init()
    -- Move sound: Short high-pitched blip
    self.sounds.move = generateSquareWave(880, 0.05, 0.03, true)
    
    -- Rotate sound: Slightly different pitch
    self.sounds.rotate = generateSquareWave(660, 0.07, 0.03, true)
    
    -- Lock sound: Lower "thud"
    self.sounds.lock = generateSquareWave(220, 0.1, 0.05, true)
    
    -- Clear line: "Ding" (rising notes)
    -- Zelda-like puzzle solve: G5, B5, D6, G6
    -- Frequencies: 783.99, 987.77, 1174.66, 1567.98
    self.sounds.clear = generateDing({784, 987, 1174, 1568}, 0.4, 0.05)
    
    -- Game over: Descending
    self.sounds.gameOver = generateDing({440, 330, 220, 110}, 0.8, 0.06)
    
    -- Countdown beep
    self.sounds.beep = generateSquareWave(440, 0.1, 0.04, true)
    -- GO beep (higher)
    self.sounds.go = generateSquareWave(880, 0.2, 0.05, true)
end

function Audio:play(name)
    if self.sounds[name] then
        -- We clone for move sounds so they can overlap if pressed fast
        if name == 'move' or name == 'rotate' then
            local s = self.sounds[name]:clone()
            s:play()
        else
            self.sounds[name]:stop()
            self.sounds[name]:play()
        end
    end
end

return Audio
