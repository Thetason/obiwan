#!/bin/bash

echo "🚀 오비완 v2 전자동 시작!"
echo "========================"

# 모든 관련 프로세스 정리
echo "🧹 기존 프로세스 정리 중..."
pkill -f "flutter run" 2>/dev/null
pkill -f "official_crepe_server" 2>/dev/null  
pkill -f "spice_server" 2>/dev/null
sleep 2

# 서버들 백그라운드 시작
echo "🔧 서버들 시작 중..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
if [ -f "venv/bin/activate" ]; then
  source venv/bin/activate
fi

# CREPE 서버 시작
python3 crepe_server.py > /tmp/crepe.log 2>&1 &
echo "CREPE 서버 시작됨 (PID: $!)"

# SPICE 서버 시작  
python3 spice_server.py > /tmp/spice.log 2>&1 &
echo "SPICE 서버 시작됨 (PID: $!)"

# 서버 준비 대기
echo "⏳ 서버 준비 중... (5초)"
sleep 5

# Flutter 앱 시작
echo "🎵 Flutter 앱 시작 중..."
cd "$SCRIPT_DIR"

# 브라우저 자동 열기
echo "🌐 브라우저에서 자동으로 앱이 열립니다..."

# Flutter 실행 (localhost로 변경)
flutter run -d macos &

# 잠시 후 브라우저 열기 
sleep 3
# macOS 앱 실행이므로 브라우저 자동 열기 생략

echo ""
echo "✅ 완료! 브라우저에서 마이크 권한만 허용하세요!"
echo "❌ 종료하려면: Ctrl+C"
echo ""

# 로그 확인 옵션
echo "📋 서버 로그 확인:"
echo "   CREPE: tail -f /tmp/crepe.log"  
echo "   SPICE: tail -f /tmp/spice.log"

wait
