#!/bin/zsh
set -euo pipefail
print -r -- build >> "$INSTALLER_TEST_CASE_DIR/events"
app="$INSTALLER_TEST_CASE_DIR/project/dist/NotchVeil.app"
mkdir -p "$app/Contents/MacOS"
cp "$INSTALLER_TEST_SOURCE/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$INSTALLER_TEST_SOURCE/Tests/InstallerTests/fixtures/register.sh" "$app/Contents/MacOS/NotchVeil"
chmod +x "$app/Contents/MacOS/NotchVeil"
