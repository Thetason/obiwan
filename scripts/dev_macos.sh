#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# SAFE_MODE=true for quick boot without heavy init; set SAFE_MODE=false for full path
SAFE_MODE=${SAFE_MODE:-true}

echo "[dev] Running macOS app (SAFE_MODE=$SAFE_MODE)"
flutter pub get
flutter run -d macos --dart-define=SAFE_MODE=$SAFE_MODE "$@"

