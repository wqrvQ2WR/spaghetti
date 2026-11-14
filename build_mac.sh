#!/bin/sh
# 맥용 .app 과 .dmg 를 만든다. LÖVE 앱 껍데기에 game.love 를 넣는 방식.
set -e
cd "$(dirname "$0")"

LOVE_APP="$HOME/Applications/love.app"
APP="dist/Spaghetti.app"
STAGE=".build/dmg"

[ -d "$LOVE_APP" ] || { echo "love.app 이 없다: $LOVE_APP"; exit 1; }

mkdir -p .build dist

# 1) game.love (윈도우 빌드와 같은 내용)
echo "game.love 묶는 중"
rm -f .build/game.love
zip -q -r .build/game.love main.lua conf.lua src assets icon.png -x "*.DS_Store"

# 2) 껍데기 복사
rm -rf "$APP"
cp -R "$LOVE_APP" "$APP"
cp .build/game.love "$APP/Contents/Resources/"
cp icon.icns "$APP/Contents/Resources/Spaghetti.icns"

# LÖVE 자체 아이콘들은 치운다. 안 치우면 그쪽이 먼저 잡힌다
rm -f "$APP/Contents/Resources/OS X AppIcon.icns" \
      "$APP/Contents/Resources/GameIcon.icns" \
      "$APP/Contents/Resources/Assets.car"

# 3) 이름과 아이콘
P="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Spaghetti" "$P"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.hayoonjae.spaghetti" "$P"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Spaghetti" "$P"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0" "$P"
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Spaghetti" "$P" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Spaghetti" "$P"
# .love 파일을 가로채지 않게 문서 타입 선언을 뺀다
/usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$P" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations" "$P" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true

# 4) 껍데기를 건드렸으니 다시 서명하고 격리 속성을 지운다
xattr -cr "$APP"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1
echo ".app 완료: $APP"

# 5) dmg
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f dist/Spaghetti.dmg
hdiutil create -quiet -volname "Spaghetti" -srcfolder "$STAGE" \
    -ov -format UDZO dist/Spaghetti.dmg
rm -rf "$STAGE"

echo "완료: dist/Spaghetti.dmg"
du -sh dist/Spaghetti.dmg
