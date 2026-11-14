-- 화면에 나오는 모든 글자. 코드에 한글을 직접 쓰지 않는다
local Lang = {}

local FILE = "lang.txt"

local S = {
    ko = {
        title = "스파게티",
        tagline = "박자에 맞춰 쌓는 3D 프린터",
        start = "시작",
        language = "언어",
        language_value = "한국어",
        collection = "컬렉션",
        resume = "계속하기",
        restart = "처음부터",
        screenfx = "화면 효과",
        quit = "끝내기",
        fx = { "강하게", "약하게", "끔" },

        howto = "조작법",
        choose_hint = "위아래로 고르고 엔터",
        menu_help = "게임에서는 박자에 맞춰 스페이스, W 로 가열.\n노즐은 정박마다 한가운데에서 잠깐 멎는다.\n그때 누르면 정타, 조금 어긋나면 보통,\n많이 어긋나면 아예 압출되지 않는다.",
        title_hint = "박자에 맞춰 스페이스",

        layers = "%d층",
        mm = "%.1f mm",
        best = "최고 %d층",
        bpm = "%d BPM",
        combo = "%d연속 정타",
        nozzle = "노즐 %d도",

        temp_ok = "정상",
        temp_sag = "늘어짐 - 온도가 높다",
        temp_cold = "접착 불량 - 가열해라",

        judge_perfect = "정타",
        judge_good = "보통",
        judge_miss = "엇박",
        judge_combo = "%d연속",

        over_sub = "%d층 · %.1f mm",
        over_added = "컬렉션에 추가됨 · %d점 · 최고 %d층",
        over_retry = "스페이스 또는 R 로 다시",

        coll_title = "실패작 컬렉션",
        coll_count = "%d점",
        coll_empty = "아직 아무것도 못 만들었다",
        coll_item = "%d층 · %s",
        back = "ESC 로 돌아가기",

        items = { "덩어리", "코스터", "문 괴임돌", "연필꽂이", "화분",
                  "사탑", "탑", "첨탑", "작품" },
        grades = { "폐기", "재활용함", "서랍행", "책상 위", "전시" },
    },

    en = {
        title = "SPAGHETTI",
        tagline = "a 3D printer that stacks on the beat",
        start = "Start",
        language = "Language",
        language_value = "English",
        collection = "Collection",
        resume = "Resume",
        restart = "Restart",
        screenfx = "Screen effects",
        quit = "Quit",
        fx = { "Strong", "Light", "Off" },

        howto = "Controls",
        choose_hint = "Arrow keys to choose, Enter to pick",
        menu_help = "Space on the beat to extrude, W to heat.\nThe nozzle pauses dead centre on every beat.\nHit it then for PERFECT, a little off for OK,\ntoo far off and nothing comes out.",
        title_hint = "Space on the beat",

        layers = "%d layers",
        mm = "%.1f mm",
        best = "best %d",
        bpm = "%d BPM",
        combo = "%d in a row",
        nozzle = "nozzle %d\194\176C",

        temp_ok = "OK",
        temp_sag = "sagging - too hot",
        temp_cold = "not sticking - heat it",

        judge_perfect = "PERFECT",
        judge_good = "OK",
        judge_miss = "OFF-BEAT",
        judge_combo = "%d in a row",

        over_sub = "%d layers · %.1f mm",
        over_added = "added to collection · %d items · best %d",
        over_retry = "Space or R to try again",

        coll_title = "FAILED PRINTS",
        coll_count = "%d items",
        coll_empty = "nothing made yet",
        coll_item = "%d layers · %s",
        back = "ESC to go back",

        items = { "blob", "coaster", "doorstop", "pen cup", "planter",
                  "leaning tower", "tower", "spire", "sculpture" },
        grades = { "trash", "recycling", "drawer", "desk", "display" },
    },
}

Lang.codes = { "en", "ko" }
Lang.current = "en"      -- 처음 켤 때 기본값

function Lang.load()
    if love.filesystem.getInfo(FILE) then
        local code = (love.filesystem.read(FILE) or ""):gsub("%s", "")
        if S[code] then Lang.current = code end
    end
end

function Lang.set(code)
    if S[code] then
        Lang.current = code
        love.filesystem.write(FILE, code)
    end
end

function Lang.next()
    for i, c in ipairs(Lang.codes) do
        if c == Lang.current then
            Lang.set(Lang.codes[i % #Lang.codes + 1])
            return
        end
    end
end

-- L("layers", 26) 처럼 쓴다
function Lang.get(key, ...)
    local v = S[Lang.current][key] or S.ko[key] or key
    if select("#", ...) > 0 then return string.format(v, ...) end
    return v
end

function Lang.list(key)
    return S[Lang.current][key] or S.ko[key]
end

return Lang
