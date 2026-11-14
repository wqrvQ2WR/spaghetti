#!/bin/sh
# LÖVE 는 brew cask 가 막혀서 ~/Applications 에 직접 설치해 둠
exec ~/Applications/love.app/Contents/MacOS/love "$(dirname "$0")"
