-- 화면 그리기 전담
local Game = require("src.game")
local Juice = require("src.juice")
local Screen = require("src.screen")
local Menu = require("src.menu")
local Lang = require("src.lang")
local L = Lang.get

local Draw = {}

local W, H = Game.W, Game.H
local fonts, bg = {}, nil

local function hsl(h, s, l)
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

function Draw.load()
    local regular = "assets/fonts/Pretendard-Regular.otf"
    local bold = "assets/fonts/Pretendard-Bold.otf"
    fonts.title = love.graphics.newFont(bold, 40)
    fonts.score = love.graphics.newFont(bold, 26)
    fonts.label = love.graphics.newFont(bold, 14)
    fonts.judge = love.graphics.newFont(bold, 20)
    fonts.name = love.graphics.newFont(bold, 30)
    fonts.hero = love.graphics.newFont(bold, 46)
    fonts.tiny = love.graphics.newFont(regular, 11)
    fonts.body = love.graphics.newFont(regular, 15)
    fonts.small = love.graphics.newFont(regular, 12)

    bg = love.graphics.newMesh({
        { 0, 0, 0, 0, 0.42, 0.80, 0.99, 1 },
        { W, 0, 1, 0, 0.56, 0.74, 1.00, 1 },
        { W, H, 1, 1, 1.00, 0.78, 0.90, 1 },
        { 0, H, 0, 1, 1.00, 0.86, 0.70, 1 },
    }, "fan")
end

local function drawBox(body, w, h, r, g, b, radius, sx, sy, flash)
    love.graphics.push()
    love.graphics.translate(body:getX(), body:getY())
    love.graphics.rotate(body:getAngle())
    love.graphics.scale(sx or 1, sy or 1)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, radius or 3)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("fill", -w / 2, -h / 2, w, math.max(2, h * 0.3), radius or 3)
    if flash and flash > 0 then
        love.graphics.setColor(1, 1, 1, math.min(1, flash / 0.12) * 0.85)
        love.graphics.rectangle("fill", -w / 2, -h / 2, w, h, radius or 3)
    end
    love.graphics.pop()
end

local function drawWorld(g)
    local topY = g:towerTop()

    -- 프린터 레일과 갠트리
    love.graphics.setColor(0.78, 0.80, 0.86, 1)
    local railTop, railBottom = topY - 800, g.bedY + 58
    love.graphics.rectangle("fill", 14, railTop, 12, railBottom - railTop, 4)
    love.graphics.rectangle("fill", W - 26, railTop, 12, railBottom - railTop, 4)

    -- 프린터 본체
    love.graphics.setColor(0.70, 0.73, 0.80, 1)
    love.graphics.rectangle("fill", 10, g.bedY + 44, W - 20, 120, 8)
    love.graphics.setColor(0.60, 0.63, 0.71, 1)
    love.graphics.rectangle("fill", 34, g.bedY + 66, W - 68, 34, 5)
    love.graphics.setColor(0.42, 0.78, 0.62, 1)
    love.graphics.rectangle("fill", 44, g.bedY + 76, 14, 14, 3)
    do
        local d = math.abs(g:beatOffset())
        local near = 1 - math.min(1, d * 2.6)
        local r, gg, b = 0.86, 0.88, 0.93
        if d <= Game.PERFECT then
            r, gg, b = 0.30, 0.86, 0.52
        elseif d <= Game.GOOD then
            r, gg, b = 0.98, 0.74, 0.32
        end
        love.graphics.setColor(Juice.lerp(0.86, r, near), Juice.lerp(0.88, gg, near),
            Juice.lerp(0.93, b, near), 1)
        love.graphics.rectangle("fill", 14, g:nozzleY() - 16, W - 28, 10 + 4 * near, 4)
    end

    -- 베드
    love.graphics.setColor(0.62, 0.66, 0.74, 1)
    love.graphics.rectangle("fill", W / 2 - Game.BED_W / 2, g.bedY - Game.BED_H / 2,
        Game.BED_W, Game.BED_H, 4)
    love.graphics.setColor(1, 1, 1, 0.25)
    for i = 0, 10 do
        local x = W / 2 - Game.BED_W / 2 + i * (Game.BED_W / 10)
        love.graphics.line(x, g.bedY - Game.BED_H / 2, x, g.bedY + Game.BED_H / 2)
    end

    -- 떨어지는 파편
    for _, d in ipairs(g.debris) do
        local a = math.min(1, d.life)
        love.graphics.setColor(0.95, 0.55, 0.45, a * 0.8)
        drawBox(d.body, d.w, d.h, 0.95, 0.55, 0.45, 2)
    end

    -- 쌓인 층
    for _, l in ipairs(g.layers) do
        local r, gg, b = hsl(l.hue, 0.82, 0.62)
        if l.kind == "cold" then
            r, gg, b = hsl(l.hue, 0.45, 0.70)
        end
        local k = math.min(1, l.popT / 0.18)
        local e = Juice.easeOutBack(k)
        drawBox(l.body, l.w, l.h, r, gg, b, 3,
            Juice.lerp(l.popX, 1, e), Juice.lerp(l.popY, 1, e), l.flashT)
    end

    -- 노즐에서 쭉 나오는 필라멘트
    if #g.filament > 1 then
        for i = 1, #g.filament - 1 do
            local a, b = g.filament[i], g.filament[i + 1]
            local k = i / #g.filament
            love.graphics.setLineWidth(4.5 * (1 - k) + 1)
            love.graphics.setColor(1, 0.84, 0.30, 0.9 * (1 - k))
            love.graphics.line(a.x, a.y, b.x, b.y)
        end
        love.graphics.setLineWidth(1)
    end

    -- 노즐
    local nx, ny = g.nozzleX, g:nozzleY()
    if g.nozzleShake > 0 then
        nx = nx + math.sin(love.timer.getTime() * 60) * 7 * g.nozzleShake
    end
    local heat = math.max(0, math.min(1, (g.temp - Game.IDEAL) / 60))
    love.graphics.setColor(0.52, 0.55, 0.62, 1)
    love.graphics.rectangle("fill", nx - 22, ny - 16, 44, 22, 4)
    love.graphics.setColor(0.4 + 0.6 * heat, 0.42 - 0.2 * heat, 0.48 - 0.3 * heat, 1)
    love.graphics.polygon("fill", nx - 10, ny + 6, nx + 10, ny + 6, nx + 4, ny + 20, nx - 4, ny + 20)

    -- 쳐야 하는 자리: 아래 층 한가운데로 점선을 올린다
    local tx = g:top().body:getX()
    local delta = math.abs(g:beatOffset())
    local closeness = math.min(1, delta * 2.6)

    local cr, cg, cb = 0.30, 0.34, 0.46        -- 아직 멀었다
    if delta <= Game.PERFECT then
        cr, cg, cb = 0.06, 0.70, 0.36          -- 지금 누르면 정타
    elseif delta <= Game.GOOD then
        cr, cg, cb = 0.93, 0.52, 0.06          -- 보통
    end

    love.graphics.setLineWidth(3)
    love.graphics.setColor(cr, cg, cb, 0.35 + 0.55 * (1 - closeness))
    local gy0, gy1 = g:towerTop() - 4, ny + 28
    local yy = gy1
    while yy > gy0 do
        love.graphics.line(tx, yy, tx, math.max(gy0, yy - 6))
        yy = yy - 12
    end

    -- 아래 층의 폭. 이 안에 들어가야 안 깎인다
    local tw = g:top().w / 2
    love.graphics.setColor(cr, cg, cb, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.line(tx - tw, gy0 - 7, tx - tw, gy0 + 9)
    love.graphics.line(tx + tw, gy0 - 7, tx + tw, gy0 + 9)

    -- 고정 과녁 + 좁혀 들어오는 고리. 둘이 겹치는 순간이 정타
    local TARGET = 16
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.25, 0.28, 0.38, 0.55)
    love.graphics.circle("line", nx, ny + 12, TARGET)

    love.graphics.setLineWidth(5)
    love.graphics.setColor(cr, cg, cb, 0.45 + 0.5 * (1 - closeness))
    love.graphics.circle("line", nx, ny + 12, TARGET + 50 * closeness)

    if g.beatPulse > 0 then
        love.graphics.setColor(cr, cg, cb, g.beatPulse * 0.9)
        love.graphics.circle("line", nx, ny + 12, TARGET + 40 * (1 - g.beatPulse))
    end
    love.graphics.setLineWidth(1)

    -- 판정
    if g.judge and g.judgeAt < 0.6 then
        local a = 1 - g.judgeAt / 0.6
        local r, gg, b = 0.15, 0.65, 0.40
        if g.judge == "judge_good" then r, gg, b = 0.85, 0.55, 0.12
        elseif g.judge == "judge_miss" then r, gg, b = 0.88, 0.28, 0.25 end
        local pop = Juice.easeOutBack(math.min(1, g.judgeAt / 0.18))
        love.graphics.push()
        love.graphics.translate(W / 2, ny - 54 - 18 * (1 - a))
        love.graphics.scale(Juice.lerp(0.4, 1, pop))
        love.graphics.setFont(fonts.judge)
        love.graphics.setColor(r, gg, b, a)
        love.graphics.printf(L(g.judge, g.judgeNum), -W / 2, -10, W, "center")
        love.graphics.pop()
    end

    g.juice:drawRings()
    g.juice:drawParticles()

    -- 압출 순간의 필라멘트
    if g.flash > 0 then
        love.graphics.setColor(1, 0.95, 0.4, g.flash * 2)
        love.graphics.setLineWidth(4)
        love.graphics.line(nx, ny + 20, nx, g:towerTop() + 6)
        love.graphics.setLineWidth(1)
    end
end

local function drawTempBar(g)
    local x, y, w, h = 24, H - 50, W - 48, 16
    local span = Game.TEMP_MAX - Game.TEMP_MIN

    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.rectangle("fill", x, y, w, h, 8)

    local bL = (Game.IDEAL - Game.BAND - Game.TEMP_MIN) / span
    local bR = (Game.IDEAL + Game.BAND - Game.TEMP_MIN) / span
    love.graphics.setColor(0.25, 0.85, 0.55, 0.85)
    love.graphics.rectangle("fill", x + w * bL, y, w * (bR - bL), h, 8)

    local p = (g.temp - Game.TEMP_MIN) / span
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.rectangle("fill", x + w * p - 2, y - 5, 4, h + 10, 2)

    local eff = g:effect()
    local text, r, gg, b
    if eff.kind == "ok" then
        text, r, gg, b = L("temp_ok"), 0.10, 0.45, 0.25
    elseif eff.kind == "sag" then
        text, r, gg, b = L("temp_sag"), 0.70, 0.25, 0.10
    else
        text, r, gg, b = L("temp_cold"), 0.15, 0.30, 0.65
    end

    love.graphics.setFont(fonts.label)
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.print(L("nozzle", math.floor(g.temp)), x, y - 24)
    love.graphics.setColor(r, gg, b, 1)
    love.graphics.printf(text, x, y - 24, w, "right")
end

local function drawHud(g)
    love.graphics.setFont(fonts.score)
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.print(L("layers", g.count), 24, 20)
    love.graphics.setFont(fonts.body)
    love.graphics.print(L("mm", g:heightMm()), 24, 52)

    if g.combo >= 2 then
        love.graphics.setFont(fonts.label)
        love.graphics.setColor(0.12, 0.60, 0.38, 1)
        love.graphics.print(L("combo", g.combo), 24, 76)
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.15, 0.17, 0.22, 0.65)
    love.graphics.printf(L("best", g.best), 0, 22, W - 24, "right")
    love.graphics.printf(L("bpm", math.floor(g:bpm())), 0, 42, W - 24, "right")

    love.graphics.setColor(1, 1, 1, 0.82)
    love.graphics.rectangle("fill", 0, H - 86, W, 86)
    love.graphics.setColor(0.15, 0.17, 0.22, 0.08)
    love.graphics.rectangle("fill", 0, H - 86, W, 1)

    -- 박자 점: 네 박 중 어디인지. 첫 박이 크다
    local beat = math.floor(g.beatPhase) % 4
    local cx0 = W / 2 - 3 * 13
    for i = 0, 3 do
        local on = (i == beat)
        local r = (i == 0 and 5 or 4) * (on and 1.7 or 1)
        if on then
            love.graphics.setColor(0.20, 0.80, 0.50, 1)
        else
            love.graphics.setColor(0.15, 0.17, 0.22, 0.22)
        end
        love.graphics.circle("fill", cx0 + i * 26, H - 72, r)
    end

    drawTempBar(g)
end

local function drawThumb(shape, x, y, w, h)
    if not shape or #shape == 0 then return end
    local minx, maxx, top = 1e9, -1e9, 0
    for _, l in ipairs(shape) do
        minx = math.min(minx, l.dx - l.w / 2)
        maxx = math.max(maxx, l.dx + l.w / 2)
        top = math.max(top, l.up + l.h / 2)
    end
    local sc = math.min(w / math.max(60, maxx - minx), h / math.max(60, top)) * 0.88
    local cx = x + w / 2 - (minx + maxx) / 2 * sc
    local by = y + h - 4

    for _, l in ipairs(shape) do
        local r, gg, b = hsl(l.hue, 0.82, 0.62)
        love.graphics.push()
        love.graphics.translate(cx + l.dx * sc, by - l.up * sc)
        love.graphics.rotate(l.ang)
        love.graphics.setColor(r, gg, b, 1)
        love.graphics.rectangle("fill", -l.w * sc / 2, -l.h * sc / 2,
            l.w * sc, math.max(1.5, l.h * sc), 1)
        love.graphics.pop()
    end
end

local function drawChip(text, cx, y, r, g, b, alpha)
    love.graphics.setFont(fonts.tiny)
    local w = fonts.tiny:getWidth(text) + 20
    love.graphics.setColor(r, g, b, 0.16 * alpha)
    love.graphics.rectangle("fill", cx - w / 2, y, w, 20, 10)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.printf(text, cx - w / 2, y + 4, w, "center")
end

local function drawOver(g)
    -- 터지는 걸 먼저 보여주고 결과창은 늦게 올린다
    local a = math.min(1, math.max(0, (g.overAt - 1.1) / 0.45))
    if a <= 0 then return end
    a = Juice.easeOutCubic(a)

    love.graphics.setColor(0.1, 0.11, 0.15, 0.55 * a)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local e = g.entry
    local pw, ph = W - 70, 330
    local px, py = 35, H / 2 - ph / 2 + 18 * (1 - a)
    love.graphics.setColor(1, 1, 1, 0.96 * a)
    love.graphics.rectangle("fill", px, py, pw, ph, 18)

    -- 만들어진 물건
    love.graphics.setColor(0.94, 0.95, 0.97, a)
    love.graphics.rectangle("fill", px + 110, py + 20, pw - 220, 96, 10)
    if e then drawThumb(e.shape, px + 116, py + 24, pw - 232, 88) end

    love.graphics.setFont(fonts.name)
    love.graphics.setColor(0.15, 0.17, 0.22, a)
    love.graphics.printf(e and Lang.list("items")[e.item] or "", px, py + 128, pw, "center")

    love.graphics.setFont(fonts.body)
    love.graphics.setColor(0.42, 0.45, 0.50, a)
    love.graphics.printf(L("over_sub", g.count, g:heightMm()), px, py + 168, pw, "center")

    if e then
        drawChip(Lang.list("grades")[e.grade], px + pw / 2, py + 198, 0.88, 0.42, 0.22, a)
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.15, 0.17, 0.22, 0.55 * a)
    love.graphics.printf(L("over_added", g.entryTotal or 0, g.best),
        px, py + 236, pw, "center")

    love.graphics.setFont(fonts.label)
    love.graphics.setColor(0.25, 0.55, 0.95, a)
    love.graphics.printf(L("over_retry"), px, py + 274, pw, "center")
end

local function drawCollection(g)
    love.graphics.setColor(0.10, 0.11, 0.15, 0.88)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(fonts.judge)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(L("coll_title"), 0, 54, W, "center")
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.printf(L("coll_count", #g.collection), 0, 82, W, "center")

    local cols, cw, ch = 3, 128, 150
    local gx = (W - cols * cw) / 2
    for i = 1, math.min(9, #g.collection) do
        local e = g.collection[i]
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x, y = gx + col * cw, 120 + row * ch

        love.graphics.setColor(1, 1, 1, 0.10)
        love.graphics.rectangle("fill", x + 6, y, cw - 12, ch - 14, 10)
        drawThumb(e.shape, x + 12, y + 8, cw - 24, 78)

        love.graphics.setFont(fonts.label)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(Lang.list("items")[e.item], x, y + 94, cw, "center")
        love.graphics.setFont(fonts.tiny)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf(L("coll_item", e.count, Lang.list("grades")[e.grade]), x, y + 116, cw, "center")
    end

    if #g.collection == 0 then
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf(L("coll_empty"), 0, H / 2 - 10, W, "center")
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.printf(L("back"), 0, H - 44, W, "center")
end

local function drawTitle(g)
    -- 장식용 탑
    local hues = { 28, 70, 140, 280 }
    local bw, bh = 150, 22
    local by = H * 0.74
    for i, hue in ipairs(hues) do
        local r, gg, b = hsl(hue, 0.82, 0.62)
        local w = bw - (i - 1) * 9
        love.graphics.setColor(r, gg, b, 1)
        love.graphics.rectangle("fill", W / 2 - w / 2 + (i % 2 == 0 and 7 or -7),
            by - (i - 1) * (bh + 4), w, bh, 5)
    end
    love.graphics.setColor(0.52, 0.55, 0.62, 1)
    love.graphics.rectangle("fill", W / 2 - 26, by - 4 * (bh + 4) - 26, 52, 24, 5)
    love.graphics.setColor(1, 0.84, 0.30, 1)
    love.graphics.rectangle("fill", W / 2 - 4, by - 4 * (bh + 4) - 4, 8, 22, 4)

    love.graphics.setFont(fonts.hero)
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.printf(L("title"), 0, H * 0.17, W, "center")
    love.graphics.setFont(fonts.body)
    love.graphics.setColor(0.15, 0.17, 0.22, 0.55)
    love.graphics.printf(L("tagline"), 0, H * 0.17 + 62, W, "center")

    local px, pw = 60, W - 120
    local y = H * 0.36
    for i, id in ipairs(Menu.titleItems) do
        local name, value = Menu.label(g, id)
        local focused = (g.menuIndex == i)
        if focused then
            love.graphics.setColor(1, 1, 1, 0.55)
            love.graphics.rectangle("fill", px, y - 8, pw, 34, 10)
            love.graphics.setColor(0.25, 0.55, 0.95, 1)
            love.graphics.rectangle("fill", px, y - 8, 3, 34, 2)
        end
        love.graphics.setFont(fonts.label)
        love.graphics.setColor(focused and 0.16 or 0.28, focused and 0.38 or 0.31,
            focused and 0.72 or 0.38, 1)
        love.graphics.print(name, px + 14, y)
        if value then
            love.graphics.setFont(fonts.body)
            love.graphics.setColor(0.35, 0.38, 0.44, 1)
            love.graphics.printf(value, px, y - 1, pw - 14, "right")
        end
        y = y + 38
    end

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.15, 0.17, 0.22, 0.5)
    love.graphics.printf(L("choose_hint"), 0, H - 56, W, "center")
end

local function drawPause(g)
    love.graphics.setColor(0.1, 0.11, 0.15, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local pw, ph = W - 70, 376
    local px, py = 35, H / 2 - ph / 2
    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.rectangle("fill", px, py, pw, ph, 18)

    love.graphics.setFont(fonts.judge)
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.printf(L("howto"), px, py + 26, pw, "center")

    local y = py + 70
    for i, id in ipairs(Menu.items) do
        local name, value = Menu.label(g, id)
        local focused = (g.menuIndex == i)
        if focused then
            love.graphics.setColor(0.25, 0.55, 0.95, 0.12)
            love.graphics.rectangle("fill", px + 16, y - 7, pw - 32, 32, 8)
            love.graphics.setColor(0.25, 0.55, 0.95, 1)
            love.graphics.rectangle("fill", px + 16, y - 7, 3, 32, 2)
        end
        love.graphics.setFont(fonts.label)
        love.graphics.setColor(focused and 0.16 or 0.30, focused and 0.38 or 0.32,
            focused and 0.72 or 0.38, 1)
        love.graphics.print(name, px + 30, y)
        love.graphics.setFont(fonts.body)
        love.graphics.setColor(0.42, 0.45, 0.50, 1)
        love.graphics.printf(value, px, y - 1, pw - 30, "right")
        y = y + 36
    end

    love.graphics.setColor(0.15, 0.17, 0.22, 0.10)
    love.graphics.rectangle("fill", px + 26, y + 2, pw - 52, 1)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.42, 0.45, 0.50, 1)
    love.graphics.printf(L("choose_hint"), px + 26, y + 16, pw - 52, "center")

    love.graphics.printf(L("menu_help"), px + 26, y + 40, pw - 52, "center")
end

function Draw.draw(g)
    Screen.push()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg)

    if g.state == "title" then
        drawTitle(g)
        Screen.pop()
        Screen.drawBars()
        return
    end

    local dx, dy, roll = g.juice:shake()
    love.graphics.push()
    love.graphics.translate(W / 2 + dx, H / 2 + dy)
    love.graphics.rotate(roll)
    love.graphics.translate(-W / 2, -H / 2 + g.camY)
    drawWorld(g)
    love.graphics.pop()

    g.juice:drawFlash(W, H)

    drawHud(g)
    if g.state == "over" then
        drawOver(g)
    elseif g.state == "paused" then
        drawPause(g)
    elseif g.state == "collection" then
        drawCollection(g)
    end
    Screen.pop()
    Screen.drawBars()
end

return Draw
