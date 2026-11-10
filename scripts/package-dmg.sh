#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
OUTPUT="$ROOT_DIR/dist/NotchVeil.dmg"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null
if [[ -L "$OUTPUT" || ( -e "$OUTPUT" && ! -f "$OUTPUT" ) ]]; then
    echo "error: DMG output must be a regular file." >&2
    exit 2
fi

staging_dir=$(mktemp -d "$ROOT_DIR/dist/.notchveil-dmg.XXXXXX")
trap '[[ "$staging_dir" == "$ROOT_DIR/dist/.notchveil-dmg."* ]] && /bin/rm -rf "$staging_dir"' EXIT
mkdir "$staging_dir/contents"
ditto --norsrc --noextattr "$ROOT_DIR/dist/NotchVeil.app" "$staging_dir/contents/NotchVeil.app"
ln -s /Applications "$staging_dir/contents/Applications"

hdiutil create -quiet -format UDZO -fs HFS+ -volname NotchVeil \
    -srcfolder "$staging_dir/contents" "$staging_dir/NotchVeil.dmg"
hdiutil verify "$staging_dir/NotchVeil.dmg" >/dev/null
mv -f "$staging_dir/NotchVeil.dmg" "$OUTPUT"
echo "$OUTPUT"
