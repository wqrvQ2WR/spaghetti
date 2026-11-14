-- 효과음은 파일 없이 전부 코드로 합성한다
local Audio = {}
Audio.data = {}   -- 합성한 원본 파형 (검증용으로도 쓴다)

local RATE = 44100

-- 음계 (장음계 위주로 올라간다)
local STEPS = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31, 33, 36 }

local function envelope(t, dur, decay)
    local attack = math.min(1, t / 0.004)
    local tail = math.min(1, (dur - t) / 0.01)
    return attack * math.max(0, tail) * math.exp(-t * decay)
end

local function synth(dur, decay, vol, wave)
    local n = math.floor(RATE * dur)
    local data = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local t = i / RATE
        data:setSample(i, wave(t) * envelope(t, dur, decay) * vol)
    end
    return data
end

local function sine(freq)
    return function(t) return math.sin(2 * math.pi * freq * t) end
end

local function source(name, data)
    Audio.data[name] = data
    return love.audio.newSource(data, "static")
end

function Audio.load()
    -- 압출: 사인 + 옥타브 위를 살짝 섞어 또렷하게
    Audio.place = source("place", synth(0.18, 11, 0.42, function(t)
        return math.sin(2 * math.pi * 440 * t) * 0.8
             + math.sin(2 * math.pi * 880 * t) * 0.2
    end))

    -- 잘려 나가는 소리
    Audio.cut = source("cut", synth(0.09, 30, 0.20, function()
        return love.math.random() * 2 - 1
    end))

    -- 무너지는 소리: 낮은 톱니 + 잡음
    Audio.crash = source("crash", synth(0.7, 5, 0.45, function(t)
        local saw = ((110 * t) % 1) * 2 - 1
        return saw * 0.5 + (love.math.random() * 2 - 1) * 0.5
    end))

    -- 온도가 적정 구간을 벗어날 때
    Audio.warn = source("warn", synth(0.12, 16, 0.16, sine(720)))

    -- 메트로놈
    Audio.tick_ = source("tick", synth(0.05, 70, 0.22, sine(1250)))

    -- 박자를 놓쳐 압출이 거부될 때
    Audio.reject = source("reject", synth(0.13, 14, 0.26, function(t)
        return (math.sin(2 * math.pi * 92 * t) >= 0 and 1 or -1) * 0.7
    end))
end

local function play(source, pitch, volume)
    if not source then return end
    local s = source:clone()
    s:setPitch(pitch or 1)
    s:setVolume(volume or 1)
    s:play()
end

-- 연속으로 잘 얹을수록 음이 올라간다
function Audio.placed(combo)
    local i = math.min(math.max(combo, 1), #STEPS)
    play(Audio.place, 2 ^ (STEPS[i] / 12))
end

function Audio.cutOff(amount)
    play(Audio.cut, 0.8 + math.min(amount, 40) / 40, 0.5 + math.min(amount, 40) / 80)
end

function Audio.crashed()
    play(Audio.crash)
end

-- 붕괴음 아래에 한 옥타브 낮게 깔아 덩치를 키운다
function Audio.boom()
    play(Audio.crash, 0.45, 1.0)
    play(Audio.cut, 0.35, 1.0)
end

function Audio.warned()
    play(Audio.warn)
end

-- 정박마다. 네 박에 한 번은 낮고 크게
function Audio.tick(accent)
    if accent then
        play(Audio.tick_, 0.68, 1.0)
    else
        play(Audio.tick_, 1.0, 0.55)
    end
end

-- 정타는 아니지만 층은 놓였을 때
function Audio.placedDull()
    play(Audio.place, 0.72, 0.7)
end

function Audio.rejected()
    play(Audio.reject)
end

return Audio
