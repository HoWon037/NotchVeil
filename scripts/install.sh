#!/bin/zsh
set -euo pipefail

# Builds NotchVeil, installs it, and repairs the login item registration.
#
# launchd guards the login item with a code requirement pinned to the launcher's
# code identity, and replacing the app invalidates it silently. Restoring it
# needs both a settling delay and a registration issued from outside the running
# app, which is what the wait and the --register-login-item call below are for.
# See Sources/NotchVeil/LoginItemRegistration.swift.

ROOT_DIR="${0:A:h:h}"
DESTINATION="${1:-/Applications/NotchVeil.app}"
LABEL="gui/$(id -u)/com.limdy.NotchVeil.LoginLauncher"
SETTLE_SECONDS="${SETTLE_SECONDS:-90}"

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

echo "로그인 항목 재등록까지 ${SETTLE_SECONDS}초 대기 중..." >&2
sleep "$SETTLE_SECONDS"

"$DESTINATION/Contents/MacOS/NotchVeil" --register-login-item

if launchctl print "$LABEL" 2>&1 | grep -q 'needs LWCR update'; then
    echo "경고: 로그인 항목이 아직 갱신되지 않았습니다." >&2
    echo "      잠시 후 다시 실행하십시오:" >&2
    echo "      $DESTINATION/Contents/MacOS/NotchVeil --register-login-item" >&2
else
    echo "로그인 항목 재등록 완료." >&2
fi

echo "$DESTINATION"
