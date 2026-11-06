#!/bin/zsh
set -euo pipefail

case "${0:t}" in
    swift)
        [[ "$BUILD_TEST_SCENARIO" != compile-failure ]] || exit 1
        mkdir -p .build/release
        touch .build/release/{NotchVeil,NotchVeilLoginLauncher}
        ;;
    xcrun)
        [[ "$*" == '--sdk macosx --show-sdk-version' ]] || exit 64
        print -- '25.0'
        ;;
    codesign)
        if [[ "$BUILD_TEST_SCENARIO" == signing-failure && " $* " == *' --sign '* ]]; then
            exit 1
        fi
        ;;
    mv)
        # Restrict even the real move to this isolated test directory.
        for argument in "$@"; do
            [[ "${argument:A}" == "$BUILD_TEST_ROOT/"* ]] || exit 64
        done
        if [[ ( "$BUILD_TEST_SCENARIO" == publish-failure || "$BUILD_TEST_SCENARIO" == rollback-failure ) \
            && "$1" == */.notchveil-build.*/NotchVeil.app ]]; then
            exit 1
        fi
        if [[ "$BUILD_TEST_SCENARIO" == rollback-failure && "$1" == */previous-app ]]; then
            exit 1
        fi
        /bin/mv "$@"
        ;;
    *) exit 64 ;;
esac
