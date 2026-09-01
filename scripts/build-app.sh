#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_DIR="$ROOT_DIR/.build"
APP_DIR="$ROOT_DIR/dist/NotchVeil.app"
LOGIN_APP_DIR="$APP_DIR/Contents/Library/LoginItems/NotchVeilLoginLauncher.app"

# A Developer ID identity makes SMAppService login-item registration reliable.
# Ad-hoc ("-") still builds a runnable app, but macOS frequently refuses to
# register its login item, so warn instead of failing silently at runtime.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

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

# Sign inside out. `--deep` is deprecated and would re-sign nested bundles with
# the outer bundle's options, which is wrong for the login item.
codesign --force --options runtime --timestamp=none \
    --sign "$SIGN_IDENTITY" "$LOGIN_APP_DIR"
codesign --force --options runtime --timestamp=none \
    --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR" >/dev/null 2>&1 \
    || echo "warning: signature verification failed for $APP_DIR" >&2

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    cat >&2 <<'WARN'
warning: signed ad-hoc. macOS may refuse to register the login item
         (SMAppService), so "로그인할 때 자동 실행" can fail with an error alert.
         Set SIGN_IDENTITY to a Developer ID Application identity for a build
         where launch-at-login works reliably, e.g.
           SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
WARN
fi

echo "$APP_DIR"
