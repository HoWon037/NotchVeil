#!/bin/zsh
set -euo pipefail
pkill -u "$(id -u)" -x NotchVeil 2>/dev/null || true
