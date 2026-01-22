local Audio = {
    sounds = {},
    music = {},
    currentMusic = nil,
    currentMusicName = nil,
    sfxVolume = 0.5,
    musicVolume = 0.5,
    baseVolumes = {},
    -- Lazy loading: track what's been generated
    _initialized = false,
    _soundsGenerated = {},
    _musicGenerated = {}
}

local NOTES = {
    ['C3'] = 130.81, ['C#3'] = 138.59, ['D3'] = 146.83, ['D#3'] = 155.56, ['E3'] = 164.81, ['F3'] = 174.61, ['F#3'] = 185.00, ['G3'] = 196.00, ['G#3'] = 207.65, ['A3'] = 220.00, ['A#3'] = 233.08, ['B3'] = 246.94,
    ['C4'] = 261.63, ['C#4'] = 277.18, ['D4'] = 293.66, ['D#4'] = 311.13, ['E4'] = 329.63, ['F4'] = 349.23, ['F#4'] = 369.99, ['G4'] = 392.00, ['G#4'] = 415.30, ['A4'] = 440.00, ['A#4'] = 466.16, ['B4'] = 493.88,
    ['C5'] = 523.25, ['C#5'] = 554.37, ['D5'] = 587.33, ['D#5'] = 622.25, ['E5'] = 659.25, ['F5'] = 698.46, ['F#5'] = 739.99, ['G5'] = 783.99, ['G#5'] = 830.61, ['A5'] = 880.00, ['A#5'] = 932.33, ['B5'] = 987.77,
    ['C6'] = 1046.50, ['D6'] = 1174.66, ['E6'] = 1318.51, ['G6'] = 1567.98, ['R'] = 0 -- Rest
}

-- Sound effect definitions (generated lazily)
local SOUND_DEFS = {
    move = { type = "square", freq = 880, duration = 0.05, volume = 1.0, decay = true, baseVol = 0.03 },
    rotate = { type = "square", freq = 660, duration = 0.07, volume = 1.0, decay = true, baseVol = 0.03 },
    lock = { type = "square", freq = 220, duration = 0.1, volume = 1.0, decay = true, baseVol = 0.05 },
    clear = { type = "ding", freqs = {784, 987, 1174, 1568}, duration = 0.4, volume = 1.0, baseVol = 0.05 },
    gameOver = { type = "ding", freqs = {440, 330, 220, 110}, duration = 0.8, volume = 1.0, baseVol = 0.06 },
    beep = { type = "square", freq = 440, duration = 0.1, volume = 1.0, decay = true, baseVol = 0.04 },
    go = { type = "square", freq = 880, duration = 0.2, volume = 1.0, decay = true, baseVol = 0.05 },
    secret = { type = "melody", melody = {{'D5', 1}, {'F5', 1}, {'G#5', 1}, {'A5', 2}, {'F5', 1}, {'D5', 4}}, stepDuration = 0.1, volume = 1.0, baseVol = 0.04 },
    item = { type = "melody", melody = {{'A4', 1}, {'D5', 1}, {'F#5', 1}, {'A5', 4}}, stepDuration = 0.12, volume = 1.0, baseVol = 0.04 }
}

-- Music definitions (generated lazily)
local MUSIC_DEFS = {
    menu = {
        melody = {
            {'G4', 8}, {'C5', 8}, {'D5', 4}, {'E5', 12},
            {'F5', 8}, {'E5', 8}, {'D5', 4}, {'C5', 12},
            {'G4', 8}, {'C5', 8}, {'D5', 4}, {'B4', 12},
            {'A4', 8}, {'G4', 24}
        },
        stepDuration = 0.18, volume = 1.0, baseVol = 0.02
    },
    kakariko = {
        melody = {
            {'D4', 6}, {'E4', 2}, {'F#4', 8}, {'G4', 6}, {'A4', 2}, {'B4', 8},
            {'D5', 4}, {'C#5', 4}, {'B4', 4}, {'A4', 4}, {'G4', 8}, {'F#4', 8},
            {'E4', 4}, {'A4', 4}, {'D4', 16}
        },
        stepDuration = 0.18, volume = 1.0, baseVol = 0.02
    },
    storms = {
        melody = {
            {'A3', 8}, {'C4', 8}, {'E4', 8}, {'D4', 8},
            {'F4', 8}, {'E4', 8}, {'C4', 8}, {'B3', 8},
            {'A3', 8}, {'C4', 8}, {'E4', 8}, {'G4', 8},
            {'F4', 12}, {'E4', 4}, {'D4', 16}
        },
        stepDuration = 0.15, volume = 1.0, baseVol = 0.02
    },
    zelda = {
        melody = {
            {'D4', 12}, {'A3', 4}, {'D4', 8}, {'E4', 8}, {'F4', 12}, {'G4', 4}, {'A4', 16},
            {'G4', 8}, {'F4', 8}, {'E4', 8}, {'D4', 8}, {'C4', 12}, {'E4', 4}, {'D4', 16}
        },
        stepDuration = 0.2, volume = 1.0, baseVol = 0.015
    },
    saria = {
        melody = {
            {'E4', 6}, {'F#4', 2}, {'G4', 8}, {'B4', 4}, {'A4', 4}, {'G4', 8},
            {'E4', 6}, {'F#4', 2}, {'G4', 8}, {'D5', 4}, {'C5', 4}, {'B4', 8},
            {'A4', 4}, {'G4', 4}, {'F#4', 4}, {'D4', 4}, {'E4', 16}
        },
        stepDuration = 0.15, volume = 1.0, baseVol = 0.015
    },
    fairy = {
        melody = {
            {'C4', 2}, {'E4', 2}, {'G4', 2}, {'B4', 2}, {'C5', 2}, {'B4', 2}, {'G4', 2}, {'E4', 2},
            {'A3', 2}, {'C4', 2}, {'E4', 2}, {'G4', 2}, {'A4', 2}, {'G4', 2}, {'E4', 2}, {'C4', 2},
            {'F3', 2}, {'A3', 2}, {'C4', 2}, {'E4', 2}, {'F4', 2}, {'E4', 2}, {'C4', 2}, {'A3', 2},
            {'G3', 2}, {'B3', 2}, {'D4', 2}, {'F4', 2}, {'G4', 2}, {'F4', 2}, {'D4', 2}, {'B3', 2}
        },
        stepDuration = 0.12, volume = 1.0, baseVol = 0.012
    },
    epona = {
        melody = {
            {'A4', 12}, {'G4', 4}, {'F4', 16},
            {'A4', 12}, {'G4', 4}, {'E4', 16},
            {'D4', 8}, {'E4', 8}, {'F4', 8}, {'G4', 8}, {'A4', 16}
        },
        stepDuration = 0.2, volume = 1.0, baseVol = 0.015
    }
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

local function generateMelody(melody, stepDuration, volume)
    local rate = 44100
    local totalSteps = 0
    for _, step in ipairs(melody) do
        totalSteps = totalSteps + step[2]
    end
    
    local totalLength = math.floor(rate * stepDuration * totalSteps)
    local soundData = love.sound.newSoundData(totalLength, rate, 16, 1)
    local currentPos = 0
    
    for _, step in ipairs(melody) do
        local noteName = step[1]
        local numSteps = step[2]
        local freq = NOTES[noteName] or 0
        local length = math.floor(rate * stepDuration * numSteps)
        
        local phase = 0
        for i = 0, length - 1 do
            local v = volume or 0.05
            -- Sharp attack, slight decay at the very end of each note
            if i > length - 200 then
                v = v * (length - i) / 200
            end
            
            if freq > 0 then
                phase = phase + (freq * 2 * math.pi / rate)
                -- Square wave
                local sample = math.sin(phase) > 0 and v or -v
                soundData:setSample(currentPos + i, sample)
            else
                soundData:setSample(currentPos + i, 0)
            end
        end
        currentPos = currentPos + length
    end
    
    local source = love.audio.newSource(soundData, "static")
    return source
end

-- Generate a sound effect on demand
local function ensureSound(self, name)
    if self._soundsGenerated[name] then return end
    
    local def = SOUND_DEFS[name]
    if not def then return end
    
    self.baseVolumes[name] = def.baseVol
    
    if def.type == "square" then
        self.sounds[name] = generateSquareWave(def.freq, def.duration, def.volume, def.decay)
    elseif def.type == "ding" then
        self.sounds[name] = generateDing(def.freqs, def.duration, def.volume)
    elseif def.type == "melody" then
        self.sounds[name] = generateMelody(def.melody, def.stepDuration, def.volume)
    end
    
    self._soundsGenerated[name] = true
end

-- Generate a music track on demand
local function ensureMusic(self, name)
    if self._musicGenerated[name] then return end
    
    local def = MUSIC_DEFS[name]
    if not def then return end
    
    self.baseVolumes[name] = def.baseVol
    self.music[name] = generateMelody(def.melody, def.stepDuration, def.volume)
    self.music[name]:setLooping(true)
    
    self._musicGenerated[name] = true
end

function Audio:init()
    -- Lazy loading: just set up the track list, don't generate anything yet
    self.gameTracks = {'zelda', 'kakariko', 'storms', 'saria', 'fairy', 'epona'}
    self._initialized = true
end

function Audio:play(name)
    -- Lazy load the sound if not yet generated
    ensureSound(self, name)
    
    if self.sounds[name] then
        local s = self.sounds[name]
        -- We clone for move sounds so they can overlap if pressed fast
        if name == 'move' or name == 'rotate' then
            s = self.sounds[name]:clone()
        else
            s:stop()
        end
        s:setVolume(self.sfxVolume * (self.baseVolumes[name] or 1))
        s:play()
    end
end

function Audio:playMusic(name)
    -- Lazy load the music if not yet generated
    ensureMusic(self, name)
    
    if self.music[name] then
        if self.currentMusicName == name then return end -- Already playing this track
        if self.currentMusic then
            self.currentMusic:stop()
        end
        self.currentMusic = self.music[name]
        self.currentMusicName = name
        self.currentMusic:setVolume(self.musicVolume * (self.baseVolumes[name] or 1))
        self.currentMusic:play()
    end
end

function Audio:playRandomGameMusic()
    local track = self.gameTracks[love.math.random(#self.gameTracks)]
    self:playMusic(track)
end

function Audio:setSFXVolume(v)
    self.sfxVolume = v
end

function Audio:setMusicVolume(v)
    self.musicVolume = v
    if self.currentMusic and self.currentMusicName then
        local baseVol = self.baseVolumes[self.currentMusicName] or 1
        self.currentMusic:setVolume(self.musicVolume * baseVol)
    end
end

function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
        self.currentMusicName = nil
    end
end

function Audio:pauseMusic()
    if self.currentMusic then
        self.currentMusic:pause()
    end
end

function Audio:resumeMusic()
    if self.currentMusic then
        self.currentMusic:play()
    end
end

return Audio
