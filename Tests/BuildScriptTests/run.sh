#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h:h}"
test_root=$(/usr/bin/mktemp -d /private/tmp/notchveil-build-tests.XXXXXX)
trap '[[ "$test_root" == /private/tmp/notchveil-build-tests.* ]] && /bin/rm -rf "$test_root"' EXIT

# Rejected paths must fail before compilation and leave the linked target intact.
mkdir -p "$test_root/project/scripts" "$test_root/Xcode/Platforms/MacOSX.platform" "$test_root/keep"
cp "$PROJECT_ROOT/scripts/build-app.sh" "$test_root/project/scripts/build-app.sh"
touch "$test_root/keep/marker"
export DEVELOPER_DIR="$test_root/Xcode"

expect_rejection() {
    local result=0
    /bin/zsh "$test_root/project/scripts/build-app.sh" > "$test_root/output" 2>&1 || result=$?
    if [[ "$result" != 2 || ! -f "$test_root/keep/marker" ]]; then
        print -u2 -- "FAIL: build must reject redirected output without modifying it"
        /bin/cat "$test_root/output"
        exit 1
    fi
}

ln -s "$test_root/keep" "$test_root/project/dist"
expect_rejection
/bin/rm "$test_root/project/dist"
mkdir "$test_root/project/dist"
ln -s "$test_root/keep" "$test_root/project/dist/NotchVeil.app"
expect_rejection
/bin/rm "$test_root/project/dist/NotchVeil.app"
ln -s "$test_root/nonexistent" "$test_root/project/dist/NotchVeil.app"
expect_rejection
/bin/rm "$test_root/project/dist/NotchVeil.app"

# Failure injection uses dummy binaries and signing commands, never the system
# compiler or a signing identity. Real compilation/signing is covered by CI.
mkdir -p "$test_root/bin" "$test_root/project/Resources"
for command_name in swift xcrun codesign mv; do
    cp "$PROJECT_ROOT/Tests/BuildScriptTests/fixtures/command.sh" "$test_root/bin/$command_name"
    chmod +x "$test_root/bin/$command_name"
done
cp "$PROJECT_ROOT/Resources/Info.plist" "$test_root/project/Resources/Info.plist"
cp "$PROJECT_ROOT/Resources/LoginLauncher-Info.plist" "$test_root/project/Resources/LoginLauncher-Info.plist"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$test_root/project/Resources/AppIcon.icns"
cp "$PROJECT_ROOT/Resources/AppIcon-1024.png" "$test_root/project/Resources/AppIcon-1024.png"
export PATH="$test_root/bin:$PATH"
export BUILD_TEST_ROOT="$test_root"

for BUILD_TEST_SCENARIO in compile-failure resource-failure signing-failure publish-failure success rollback-failure; do
    export BUILD_TEST_SCENARIO
    mkdir -p "$test_root/project/dist/NotchVeil.app"
    touch "$test_root/project/dist/NotchVeil.app/previous-build"
    if [[ "$BUILD_TEST_SCENARIO" == resource-failure ]]; then
        /bin/mv "$test_root/project/Resources/Info.plist" "$test_root/Info.plist"
    fi
    result=0
    /bin/zsh "$test_root/project/scripts/build-app.sh" > "$test_root/output" 2>&1 || result=$?
    if [[ "$BUILD_TEST_SCENARIO" == resource-failure ]]; then
        /bin/mv "$test_root/Info.plist" "$test_root/project/Resources/Info.plist"
    fi
    if [[ "$BUILD_TEST_SCENARIO" == rollback-failure ]]; then
        backups=("$test_root/project/dist"/.notchveil-build.*/previous-app/previous-build(N))
        if [[ "$result" == 0 || ${#backups} != 1 ]]; then
            print -u2 -- "FAIL: failed rollback must retain the previous build as a recoverable backup"
            /bin/cat "$test_root/output"
            exit 1
        fi
        continue
    elif [[ "$BUILD_TEST_SCENARIO" == success ]]; then
        [[ "$result" == 0 && ! -e "$test_root/project/dist/NotchVeil.app/previous-build" ]] \
            && [[ -x "$test_root/project/dist/NotchVeil.app/Contents/MacOS/NotchVeil" ]] || {
                /bin/cat "$test_root/output"
                exit 1
            }
    elif [[ "$result" == 0 || ! -f "$test_root/project/dist/NotchVeil.app/previous-build" ]]; then
        print -u2 -- "FAIL: $BUILD_TEST_SCENARIO must preserve the previous build"
        /bin/cat "$test_root/output"
        exit 1
    fi
    staging=("$test_root/project/dist"/.notchveil-build.*(N))
    if (( ${#staging} != 0 )); then
        print -u2 -- "FAIL: $BUILD_TEST_SCENARIO left staging output behind"
        exit 1
    fi
done

print -- "Build output safety tests passed (9 scenarios)."
