#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
BUILD_DIR="$ROOT_DIR/.build"
OUTPUT_APP="$ROOT_DIR/dist/NotchVeil.app"

# Ad-hoc signing is useful for development; distribution requires a stable identity.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

export DEVELOPER_DIR
if [[ ! -d "$DEVELOPER_DIR/Platforms/MacOSX.platform" ]]; then
    echo "error: select a full Xcode installation or set DEVELOPER_DIR." >&2
    exit 2
fi

# Never remove build output through a redirected distribution directory.
if [[ -L "$ROOT_DIR/dist" || -L "$OUTPUT_APP" ]]; then
    echo "error: dist and the output app must not be symbolic links." >&2
    exit 2
fi

cd "$ROOT_DIR"
swift build -c release --scratch-path "$BUILD_DIR"

# Assemble and verify before replacing a previously successful build.
mkdir -p "$ROOT_DIR/dist"
STAGING_DIR=$(mktemp -d "$ROOT_DIR/dist/.notchveil-build.XXXXXX")
APP_DIR="$STAGING_DIR/NotchVeil.app"
LOGIN_APP_DIR="$APP_DIR/Contents/Library/LoginItems/NotchVeilLoginLauncher.app"
PREVIOUS_APP="$STAGING_DIR/previous-app"
published=false
cleanup() {
    if [[ "$published" == false && -e "$PREVIOUS_APP" ]]; then
        echo "error: previous build preserved at: $PREVIOUS_APP" >&2
    elif [[ "$STAGING_DIR" == "$ROOT_DIR/dist/.notchveil-build."* ]]; then
        /bin/rm -rf "$STAGING_DIR"
    fi
}
trap cleanup EXIT

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$LOGIN_APP_DIR/Contents/MacOS"
mkdir -p "$LOGIN_APP_DIR/Contents/Resources"
cp "$BUILD_DIR/release/NotchVeil" "$APP_DIR/Contents/MacOS/NotchVeil"
cp "$BUILD_DIR/release/NotchVeilLoginLauncher" "$LOGIN_APP_DIR/Contents/MacOS/NotchVeilLoginLauncher"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/LoginLauncher-Info.plist" "$LOGIN_APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
/usr/bin/sips -Z 44 "$ROOT_DIR/Resources/AppIcon-1024.png" --out "$APP_DIR/Contents/Resources/SettingsIcon.png" >/dev/null
/usr/bin/sips -Z 88 "$ROOT_DIR/Resources/AppIcon-1024.png" --out "$APP_DIR/Contents/Resources/SettingsIcon@2x.png" >/dev/null
cp "$ROOT_DIR/Resources/AppIcon.icns" "$LOGIN_APP_DIR/Contents/Resources/AppIcon.icns"

# Native icon catalog for macOS 26+. Keep the existing ICNS for older systems.
sdk_version=$(xcrun --sdk macosx --show-sdk-version)
if (( ${sdk_version%%.*} >= 26 )); then
    icon_output="$BUILD_DIR/native-icon"
    mkdir -p "$icon_output"
    xcrun actool "$ROOT_DIR/Resources/NotchVeil.icon" \
        --compile "$icon_output" --platform macosx \
        --minimum-deployment-target 12.0 --app-icon NotchVeil \
        --output-partial-info-plist "$icon_output/Info.plist"
    cp "$icon_output/Assets.car" "$APP_DIR/Contents/Resources/Assets.car"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string NotchVeil" "$APP_DIR/Contents/Info.plist"
fi
chmod 755 "$APP_DIR/Contents/MacOS/NotchVeil"
chmod 755 "$LOGIN_APP_DIR/Contents/MacOS/NotchVeilLoginLauncher"

# Sign inside out. `--deep` is deprecated and would re-sign nested bundles with
# the outer bundle's options, which is wrong for the login item.
timestamp_option=--timestamp
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    timestamp_option=--timestamp=none
fi
codesign --force --options runtime "$timestamp_option" \
    --sign "$SIGN_IDENTITY" "$LOGIN_APP_DIR"
codesign --force --options runtime "$timestamp_option" \
    --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --strict --verbose=2 "$LOGIN_APP_DIR" >/dev/null 2>&1 \
    || { echo "error: login helper signature verification failed" >&2; exit 1; }
codesign --verify --strict --verbose=2 "$APP_DIR" >/dev/null 2>&1 \
    || { echo "error: signature verification failed for $APP_DIR" >&2; exit 1; }

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    cat >&2 <<'WARN'
warning: signed ad-hoc. macOS may refuse to register the login item
         (SMAppService), so launch at login may fail.
         Set SIGN_IDENTITY to a Developer ID Application identity for a build
         where launch-at-login works reliably, e.g.
           SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
WARN
fi

if [[ -e "$OUTPUT_APP" ]]; then
    mv "$OUTPUT_APP" "$PREVIOUS_APP"
fi
if ! mv "$APP_DIR" "$OUTPUT_APP"; then
    if [[ -e "$PREVIOUS_APP" ]]; then
        mv "$PREVIOUS_APP" "$OUTPUT_APP" \
            || echo "error: could not restore previous build" >&2
    fi
    exit 1
fi
published=true
echo "$OUTPUT_APP"
