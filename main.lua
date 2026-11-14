local Game = require("src.game")
local Draw = require("src.draw")
local Audio = require("src.audio")
local Juice = require("src.juice")
local Menu = require("src.menu")
local Screen = require("src.screen")
local Lang = require("src.lang")

local game

-- love . --shot : 자동으로 몇 층 쌓고 스크린샷만 남기고 종료 (렌더링 검증용)
local shot = { on = false, t = 0, beat = nil, err = 0, hit = false, title = false, onbeat = false, play = false, menu = false, wide = false, wideShot = false, restored = false, boom1 = false, boom2 = false, over = false, coll = false, doneAt = nil }

function love.load(args)
    love.graphics.setDefaultFilter("linear", "linear")
    love.keyboard.setTextInput(false)   -- 글자 입력이 필요 없다. 입력기가 키를 먹는 걸 막는다
    Lang.load()
    if love.filesystem.getInfo("icon.png") then
        love.window.setIcon(love.image.newImageData("icon.png"))
    end
    Screen.fitWindow()
    Draw.load()
    Audio.load()
    game = Game.new()
    game.state = "title"
    game.menuIndex = 1

    for _, a in ipairs(args or {}) do
        if a == "--en" then Lang.set("en") end
        if a == "--shot" then
            shot.on = true
            love.audio.setVolume(0)   -- 검증용 실행은 조용히
        end
    end
end

local function act()
    if game.state == "play" then game:place() else game:reset() end
end

local function updateShot(dt)
    shot.t = shot.t + dt

    if game.state == "title" then
        if shot.t > 0.4 and not shot.title then
            love.graphics.captureScreenshot("title.png")
            shot.title = true
        elseif shot.title then
            game:reset()
        end
        return
    end

    -- 12초까지는 온도를 맞춰 주고, 그 뒤엔 방치해서 접착 불량을 만든다
    game.heating = shot.t < 12 and game.temp < 212
    game:update(dt)

    -- 박자를 ±0.12박 정도 흘리는 사람이 친다고 보고 친다
    if game.state == "play" then
        local _, nearest = game:beatOffset()
        if shot.beat ~= nearest then
            shot.beat = nearest
            shot.err = (love.math.random() - 0.5) * 0.24
            shot.hit = false
        end
        if not shot.hit and game.beatPhase >= nearest + shot.err then
            shot.hit = true
            game:place()
        end
    end

    -- 정박에 딱 맞은 순간
    if not shot.onbeat and shot.t > 7 and math.abs(game:beatOffset()) < 0.02 then
        love.graphics.captureScreenshot("onbeat.png")
        shot.onbeat = true
    end
    if not shot.play and shot.t > 8.5 then
        love.graphics.captureScreenshot("play.png")
        shot.play = true
    end
    if not shot.menu and shot.t > 9.2 then
        Menu.open(game)
        love.graphics.captureScreenshot("menu.png")
        shot.menu = true
    elseif shot.menu and game.state == "paused" then
        game.state = "play"
    end
    -- 창 크기를 바꿔도 레이아웃이 버티는지
    if not shot.wide and shot.t > 9.9 then
        love.window.setMode(880, 620, { resizable = true })
        shot.wide = true
    elseif shot.wide and not shot.wideShot and shot.t > 10.4 then
        love.graphics.captureScreenshot("wide.png")
        shot.wideShot = true
    elseif shot.wideShot and not shot.restored and shot.t > 10.9 then
        love.window.setMode(450, 800, { resizable = true })
        shot.restored = true
    end
    if game.state == "over" then
        if not shot.boom1 and game.overAt > 0.18 then
            love.graphics.captureScreenshot("boom1.png")
            shot.boom1 = true
        end
        if not shot.boom2 and game.overAt > 0.55 then
            love.graphics.captureScreenshot("boom2.png")
            shot.boom2 = true
        end
        if not shot.over and game.overAt > 1.9 then
            love.graphics.captureScreenshot("over.png")
            shot.over = true
        end
        if shot.over and not shot.coll and game.overAt > 2.4 then
            game.state = "collection"
            love.graphics.captureScreenshot("collection.png")
            shot.coll = true
            shot.doneAt = shot.t + 0.5
        end
    end
    if (shot.doneAt and shot.t > shot.doneAt) or shot.t > 40 then
        love.event.quit()
    end
end

function love.update(dt)
    if shot.on then
        return updateShot(1 / 60)
    end
    game.heating = love.keyboard.isScancodeDown("w")
        or love.keyboard.isScancodeDown("up")
    game:update(math.min(dt, 1 / 30))
end

function love.draw()
    Draw.draw(game)
end

function love.keypressed(key, scancode)
    local k = scancode or key
    if game.state == "collection" then
        if k == "escape" or k == "return" or k == "space" or k == "q" then
            game.state = game.collectionFrom or "paused"
        end
        return
    end

    if game.state == "title" then
        if k == "up" then Menu.move(game, -1)
        elseif k == "down" then Menu.move(game, 1)
        elseif k == "left" then Menu.adjust(game, -1)
        elseif k == "right" then Menu.adjust(game, 1)
        elseif k == "return" or k == "space" then
            if Menu.activate(game) == "quit" then love.event.quit() end
        elseif k == "escape" then
            love.event.quit()
        end
        return
    end

    if game.state == "paused" then
        if k == "escape" then
            game.state = "play"
        elseif k == "up" then
            Menu.move(game, -1)
        elseif k == "down" then
            Menu.move(game, 1)
        elseif k == "left" then
            Menu.adjust(game, -1)
        elseif k == "right" then
            Menu.adjust(game, 1)
        elseif k == "return" or k == "space" then
            if Menu.activate(game) == "quit" then love.event.quit() end
        elseif k == "r" then
            game:reset()
        elseif k == "q" then
            love.event.quit()
        end
        return
    end

    if k == "escape" then
        if game.state == "play" then
            Menu.open(game)
        else
            love.event.quit()
        end
    elseif k == "r" then
        game:reset()
    elseif k == "space" or k == "return" then
        act()
    end
end

function love.mousepressed()
    if game.state == "title" then return end
    if game.state == "collection" then
        game.state = game.collectionFrom or "paused"
        return
    end
    if game.state == "paused" then
        game.state = "play"
        return
    end
    act()
end
