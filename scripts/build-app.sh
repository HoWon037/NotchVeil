#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/NotchVeil.app"
LOGIN_APP_DIR="$APP_DIR/Contents/Library/LoginItems/NotchVeilLoginLauncher.app"

export DEVELOPER_DIR

cd "$ROOT_DIR"
swift build -c release --scratch-path "$BUILD_DIR"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$LOGIN_APP_DIR/Contents/MacOS"
mkdir -p "$LOGIN_APP_DIR/Contents/Resources"
cp "$BUILD_DIR/release/NotchVeil" "$APP_DIR/Contents/MacOS/NotchVeil"
cp "$BUILD_DIR/release/NotchVeilLoginLauncher" "$LOGIN_APP_DIR/Contents/MacOS/NotchVeilLoginLauncher"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/LoginLauncher-Info.plist" "$LOGIN_APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$LOGIN_APP_DIR/Contents/Resources/AppIcon.icns"
chmod 755 "$APP_DIR/Contents/MacOS/NotchVeil"
chmod 755 "$LOGIN_APP_DIR/Contents/MacOS/NotchVeilLoginLauncher"
codesign --force --sign - "$LOGIN_APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
