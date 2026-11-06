#!/bin/zsh
set -euo pipefail
command_name="${0:t}"
print -r -- "$command_name $*" >> "$INSTALLER_TEST_CASE_DIR/events"

# Even a regression must not mutate anything outside this test's sandbox.
check_path() {
    [[ "${1:A}" == "$INSTALLER_TEST_CASE_DIR/"* ]] || exit 64
}

case "$command_name" in
    launchctl)
        [[ -e "$INSTALLER_TEST_CASE_DIR/registered" ]] || exit 1
        if [[ "$1" == kickstart ]]; then
            if [[ "$INSTALLER_TEST_SCENARIO" != delayed-launch && "$INSTALLER_TEST_SCENARIO" != unrelated-process ]]; then
                touch "$INSTALLER_TEST_CASE_DIR/running"
            fi
        elif [[ "$INSTALLER_TEST_SCENARIO" == failed-job-live-app ]]; then
            print -- 'last exit code = 78: EX_CONFIG'
        elif [[ -e "$INSTALLER_TEST_CASE_DIR/running" ]]; then
            print -- 'last exit code = 0'
        fi
        ;;
    pgrep)
        [[ -e "$INSTALLER_TEST_CASE_DIR/running" ]]
        ;;
    open)
        if [[ "$INSTALLER_TEST_SCENARIO" == open-failure ]]; then exit 1; fi
        if [[ "$INSTALLER_TEST_SCENARIO" == open-retry && ! -e "$INSTALLER_TEST_CASE_DIR/open-failed" ]]; then
            touch "$INSTALLER_TEST_CASE_DIR/open-failed"
            exit 1
        fi
        ;;
    sleep)
        ;;
    ditto)
        check_path "$1"
        check_path "$2"
        [[ "$INSTALLER_TEST_SCENARIO" != copy-failure ]] || exit 1
        /usr/bin/ditto "$@"
        ;;
    mv)
        check_path "$1"
        check_path "$2"
        if [[ "$INSTALLER_TEST_SCENARIO" == swap-failure \
            && "$1" == */.notchveil-install.*/NotchVeil.app ]]; then
            exit 1
        fi
        /bin/mv "$@"
        ;;
    mktemp)
        check_path "$2"
        /usr/bin/mktemp "$@"
        ;;
    rm)
        for argument in "$@"; do
            [[ "$argument" == -* ]] || check_path "$argument"
        done
        /bin/rm "$@"
        ;;
    *)
        exit 64
        ;;
esac
