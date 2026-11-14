#!/bin/sh
# 윈도우용 묶음을 만든다. LÖVE 윈도우 런타임을 받아서 game.love 를 붙이는 방식.
set -e
cd "$(dirname "$0")"

VER=11.5
RUNTIME="love-$VER-win64"
WORK=".build"
OUT="dist/spaghetti-win64"

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

# 1) 런타임
if [ ! -d "$WORK/$RUNTIME" ]; then
    echo "LÖVE $VER 윈도우 런타임 받는 중"
    curl -sL -o "$WORK/$RUNTIME.zip" \
        "https://github.com/love2d/love/releases/download/$VER/$RUNTIME.zip"
    unzip -q "$WORK/$RUNTIME.zip" -d "$WORK"
fi

# 2) game.love (게임에 실제로 필요한 것만)
echo "game.love 묶는 중"
rm -f "$WORK/game.love"
zip -q -r "$WORK/game.love" \
    main.lua conf.lua src assets icon.png \
    -x "*.DS_Store"

# 3) love.exe 뒤에 game.love 를 이어 붙이면 단독 실행 파일이 된다
cat "$WORK/$RUNTIME/love.exe" "$WORK/game.love" > "$OUT/Spaghetti.exe"

# 4) 같이 있어야 도는 dll 들
for f in SDL2.dll OpenAL32.dll love.dll lua51.dll mpg123.dll msvcp120.dll msvcr120.dll license.txt; do
    [ -f "$WORK/$RUNTIME/$f" ] && cp "$WORK/$RUNTIME/$f" "$OUT/"
done
cp icon.ico "$OUT/" 2>/dev/null || true

# 5) 통째로 zip
( cd dist && rm -f spaghetti-win64.zip && zip -q -r spaghetti-win64.zip spaghetti-win64 )

echo "완료: dist/spaghetti-win64.zip"
du -sh dist/spaghetti-win64.zip
