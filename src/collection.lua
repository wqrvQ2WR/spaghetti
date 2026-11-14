-- 망한 출력물 보관함. 끝날 때마다 한 점씩 늘어난다
local Collection = {}

local FILE = "collection.txt"
local MAX = 60

-- 층수로 정해지는 등급. 이름과 처분은 번호로만 저장한다 —
-- 글자로 저장하면 언어를 바꿨을 때 옛날 기록이 그 언어로 남는다
local TIERS = {
    {  2, 1, 1 },
    {  5, 2, 1 },
    {  9, 3, 2 },
    { 14, 4, 2 },
    { 20, 5, 3 },
    { 27, 6, 3 },
    { 35, 7, 4 },
    { 45, 8, 4 },
    { math.huge, 9, 5 },
}

function Collection.tierFor(count)
    for _, row in ipairs(TIERS) do
        if count <= row[1] then return row[2], row[3] end
    end
    return 1, 1
end

local function serialize(e)
    local parts = {}
    for _, l in ipairs(e.shape) do
        parts[#parts + 1] = string.format("%.1f,%.1f,%.1f,%.1f,%d,%.3f",
            l.dx, l.up, l.w, l.h, l.hue, l.ang)
    end
    return string.format("%d|%d|%d|%.1f|%s",
        e.item, e.grade, e.count, e.mm, table.concat(parts, ";"))
end

local function parse(line)
    local item, grade, count, mm, rest = line:match("^(.-)|(.-)|(%d+)|([%d%.]+)|(.*)$")
    if not item then return nil end
    count = tonumber(count)
    -- 예전에는 이름을 글자로 저장했다. 그런 줄은 층수로 다시 매긴다
    item, grade = tonumber(item), tonumber(grade)
    if not item or not grade then item, grade = Collection.tierFor(count) end
    local shape = {}
    for chunk in rest:gmatch("[^;]+") do
        local dx, up, w, h, hue, ang =
            chunk:match("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d%.]+),([%-%d]+),([%-%d%.]+)")
        if dx then
            shape[#shape + 1] = {
                dx = tonumber(dx), up = tonumber(up), w = tonumber(w),
                h = tonumber(h), hue = tonumber(hue), ang = tonumber(ang),
            }
        end
    end
    return { item = item, grade = grade, count = count,
             mm = tonumber(mm), shape = shape }
end

function Collection.load()
    local list = {}
    if love.filesystem.getInfo(FILE) then
        for line in love.filesystem.lines(FILE) do
            if #line > 0 then
                local e = parse(line)
                if e then list[#list + 1] = e end
            end
        end
    end
    return list
end

function Collection.save(list)
    local out = {}
    for i = 1, math.min(#list, MAX) do
        out[#out + 1] = serialize(list[i])
    end
    love.filesystem.write(FILE, table.concat(out, "\n"))
end

-- 가장 최근 것이 앞에 온다
function Collection.add(list, entry)
    table.insert(list, 1, entry)
    while #list > MAX do table.remove(list) end
    Collection.save(list)
    return #list
end

return Collection
