#!/bin/zsh
set -euo pipefail
if [[ "${1:-}" == --check-running ]]; then
    print -r -- probe >> "$INSTALLER_TEST_CASE_DIR/events"
    if [[ "$INSTALLER_TEST_SCENARIO" == delayed-launch ]]; then
        count=0
        if [[ -f "$INSTALLER_TEST_CASE_DIR/probes" ]]; then
            count=$(<"$INSTALLER_TEST_CASE_DIR/probes")
        fi
        count=$((count + 1))
        print -r -- "$count" > "$INSTALLER_TEST_CASE_DIR/probes"
        if (( count >= 8 )); then touch "$INSTALLER_TEST_CASE_DIR/running"; fi
    fi
    [[ -e "$INSTALLER_TEST_CASE_DIR/running" ]]
    exit $?
fi
[[ "${1:-}" == --register-login-item ]]
print -r -- register >> "$INSTALLER_TEST_CASE_DIR/events"
if [[ "$INSTALLER_TEST_SCENARIO" == exhausted \
    || ( "$INSTALLER_TEST_SCENARIO" == retry && ! -e "$INSTALLER_TEST_CASE_DIR/first-failure" ) ]]; then
    # Simulate unregister succeeding before register throws.
    rm -f "$INSTALLER_TEST_CASE_DIR/registered"
    touch "$INSTALLER_TEST_CASE_DIR/first-failure"
    exit 1
fi
touch "$INSTALLER_TEST_CASE_DIR/registered"
