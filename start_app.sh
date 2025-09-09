#!/bin/bash

# 오비완 v3 앱 실행 스크립트
echo "🎤 오비완 v3 앱을 시작합니다..."
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Flutter 앱 실행
flutter run -d macos

# 종료 시 메시지
echo "================================"
echo "👋 오비완 v3 앱이 종료되었습니다."
