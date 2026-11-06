#!/bin/zsh
set -euo pipefail
print -r -- stop >> "$INSTALLER_TEST_CASE_DIR/events"
rm -f "$INSTALLER_TEST_CASE_DIR/running"
