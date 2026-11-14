-- 층 쌓기 로직, 박자, 온도 관리, 붕괴 판정
local Audio = require("src.audio")
local Juice = require("src.juice")
local Collection = require("src.collection")

local Game = {}
Game.__index = Game

Game.W, Game.H = 450, 800

local W, H = Game.W, Game.H
local BED_W, BED_H = 220, 18
local LAYER_H = 16
local FIRST_W = 150   -- 층 최대 폭. 베드(220)보다 좁아야 처음에 여유가 생긴다
local IDEAL, BAND = 210, 12
local TEMP_MIN, TEMP_MAX = 150, 290

local SWING = 140     -- 노즐이 중앙에서 좌우로 벗어나는 최대 거리
local PERFECT = 0.10  -- 정타 판정 (박자 단위)
local GOOD = 0.22     -- 이보다 어긋나면 아예 압출되지 않는다
local BPM_MIN, BPM_MAX = 100, 180

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

function Game.new()
    local self = setmetatable({}, Game)
    self.best = 0
    self.bestCombo = 0
    self.collection = Collection.load()
    self.shakeLevel = 1
    self.menuIndex = 1
    self:reset()
    return self
end

function Game:reset()
    self.juice = self.juice or Juice.new()
    self.juice:reset()

    love.physics.setMeter(64)
    self.world = love.physics.newWorld(0, 9.81 * 64, true)
    self.layers = {}
    self.debris = {}

    self.state = "play"
    self.temp = IDEAL
    self.heating = false
    self.count = 0
    self.camY = 0
    self.bedY = H - 130
    self.flash = 0
    self.overReason = nil
    self.overAt = 0
    self.camLocked = nil
    self.finalMm = nil
    self.entry = nil

    self.combo = 0
    self.lastKind = "ok"

    self.beatPhase = 0      -- 박자 단위로 누적되는 시계
    self.beatIndex = -1
    self.lastBeat = -1      -- 한 박에 한 층만
    self.judge = nil
    self.judgeAt = 0
    self.beatPulse = 0
    self.nozzleShake = 0
    self.filament = {}

    local body = love.physics.newBody(self.world, W / 2, self.bedY, "static")
    local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(BED_W, BED_H))
    fixture:setFriction(1)
    self.bed = { body = body, w = BED_W, h = BED_H }

    self.nozzleX = W / 2
end

function Game:top()
    return self.layers[#self.layers] or self.bed
end

function Game:towerTop()
    local t = self:top()
    return t.body:getY() - t.h / 2
end

function Game:heightMm()
    if self.finalMm then return self.finalMm end
    return math.max(0, (self.bedY - BED_H / 2) - self:towerTop()) * 0.5
end

function Game:nozzleY()
    return self:towerTop() - 52
end

function Game:bpm()
    return math.min(BPM_MIN + self.count * 1.2, BPM_MAX)
end

-- 박자에 노즐을 묶는다. 정박마다 아래 층 한가운데에서 잠깐 멎고, 반박에 양 끝에 닿는다
function Game:nozzleAt(phase)
    local s = math.sin(math.pi * phase)
    local center = self:top().body:getX()
    return clamp(center + SWING * (0.65 * s * s * s + 0.35 * s), 30, W - 30)
end

-- 지금 누르면 정박에서 몇 박 어긋나는지
function Game:beatOffset()
    local nearest = math.floor(self.beatPhase + 0.5)
    return self.beatPhase - nearest, nearest
end

-- 온도가 층 품질에 미치는 영향
function Game:effect()
    local t = self.temp
    if t > IDEAL + BAND then
        local sag = clamp((t - (IDEAL + BAND)) / 45, 0, 1)
        return {
            kind = "sag", amount = sag,
            wMul = 1 + 0.15 * sag, hMul = 1 - 0.6 * sag,
            friction = 0.9 - 0.55 * sag, jitter = 0,
        }
    elseif t < IDEAL - BAND then
        local cold = clamp(((IDEAL - BAND) - t) / 45, 0, 1)
        return {
            kind = "cold", amount = cold,
            wMul = 1 - 0.25 * cold, hMul = 1,
            friction = 0.9 - 0.75 * cold, jitter = cold,
        }
    end
    return { kind = "ok", amount = 0, wMul = 1, hMul = 1, friction = 0.95, jitter = 0 }
end

function Game:addDebris(x, y, w, h)
    local body = love.physics.newBody(self.world, x, y, "dynamic")
    local shape = love.physics.newRectangleShape(math.max(3, w), math.max(3, h))
    local fixture = love.physics.newFixture(body, shape, 0.6)
    fixture:setSensor(true)
    body:applyAngularImpulse(love.math.random(-400, 400))
    self.debris[#self.debris + 1] = { body = body, w = w, h = h, life = 3 }
end

function Game:setJudge(key, num)
    self.judge, self.judgeNum, self.judgeAt = key, num, 0
end

function Game:place()
    if self.state ~= "play" then return end

    local delta, nearest = self:beatOffset()
    local off = math.abs(delta)

    -- 박자를 놓치면 압출 자체가 안 된다
    if off > GOOD or self.lastBeat == nearest then
        self.combo = 0
        self:setJudge("judge_miss")
        self.nozzleShake = 1
        Audio.rejected()
        return
    end
    self.lastBeat = nearest

    local perfect = off <= PERFECT
    local top = self:top()
    local eff = self:effect()

    local base = math.min(top.w, FIRST_W)
    local taper = perfect and 0 or 1
    local w = clamp(base * eff.wMul - taper, 8, math.min(FIRST_W, base * 1.15))
    local h = math.max(5, LAYER_H * eff.hMul)
    local y = top.body:getY() - top.h / 2 - h / 2

    -- 정타는 기계가 제자리에 찍어 준다
    local dropX = perfect and top.body:getX() or self.nozzleX

    local tx = top.body:getX()
    local pL, pR = tx - top.w / 2, tx + top.w / 2
    local nL, nR = dropX - w / 2, dropX + w / 2
    local oL, oR = math.max(pL, nL), math.min(pR, nR)
    local overlap = oR - oL

    if overlap <= 6 then
        self:addDebris(dropX, y, w, h)
        self:gameOver("완전히 빗나갔다")
        return
    end

    local left = oL - nL
    if left > 2 then self:addDebris(nL + left / 2, y, left, h) end
    local right = nR - oR
    if right > 2 then self:addDebris(oR + right / 2, y, right, h) end

    local shaved = math.max(left, right)
    if shaved > 2 then
        Audio.cutOff(shaved)
        self.juice:addTrauma(0.06 + math.min(shaved, 40) / 400)
        self.juice:burst(dropX, y, 3, 0.95, 0.55, 0.45)
    end

    local body = love.physics.newBody(self.world, (oL + oR) / 2, y, "dynamic")
    local fixture = love.physics.newFixture(body, love.physics.newRectangleShape(overlap, h), 1)
    fixture:setFriction(eff.friction)
    fixture:setRestitution(0)

    -- 차가우면 안 붙어서 얹히는 순간 틀어진다
    if eff.jitter > 0 then
        local dir = love.math.random() < 0.5 and -1 or 1
        body:applyLinearImpulse(dir * 30 * eff.jitter, 0)
        body:applyAngularImpulse(dir * 1100 * eff.jitter)
    end

    self.count = self.count + 1
    local popX, popY = 1.12, 0.88
    if perfect then
        self.combo = self.combo + 1
        self:setJudge("judge_perfect")
        Audio.placed(self.combo)
        popX, popY = 1.25, 0.70
        self.juice:addTrauma(0.14)
        self.juice:burst(dropX, y, 4, 1.0, 0.86, 0.35)
        -- 다섯 번 연속마다 한 단계 크게
        if self.combo % 5 == 0 then
            self:setJudge("judge_combo", self.combo)
            self.juice:addTrauma(0.35)
            self.juice:burst(dropX, y, 10, 1.0, 0.80, 0.30)
        end
    else
        self.combo = 0
        self:setJudge("judge_good")
        Audio.placedDull()
        self.juice:addTrauma(0.10)
        self.juice:burst(dropX, y, 2, 0.95, 0.75, 0.45)
    end
    if self.combo > self.bestCombo then self.bestCombo = self.combo end

    self.layers[#self.layers + 1] = {
        body = body, w = overlap, h = h,
        hue = (self.count * 27) % 360, kind = eff.kind, perfect = perfect,
        popT = 0, popX = popX, popY = popY, flashT = perfect and 0.12 or 0,
    }
    self.flash = 0.3
end

-- 쌓은 걸 통째로 날려 버린다. 층마다 바깥으로 밀고 제각기 돌린다
function Game:explode()
    local cx = self:top().body:getX()
    local cy = (self:towerTop() + self.bedY) / 2

    for _, l in ipairs(self.layers) do
        local x, y = l.body:getX(), l.body:getY()
        local dist = math.max(30, math.abs(y - cy))

        -- 탑이 세로로 길어서 "바깥으로"를 그냥 쓰면 위아래로만 늘어난다.
        -- 좌우는 따로 흩뿌리고, 위로 뜨는 힘만 중심에 가까울수록 세게 준다
        local side = love.math.random() < 0.5 and -1 or 1
        local sideways = side * (110 + love.math.random() * 190) + (x - cx) * 0.8
        local lift = -(130 + 1900 / dist)

        l.body:applyLinearImpulse(sideways, lift)
        l.body:applyAngularImpulse(love.math.random(-13000, 13000))
        l.body:setLinearDamping(0.05)

        local r, g, b = Juice.hsl(l.hue, 0.95, 0.62)
        self.juice:burst(x, y, 7, r, g, b, 2.2)
        l.flashT = 0.12
    end

    -- 중심에서 한 번 더, 흰빛으로
    self.juice:burst(cx, cy, 40, 1.0, 0.95, 0.75, 2.6)
    self.juice:shockwave(cx, cy, 300)
    self.juice:shockwave(cx, cy, 170)
end

-- 터지기 전 모양을 떠 둔다. 보관함 그림이 된다
function Game:captureShape()
    local base = self.bed.body:getX()
    local shape = {}
    for _, l in ipairs(self.layers) do
        shape[#shape + 1] = {
            dx = l.body:getX() - base,
            up = self.bedY - l.body:getY(),
            w = l.w, h = l.h, hue = l.hue, ang = l.body:getAngle(),
        }
    end
    return shape
end

function Game:gameOver(reason)
    if self.state ~= "play" then return end
    self.state = "over"
    self.camLocked = self.camY
    self.finalMm = self:heightMm()

    local item, grade = Collection.tierFor(self.count)
    self.entry = {
        item = item, grade = grade, count = self.count,
        mm = self.finalMm, shape = self:captureShape(),
    }
    self.entryTotal = Collection.add(self.collection, self.entry)
    Audio.crashed()
    Audio.boom()
    self.juice:addTrauma(1.0)
    self.juice:hitStop(0.18)        -- 터지기 직전 한 박 멎는다
    self.juice:flashScreen(0.9)
    self:explode()
    self.overReason = reason
    self.overAt = 0
    if self.count > self.best then self.best = self.count end
end

function Game:checkCollapse()
    for _, l in ipairs(self.layers) do
        if math.abs(l.body:getAngle()) > 0.6 then
            return self:gameOver("탑이 기울어 무너졌다")
        end
        if l.body:getY() > self.bedY + 80 then
            return self:gameOver("탑이 쓰러졌다")
        end
    end
end

function Game:update(dt)
    if self.state ~= "play" and self.state ~= "over" then return end
    if not self.juice:update(dt) then return end

    self.world:update(dt)
    self.flash = math.max(0, self.flash - dt * 3)
    self.judgeAt = self.judgeAt + dt
    self.beatPulse = math.max(0, self.beatPulse - dt * 4)
    self.nozzleShake = math.max(0, self.nozzleShake - dt * 5)

    for _, l in ipairs(self.layers) do
        l.popT = l.popT + dt
        if l.flashT > 0 then l.flashT = l.flashT - dt end
    end

    for i = #self.debris, 1, -1 do
        local d = self.debris[i]
        d.life = d.life - dt
        if d.life <= 0 or d.body:getY() > self.bedY + 600 then
            d.body:destroy()
            table.remove(self.debris, i)
        end
    end

    if self.state == "play" then
        self.beatPhase = self.beatPhase + dt / (60 / self:bpm())
        local index = math.floor(self.beatPhase)
        if index ~= self.beatIndex then
            self.beatIndex = index
            self.beatPulse = 1
            Audio.tick(index % 4 == 0)
        end
        self.nozzleX = self:nozzleAt(self.beatPhase)

        -- 노즐 끝에서 계속 흘러나와 늘어진다. 보이기만 하는 것이고 판정과는 무관하다
        table.insert(self.filament, 1,
            { x = self.nozzleX, y = self:nozzleY() + 20, age = 0 })
        for i = #self.filament, 1, -1 do
            local f = self.filament[i]
            f.age = f.age + dt
            f.y = f.y + 85 * dt
            if f.age > 0.26 then table.remove(self.filament, i) end
        end
        while #self.filament > 26 do table.remove(self.filament) end

        local cool = 16 + self.count * 0.8
        if self.heating then self.temp = self.temp + 78 * dt end
        self.temp = clamp(self.temp - cool * dt, TEMP_MIN, TEMP_MAX)

        local kind = self:effect().kind
        if kind ~= self.lastKind then
            if kind ~= "ok" then Audio.warned() end
            self.lastKind = kind
        end

        self:checkCollapse()
    else
        self.overAt = self.overAt + dt
    end

    if self.camLocked then
        self.camY = self.camLocked
    else
        local want = math.max(H * 0.42 - self:towerTop(), -205)
        self.camY = self.camY + (want - self.camY) * math.min(1, dt * 6)
    end
end

Game.BED_W, Game.BED_H = BED_W, BED_H
Game.FIRST_W = FIRST_W
Game.IDEAL, Game.BAND = IDEAL, BAND
Game.TEMP_MIN, Game.TEMP_MAX = TEMP_MIN, TEMP_MAX
Game.PERFECT, Game.GOOD = PERFECT, GOOD

return Game
