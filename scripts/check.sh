#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"

for script in scripts/*.sh; do
    zsh -n "$script"
done
plutil -lint Resources/Info.plist Resources/LoginLauncher-Info.plist
xcrun swift-format lint --strict --recursive Sources Tests scripts/make-app-icon.swift
swift test
zsh Tests/InstallerTests/run.sh
zsh Tests/BuildScriptTests/run.sh
