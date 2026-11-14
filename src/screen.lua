-- 기준 해상도 450x800 을 창 크기에 맞춰 통째로 스케일한다.
-- UI 를 절대 좌표로 찍어도 어느 창 크기에서든 같은 그림이 나온다.
local Screen = {}

Screen.REF_W, Screen.REF_H = 450, 800

-- 기준 비율을 지키면서 바탕화면에 들어가는 가장 큰 창을 잡는다.
-- 이렇게 해야 시작하자마자 테두리가 생기거나 아래가 잘리는 일이 없다
function Screen.fitWindow()
    local _, dh = love.window.getDesktopDimensions()
    local h = math.min(Screen.REF_H, math.floor(dh - 120))
    local w = math.floor(h * Screen.REF_W / Screen.REF_H)
    love.window.setMode(w, h, {
        resizable = true, minwidth = 360, minheight = 560,
        highdpi = true, vsync = 1,
    })
end

function Screen.metrics()
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w / Screen.REF_W, h / Screen.REF_H)
    return scale,
           (w - Screen.REF_W * scale) / 2,
           (h - Screen.REF_H * scale) / 2
end

function Screen.push()
    local scale, ox, oy = Screen.metrics()
    love.graphics.push()
    love.graphics.translate(ox, oy)
    love.graphics.scale(scale)
    love.graphics.setScissor(ox, oy, Screen.REF_W * scale, Screen.REF_H * scale)
end

function Screen.pop()
    love.graphics.setScissor()
    love.graphics.pop()
end

-- 남는 테두리를 채운다
function Screen.drawBars()
    local scale, ox, oy = Screen.metrics()
    if ox < 1 and oy < 1 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0.09, 0.10, 0.13, 1)
    love.graphics.rectangle("fill", 0, 0, ox, h)
    love.graphics.rectangle("fill", w - ox, 0, ox, h)
    love.graphics.rectangle("fill", 0, 0, w, oy)
    love.graphics.rectangle("fill", 0, h - oy, w, oy)
end

-- 창 좌표 -> 기준 좌표
function Screen.toRef(x, y)
    local scale, ox, oy = Screen.metrics()
    return (x - ox) / scale, (y - oy) / scale
end

return Screen
