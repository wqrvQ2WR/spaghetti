-- 시작 화면과 ESC 메뉴. 키보드만으로 전부 조작된다
local Juice = require("src.juice")
local Lang = require("src.lang")
local L = Lang.get

local Menu = {}

Menu.titleItems = { "start", "language", "collection", "quit" }
Menu.items = { "resume", "collection", "restart", "shake", "quit" }

function Menu.list(g)
    return g.state == "title" and Menu.titleItems or Menu.items
end

function Menu.label(g, id)
    if id == "start" then return L("start"), nil
    elseif id == "language" then return L("language"), L("language_value")
    elseif id == "resume" then return L("resume"), "ESC"
    elseif id == "collection" then return L("collection"), L("coll_count", #g.collection)
    elseif id == "restart" then return L("restart"), "R"
    elseif id == "shake" then return L("screenfx"), Lang.list("fx")[g.shakeLevel]
    else return L("quit"), "Q" end
end

function Menu.open(g)
    g.state = "paused"
    g.menuIndex = 1          -- 열릴 때 항상 뭔가에 포커스가 가 있어야 한다
end

function Menu.move(g, delta)
    local list = Menu.list(g)
    g.menuIndex = (g.menuIndex - 1 + delta) % #list + 1
end

function Menu.adjust(g, delta)
    local id = Menu.list(g)[g.menuIndex]
    if id == "shake" then
        g.shakeLevel = (g.shakeLevel - 1 + delta) % #Juice.LEVELS + 1
        g.juice.shakeScale = Juice.LEVELS[g.shakeLevel]
        return true
    elseif id == "language" then
        Lang.next()
        return true
    end
    return false
end

-- "quit" 을 돌려주면 부르는 쪽에서 창을 닫는다
function Menu.activate(g)
    local id = Menu.list(g)[g.menuIndex]
    if id == "start" or id == "restart" then
        g:reset()
    elseif id == "resume" then
        g.state = "play"
    elseif id == "language" then
        Lang.next()
    elseif id == "collection" then
        g.collectionFrom = g.state
        g.state = "collection"
    elseif id == "shake" then
        Menu.adjust(g, 1)
    elseif id == "quit" then
        return "quit"
    end
end

return Menu
