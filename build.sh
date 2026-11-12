#!/bin/bash
# 编译并打包「鼠标键 → 右 Option」
set -euo pipefail

ROOT="/Users/wuwu/Documents/work/wk/mouse-right-option"
APP="$ROOT/build/MouseRightOption.app"
BIN="$APP/Contents/MacOS/MouseRightOption"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

swiftc -O -swift-version 5 \
  -o "$BIN" \
  "$ROOT/main.swift" \
  -framework Cocoa -framework ApplicationServices

chmod +x "$BIN"

# ad-hoc 签名（本地自用）
codesign --force --sign - --timestamp=none "$APP" 2>&1 | tail -2

echo "BUILD_OK: $APP"
