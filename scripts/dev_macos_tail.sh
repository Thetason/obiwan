#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SAFE_MODE=${SAFE_MODE:-true}
LOGFILE="$HOME/obiwan/.devlogs/latest.log"

echo "[dev] tailing $LOGFILE (created on first log write)"
( tail -n 100 -f "$LOGFILE" 2>/dev/null & )

flutter pub get
flutter run -d macos --dart-define=SAFE_MODE=$SAFE_MODE "$@"

