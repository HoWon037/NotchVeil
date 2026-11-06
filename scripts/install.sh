#!/bin/zsh
set -euo pipefail

# Build, back up and replace the app, then verify an existing login item.
# Ad-hoc signing limitations are documented in docs/development.md.

ROOT_DIR="${0:A:h:h}"
DESTINATION="${1:-/Applications/NotchVeil.app}"
LABEL="gui/$(id -u)/com.limdy.NotchVeil.LoginLauncher"
SETTLE_SECONDS="${SETTLE_SECONDS:-75}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"

# Validate before building or stopping the running app. Only a complete app
# destination is accepted, never a parent folder or an unrelated bundle.
if (( $# > 1 )); then
    echo "Usage: $0 [full/path/to/NotchVeil.app]" >&2
    exit 2
fi

DESTINATION="${DESTINATION:a}"
if [[ -L "$DESTINATION" ]]; then
    echo "error: destination must not be a symbolic link: $DESTINATION" >&2
    exit 2
fi
DESTINATION="${DESTINATION:A}"
SOURCE_APP="${ROOT_DIR:A}/dist/NotchVeil.app"

if [[ "${DESTINATION:t}" != "NotchVeil.app" \
    || "$DESTINATION" == "$SOURCE_APP" \
    || "$ROOT_DIR" == "$DESTINATION" \
    || "$ROOT_DIR" == "$DESTINATION/"* ]]; then
    echo "error: provide a safe, full NotchVeil.app path: $DESTINATION" >&2
    exit 2
fi

DESTINATION_PARENT="${DESTINATION:h}"
if [[ ! -d "$DESTINATION_PARENT" || ! -w "$DESTINATION_PARENT" ]]; then
    echo "error: destination parent must exist and be writable: $DESTINATION_PARENT" >&2
    exit 2
fi

if [[ -e "$DESTINATION" ]]; then
    existing_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
        "$DESTINATION/Contents/Info.plist" 2>/dev/null) || existing_identifier=""
    if [[ ! -d "$DESTINATION" || "$existing_identifier" != "com.limdy.NotchVeil" ]]; then
        echo "error: existing destination is not a NotchVeil bundle: $DESTINATION" >&2
        exit 2
    fi
fi

if [[ "$SETTLE_SECONDS" != <0-> || "$MAX_ATTEMPTS" != <1-> ]]; then
    echo "error: SETTLE_SECONDS must be a nonnegative integer; MAX_ATTEMPTS must be a positive integer." >&2
    exit 2
fi

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

# Keep the original intent throughout retries, even if unregister succeeds but
# the next register fails and the launchd job temporarily disappears.
login_item_was_registered=false
if launchctl print "$LABEL" >/dev/null 2>&1; then
    login_item_was_registered=true
fi

# Stage on the same volume before stopping the app. Keep the previous bundle as
# a recoverable backup rather than recursively deleting the supplied path.
STAGING_DIR=$(mktemp -d "$DESTINATION_PARENT/.notchveil-install.XXXXXX")
STAGED_APP="$STAGING_DIR/NotchVeil.app"
BACKUP_APP="$STAGING_DIR/previous-app"
if ! ditto "$SOURCE_APP" "$STAGED_APP"; then
    echo "error: staging failed; the existing app is unchanged. Staging directory: $STAGING_DIR" >&2
    exit 1
fi

"$ROOT_DIR/scripts/stop.sh"

if [[ -e "$DESTINATION" ]]; then
    mv "$DESTINATION" "$BACKUP_APP"
fi
if ! mv "$STAGED_APP" "$DESTINATION"; then
    if [[ -d "$BACKUP_APP" ]]; then
        mv "$BACKUP_APP" "$DESTINATION" \
            || echo "error: rollback failed. Previous app is preserved at: $BACKUP_APP" >&2
    fi
    echo "error: app replacement failed. Staging directory: $STAGING_DIR" >&2
    exit 1
fi

if [[ -d "$BACKUP_APP" ]]; then
    echo "Previous app backup: $BACKUP_APP" >&2
else
    rmdir "$STAGING_DIR"
fi
# LaunchServices may still see the old process while it is terminating.
open_installed_app() {
    for launch_attempt in {1..5}; do
        if open "$DESTINATION"; then return 0; fi
        sleep 1
    done
    return 1
}
open_installed_app

if [[ "$login_item_was_registered" == false ]]; then
    echo "$DESTINATION"
    echo "Launch at login was off; skipping login-item repair." >&2
    exit 0
fi

# Does the login item actually start the app? Nothing short of trying tells us.
login_item_works() {
    local job_exit
    "$ROOT_DIR/scripts/stop.sh"
    sleep 2
    launchctl kickstart -p "$LABEL" >/dev/null 2>&1 || return 1
    # The launcher itself may retry for 45 seconds. Wait for this exact app,
    # including completion of launch, before declaring a failed registration.
    for readiness_attempt in {1..50}; do
        if "$DESTINATION/Contents/MacOS/NotchVeil" --check-running; then
            job_exit=$(launchctl print "$LABEL" 2>/dev/null | awk '/last exit code =/ {print $5; exit}')
            if [[ "$job_exit" == 0 ]]; then return 0; fi
        fi
        sleep 1
    done
    return 1
}

repaired=false
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo "Checking login item ${attempt}/${MAX_ATTEMPTS} (waiting ${SETTLE_SECONDS}s)..." >&2
    sleep "$SETTLE_SECONDS"
    "$DESTINATION/Contents/MacOS/NotchVeil" --register-login-item >/dev/null 2>&1 || true

    if login_item_works; then
        repaired=true
        break
    fi
done

open_installed_app

if [[ "$repaired" == true ]]; then
    echo "Login-item launch verified." >&2
else
    echo "warning: login-item verification failed. Wait and retry:" >&2
    echo "      $DESTINATION/Contents/MacOS/NotchVeil --register-login-item" >&2
    echo "$DESTINATION"
    exit 1
fi

echo "$DESTINATION"
