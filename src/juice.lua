-- 피드백(juice) 전담: 트라우마 기반 화면 흔들림, 히트스톱, 파티클, 플래시, 이징
local Juice = {}
Juice.__index = Juice

local POOL = 420
local MAX_OFFSET_X, MAX_OFFSET_Y = 10, 7
local MAX_ROLL = 0.055
local DECAY = 1.3          -- 초당 잃는 트라우마

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

-- 0 -> 1 로 가되 1 을 살짝 넘었다 돌아온다. "팝" 전용
function Juice.easeOutBack(k)
    local c1 = 1.70158
    local c3 = c1 + 1
    local m = k - 1
    return 1 + c3 * m * m * m + c1 * m * m
end

-- 감속해서 멎는다. 기본값
function Juice.easeOutCubic(k)
    local m = 1 - k
    return 1 - m * m * m
end

function Juice.lerp(a, b, k)
    return a + (b - a) * k
end

-- 색상환 -> rgb. 층 색과 폭발 불똥 색을 맞추는 데 쓴다
function Juice.hsl(h, s, l)
    local c = (1 - math.abs(2 * l - 1)) * s
    local hp = h / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local r, g, b
    if hp < 1 then r, g, b = c, x, 0
    elseif hp < 2 then r, g, b = x, c, 0
    elseif hp < 3 then r, g, b = 0, c, x
    elseif hp < 4 then r, g, b = 0, x, c
    elseif hp < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    local m = l - c / 2
    return r + m, g + m, b + m
end

function Juice.new()
    local self = setmetatable({}, Juice)
    self.shakeScale = 1.0      -- 접근성 설정 (1 / 0.5 / 0)
    self.parts = {}
    for i = 1, POOL do self.parts[i] = { alive = false } end
    self:reset()
    return self
end

function Juice:reset()
    self.trauma = 0
    self.t = 0
    self.freeze = 0
    self.flash = 0
    self.rings = {}
    for i = 1, POOL do self.parts[i].alive = false end
end

-- 더한다. 덮어쓰지 않는다
function Juice:addTrauma(amount)
    self.trauma = clamp(self.trauma + amount, 0, 1)
end

-- 시간을 잠깐 멈춘다. 박자가 중요한 구간에서는 쓰지 말 것
function Juice:hitStop(duration)
    self.freeze = math.max(self.freeze, duration)
end

-- 퍼져 나가는 충격파 고리
function Juice:shockwave(x, y, size)
    self.rings[#self.rings + 1] = { x = x, y = y, t = 0, size = size or 260 }
end

function Juice:flashScreen(amount)
    self.flash = math.max(self.flash, amount * self.shakeScale)
end

function Juice:burst(x, y, n, r, g, b, power)
    power = power or 1
    for _ = 1, n do
        for i = 1, POOL do
            local p = self.parts[i]
            if not p.alive then
                local a = love.math.random() * math.pi * 2
                local sp = (40 + love.math.random() * 160) * power
                p.alive = true
                p.x, p.y = x, y
                p.vx, p.vy = math.cos(a) * sp, math.sin(a) * sp - 60
                p.life = (0.5 + love.math.random() * 0.4) * (power > 1 and 1.8 or 1)
                p.max = p.life
                p.size = (2 + love.math.random() * 3) * math.min(power, 1.6)
                p.r, p.g, p.b = r, g, b
                break
            end
        end
    end
end

-- 월드를 진행시켜도 되는지 돌려준다 (히트스톱 중에는 false)
function Juice:update(dt)
    if self.freeze > 0 then
        self.freeze = self.freeze - dt
        return false
    end

    self.t = self.t + dt
    self.trauma = math.max(0, self.trauma - DECAY * dt)
    self.flash = math.max(0, self.flash - dt * 4)

    for i = #self.rings, 1, -1 do
        local ring = self.rings[i]
        ring.t = ring.t + dt
        if ring.t > 0.55 then table.remove(self.rings, i) end
    end

    for i = 1, POOL do
        local p = self.parts[i]
        if p.alive then
            p.life = p.life - dt
            if p.life <= 0 then
                p.alive = false
            else
                p.vy = p.vy + 620 * dt
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
            end
        end
    end
    return true
end

-- 매 프레임 rand 를 쓰면 지직거린다. 주기가 안 맞는 사인을 겹쳐 쓴다
local function axis(seed, t)
    return 0.6 * math.sin(t * 11 + seed) + 0.4 * math.sin(t * 23 + seed * 2)
end

function Juice:shake()
    if self.trauma <= 0 or self.shakeScale <= 0 then return 0, 0, 0 end
    local s = self.trauma * self.trauma * self.shakeScale
    return MAX_OFFSET_X * s * axis(0, self.t),
           MAX_OFFSET_Y * s * axis(1.7, self.t),
           MAX_ROLL * s * axis(3.1, self.t)
end

function Juice:drawRings()
    for _, ring in ipairs(self.rings) do
        local k = ring.t / 0.55
        local e = Juice.easeOutCubic(k)
        love.graphics.setLineWidth(6 * (1 - k))
        love.graphics.setColor(1, 1, 1, 0.75 * (1 - k))
        love.graphics.circle("line", ring.x, ring.y, ring.size * e)
        love.graphics.setLineWidth(1)
    end
end

function Juice:drawParticles()
    for i = 1, POOL do
        local p = self.parts[i]
        if p.alive then
            local a = clamp(p.life / p.max, 0, 1)
            love.graphics.setColor(p.r, p.g, p.b, a)
            love.graphics.rectangle("fill", p.x - p.size / 2, p.y - p.size / 2,
                p.size, p.size, 1)
        end
    end
end

function Juice:drawFlash(w, h)
    if self.flash <= 0 then return end
    love.graphics.setColor(1, 1, 1, math.min(0.7, self.flash))
    love.graphics.rectangle("fill", 0, 0, w, h)
end

Juice.LEVELS = { 1.0, 0.5, 0 }
Juice.LEVEL_NAMES = { "강하게", "약하게", "끔" }

return Juice
