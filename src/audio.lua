local Audio = {
    sounds = {},
    music = {},
    currentMusic = nil,
    sfxVolume = 0.5,
    musicVolume = 0.5,
    baseVolumes = {}
}

local NOTES = {
    ['C3'] = 130.81, ['C#3'] = 138.59, ['D3'] = 146.83, ['D#3'] = 155.56, ['E3'] = 164.81, ['F3'] = 174.61, ['F#3'] = 185.00, ['G3'] = 196.00, ['G#3'] = 207.65, ['A3'] = 220.00, ['A#3'] = 233.08, ['B3'] = 246.94,
    ['C4'] = 261.63, ['C#4'] = 277.18, ['D4'] = 293.66, ['D#4'] = 311.13, ['E4'] = 329.63, ['F4'] = 349.23, ['F#4'] = 369.99, ['G4'] = 392.00, ['G#4'] = 415.30, ['A4'] = 440.00, ['A#4'] = 466.16, ['B4'] = 493.88,
    ['C5'] = 523.25, ['C#5'] = 554.37, ['D5'] = 587.33, ['D#5'] = 622.25, ['E5'] = 659.25, ['F5'] = 698.46, ['F#5'] = 739.99, ['G5'] = 783.99, ['G#5'] = 830.61, ['A5'] = 880.00, ['A#5'] = 932.33, ['B5'] = 987.77,
    ['C6'] = 1046.50, ['D6'] = 1174.66, ['E6'] = 1318.51, ['G6'] = 1567.98, ['R'] = 0 -- Rest
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

function Audio:init()
    -- Move sound: Short high-pitched blip
    self.baseVolumes.move = 0.03
    self.sounds.move = generateSquareWave(880, 0.05, 1.0, true)
    
    -- Rotate sound: Slightly different pitch
    self.baseVolumes.rotate = 0.03
    self.sounds.rotate = generateSquareWave(660, 0.07, 1.0, true)
    
    -- Lock sound: Lower "thud"
    self.baseVolumes.lock = 0.05
    self.sounds.lock = generateSquareWave(220, 0.1, 1.0, true)
    
    -- Clear line: "Ding" (rising notes)
    self.baseVolumes.clear = 0.05
    self.sounds.clear = generateDing({784, 987, 1174, 1568}, 0.4, 1.0)
    
    -- Game over: Descending
    self.baseVolumes.gameOver = 0.06
    self.sounds.gameOver = generateDing({440, 330, 220, 110}, 0.8, 1.0)
    
    -- Countdown beep
    self.baseVolumes.beep = 0.04
    self.sounds.beep = generateSquareWave(440, 0.1, 1.0, true)
    -- GO beep (higher)
    self.baseVolumes.go = 0.05
    self.sounds.go = generateSquareWave(880, 0.2, 1.0, true)

    -- Secret Found (Original "Mystery" jingle)
    self.baseVolumes.secret = 0.04
    self.sounds.secret = generateMelody({
        {'D5', 1}, {'F5', 1}, {'G#5', 1}, {'A5', 2}, {'F5', 1}, {'D5', 4}
    }, 0.1, 1.0)

    -- Item Get (Original "Success" jingle)
    self.baseVolumes.item = 0.04
    self.sounds.item = generateMelody({
        {'A4', 1}, {'D5', 1}, {'F#5', 1}, {'A5', 4}
    }, 0.12, 1.0)

    -- Ethereal Calm (Menu - Relaxing)
    local lullaby = {
        {'G4', 8}, {'C5', 8}, {'D5', 4}, {'E5', 12},
        {'F5', 8}, {'E5', 8}, {'D5', 4}, {'C5', 12},
        {'G4', 8}, {'C5', 8}, {'D5', 4}, {'B4', 12},
        {'A4', 8}, {'G4', 24}
    }
    self.baseVolumes.menu = 0.02
    self.music.menu = generateMelody(lullaby, 0.18, 1.0)
    self.music.menu:setLooping(true)

    -- Sunlit Path (Game - Relaxing)
    local kakariko = {
        {'D4', 6}, {'E4', 2}, {'F#4', 8}, {'G4', 6}, {'A4', 2}, {'B4', 8},
        {'D5', 4}, {'C#5', 4}, {'B4', 4}, {'A4', 4}, {'G4', 8}, {'F#4', 8},
        {'E4', 4}, {'A4', 4}, {'D4', 16}
    }
    self.baseVolumes.kakariko = 0.02
    self.music.kakariko = generateMelody(kakariko, 0.18, 1.0)
    self.music.kakariko:setLooping(true)

    -- Stormy Night (Game - Melancholy/Slow)
    local storms = {
        {'A3', 8}, {'C4', 8}, {'E4', 8}, {'D4', 8},
        {'F4', 8}, {'E4', 8}, {'C4', 8}, {'B3', 8},
        {'A3', 8}, {'C4', 8}, {'E4', 8}, {'G4', 8},
        {'F4', 12}, {'E4', 4}, {'D4', 16}
    }
    self.baseVolumes.storms = 0.02
    self.music.storms = generateMelody(storms, 0.15, 1.0)
    self.music.storms:setLooping(true)

    -- Legend's End (Game - Somber)
    local theme = {
        {'D4', 12}, {'A3', 4}, {'D4', 8}, {'E4', 8}, {'F4', 12}, {'G4', 4}, {'A4', 16},
        {'G4', 8}, {'F4', 8}, {'E4', 8}, {'D4', 8}, {'C4', 12}, {'E4', 4}, {'D4', 16}
    }
    self.baseVolumes.zelda = 0.015
    self.music.zelda = generateMelody(theme, 0.2, 1.0)
    self.music.zelda:setLooping(true)

    -- Deep Forest (Game - Mysterious)
    local saria = {
        {'E4', 6}, {'F#4', 2}, {'G4', 8}, {'B4', 4}, {'A4', 4}, {'G4', 8},
        {'E4', 6}, {'F#4', 2}, {'G4', 8}, {'D5', 4}, {'C5', 4}, {'B4', 8},
        {'A4', 4}, {'G4', 4}, {'F#4', 4}, {'D4', 4}, {'E4', 16}
    }
    self.baseVolumes.saria = 0.015
    self.music.saria = generateMelody(saria, 0.15, 1.0)
    self.music.saria:setLooping(true)

    -- Crystal Waters (Game - Arpeggios)
    local fairy = {
        {'C4', 2}, {'E4', 2}, {'G4', 2}, {'B4', 2}, {'C5', 2}, {'B4', 2}, {'G4', 2}, {'E4', 2},
        {'A3', 2}, {'C4', 2}, {'E4', 2}, {'G4', 2}, {'A4', 2}, {'G4', 2}, {'E4', 2}, {'C4', 2},
        {'F3', 2}, {'A3', 2}, {'C4', 2}, {'E4', 2}, {'F4', 2}, {'E4', 2}, {'C4', 2}, {'A3', 2},
        {'G3', 2}, {'B3', 2}, {'D4', 2}, {'F4', 2}, {'G4', 2}, {'F4', 2}, {'D4', 2}, {'B3', 2}
    }
    self.baseVolumes.fairy = 0.012
    self.music.fairy = generateMelody(fairy, 0.12, 1.0)
    self.music.fairy:setLooping(true)

    -- Desert Wind (Game - Melancholy)
    local epona = {
        {'A4', 12}, {'G4', 4}, {'F4', 16},
        {'A4', 12}, {'G4', 4}, {'E4', 16},
        {'D4', 8}, {'E4', 8}, {'F4', 8}, {'G4', 8}, {'A4', 16}
    }
    self.baseVolumes.epona = 0.015
    self.music.epona = generateMelody(epona, 0.2, 1.0)
    self.music.epona:setLooping(true)

    self.gameTracks = {'zelda', 'kakariko', 'storms', 'saria', 'fairy', 'epona'}
end

function Audio:play(name)
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
    if self.music[name] then
        if self.currentMusic == self.music[name] then return end -- Already playing
        if self.currentMusic then
            self.currentMusic:stop()
        end
        self.currentMusic = self.music[name]
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
    if self.currentMusic then
        -- Find which music is currently playing to get its base volume
        local baseVol = 1
        for name, source in pairs(self.music) do
            if source == self.currentMusic then
                baseVol = self.baseVolumes[name] or 1
                break
            end
        end
        self.currentMusic:setVolume(self.musicVolume * baseVol)
    end
end

function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
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
