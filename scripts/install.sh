#!/bin/zsh
set -euo pipefail

# Builds NotchVeil, installs it, and repairs the login item registration.
#
# launchd guards the login item with a code requirement pinned to the launcher's
# code identity, and replacing the app invalidates it silently: SMAppService
# keeps reporting .enabled while every login fails with EX_CONFIG. Repairing it
# needs a settling delay and a registration issued from outside the running app,
# and neither the reported status nor launchd's "needs LWCR update" flag tells
# you whether it took. The only trustworthy check is to spawn the job and see.
# See Sources/NotchVeil/LoginItemRegistration.swift.

ROOT_DIR="${0:A:h:h}"
DESTINATION="${1:-/Applications/NotchVeil.app}"
LABEL="gui/$(id -u)/com.limdy.NotchVeil.LoginLauncher"
SETTLE_SECONDS="${SETTLE_SECONDS:-75}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null
"$ROOT_DIR/scripts/stop.sh"

rm -rf "$DESTINATION"
ditto "$ROOT_DIR/dist/NotchVeil.app" "$DESTINATION"
open "$DESTINATION"

if ! launchctl print "$LABEL" >/dev/null 2>&1; then
    echo "$DESTINATION"
    echo "로그인 자동 실행이 꺼져 있어 로그인 항목 복구는 건너뜁니다." >&2
    exit 0
fi

# Does the login item actually start the app? Nothing short of trying tells us.
login_item_works() {
    "$ROOT_DIR/scripts/stop.sh"
    sleep 2
    launchctl kickstart -p "$LABEL" >/dev/null 2>&1 || true
    sleep 5
    pgrep -x NotchVeil >/dev/null
}

repaired=false
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo "로그인 항목 확인 ${attempt}/${MAX_ATTEMPTS} (${SETTLE_SECONDS}초 대기)..." >&2
    sleep "$SETTLE_SECONDS"
    "$DESTINATION/Contents/MacOS/NotchVeil" --register-login-item >/dev/null 2>&1 || true

    if login_item_works; then
        repaired=true
        break
    fi
done

open "$DESTINATION"

if [[ "$repaired" == true ]]; then
    echo "로그인 항목 정상 동작 확인." >&2
else
    echo "경고: 로그인 항목이 아직 동작하지 않습니다. 잠시 후 다시 실행하십시오:" >&2
    echo "      $DESTINATION/Contents/MacOS/NotchVeil --register-login-item" >&2
fi

echo "$DESTINATION"
