#!/bin/zsh
set -euo pipefail

INSTALLER_TEST_SOURCE="${0:A:h:h:h}"
test_root=$(/usr/bin/mktemp -d /private/tmp/notchveil-installer-tests.XXXXXX)
original_path="$PATH"
trap '[[ "$test_root" == /private/tmp/notchveil-installer-tests.* ]] && /bin/rm -rf "$test_root"' EXIT
export INSTALLER_TEST_SOURCE

new_case() {
    export INSTALLER_TEST_CASE_DIR="$test_root/$1"
    export INSTALLER_TEST_SCENARIO="${2:-disabled}"
    export SETTLE_SECONDS=0 MAX_ATTEMPTS=2
    mkdir -p "$INSTALLER_TEST_CASE_DIR"/{bin,project/scripts,destination}
    cp "$INSTALLER_TEST_SOURCE/scripts/install.sh" "$INSTALLER_TEST_CASE_DIR/project/scripts/install.sh"
    cp "$INSTALLER_TEST_SOURCE/Tests/InstallerTests/fixtures/"{build-app,stop}.sh \
        "$INSTALLER_TEST_CASE_DIR/project/scripts/"
    chmod +x "$INSTALLER_TEST_CASE_DIR/project/scripts/"*.sh
    for command_name in launchctl pgrep open sleep ditto mv mktemp rm; do
        cp "$INSTALLER_TEST_SOURCE/Tests/InstallerTests/fixtures/command.sh" \
            "$INSTALLER_TEST_CASE_DIR/bin/$command_name"
        chmod +x "$INSTALLER_TEST_CASE_DIR/bin/$command_name"
    done
    export PATH="$INSTALLER_TEST_CASE_DIR/bin:$original_path"
    destination="$INSTALLER_TEST_CASE_DIR/destination/NotchVeil.app"
}

old_app() {
    mkdir -p "$destination/Contents"
    cp "$INSTALLER_TEST_SOURCE/Resources/Info.plist" "$destination/Contents/Info.plist"
    touch "$destination/old-version"
}

run_install() {
    install_exit=0
    /bin/zsh "$INSTALLER_TEST_CASE_DIR/project/scripts/install.sh" "$@" \
        > "$INSTALLER_TEST_CASE_DIR/stdout" 2> "$INSTALLER_TEST_CASE_DIR/stderr" || install_exit=$?
}

check() {
    if ! "$@"; then
        print -u2 -- "FAIL: ${INSTALLER_TEST_CASE_DIR:t}: $*"
        /bin/cat "$INSTALLER_TEST_CASE_DIR/stderr"
        exit 1
    fi
}

register_count() {
    /usr/bin/awk '$0 == "register" { n++ } END { print n+0 }' "$INSTALLER_TEST_CASE_DIR/events"
}

new_case parent-path
touch "$INSTALLER_TEST_CASE_DIR/destination/keep"
run_install "$INSTALLER_TEST_CASE_DIR/destination"
check test "$install_exit" -eq 2
check test -f "$INSTALLER_TEST_CASE_DIR/destination/keep"
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case root-path
run_install /
check test "$install_exit" -eq 2
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case source-path
run_install "$INSTALLER_TEST_CASE_DIR/project/dist/NotchVeil.app"
check test "$install_exit" -eq 2
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case symlink
old_app
ln -s "$destination" "$INSTALLER_TEST_CASE_DIR/NotchVeil.app"
run_install "$INSTALLER_TEST_CASE_DIR/NotchVeil.app"
check test "$install_exit" -eq 2
check test -f "$destination/old-version"
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case unrelated-folder
mkdir "$destination"
touch "$destination/keep"
run_install "$destination"
check test "$install_exit" -eq 2
check test -f "$destination/keep"
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case invalid-attempts
export MAX_ATTEMPTS=0
run_install "$destination"
check test "$install_exit" -eq 2
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case extra-arguments
run_install "$destination" ignored
check test "$install_exit" -eq 2
check test ! -e "$INSTALLER_TEST_CASE_DIR/events"

new_case disabled
run_install "$destination"
check test "$install_exit" -eq 0
check test -x "$destination/Contents/MacOS/NotchVeil"
check test "$(register_count)" -eq 0
check test ! -e "$INSTALLER_TEST_CASE_DIR/registered"

new_case retry retry
touch "$INSTALLER_TEST_CASE_DIR/registered"
run_install "$destination"
check test "$install_exit" -eq 0
check test "$(register_count)" -eq 2
check test -f "$INSTALLER_TEST_CASE_DIR/running"

new_case exhausted exhausted
touch "$INSTALLER_TEST_CASE_DIR/registered"
run_install "$destination"
check test "$install_exit" -eq 1
check test "$(register_count)" -eq 2
check test -x "$destination/Contents/MacOS/NotchVeil"

new_case backup
old_app
run_install "$destination"
check test "$install_exit" -eq 0
check test ! -e "$destination/old-version"
backups=("$INSTALLER_TEST_CASE_DIR/destination"/.notchveil-install.*/previous-app/old-version(N))
check test "${#backups}" -eq 1

new_case copy-failure copy-failure
old_app
run_install "$destination"
check test "$install_exit" -eq 1
check test -f "$destination/old-version"
check test "$(/usr/bin/awk '$0 == "stop" { n++ } END { print n+0 }' "$INSTALLER_TEST_CASE_DIR/events")" -eq 0

new_case swap-failure swap-failure
old_app
run_install "$destination"
check test "$install_exit" -eq 1
check test -f "$destination/old-version"

new_case open-retry open-retry
run_install "$destination"
check test "$install_exit" -eq 0
check test -f "$INSTALLER_TEST_CASE_DIR/open-failed"

new_case open-failure open-failure
run_install "$destination"
check test "$install_exit" -eq 1
check test -x "$destination/Contents/MacOS/NotchVeil"

new_case delayed-launch delayed-launch
touch "$INSTALLER_TEST_CASE_DIR/registered"
run_install "$destination"
check test "$install_exit" -eq 0
check test "$(register_count)" -eq 1
check test "$(<"$INSTALLER_TEST_CASE_DIR/probes")" -eq 8

new_case unrelated-process unrelated-process
touch "$INSTALLER_TEST_CASE_DIR/registered"
run_install "$destination"
check test "$install_exit" -eq 1
check test "$(register_count)" -eq 2

new_case failed-job-live-app failed-job-live-app
touch "$INSTALLER_TEST_CASE_DIR/registered"
run_install "$destination"
check test "$install_exit" -eq 1
check test "$(register_count)" -eq 2

print -- "Installer integration tests passed (18 scenarios)."
