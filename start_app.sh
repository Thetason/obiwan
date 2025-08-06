#!/bin/bash

echo "🎵 오비완 v2 - 듀얼 AI 보컬 트레이너 시작!"
echo "=" * 50

# CREPE 서버 상태 확인
echo "📡 CREPE 서버 상태 확인..."
CREPE_STATUS=$(curl -s http://localhost:5002/health | grep -o '"status":"healthy"' || echo "")
if [ -n "$CREPE_STATUS" ]; then
    echo "✅ CREPE 서버 정상 동작 중"
else
    echo "❌ CREPE 서버 오프라인 - 수동으로 시작하세요"
    echo "   cd /Users/seoyeongbin/crepe_setup && source crepe_env/bin/activate && python official_crepe_server.py"
fi

# SPICE 서버 상태 확인
echo "📡 SPICE 서버 상태 확인..."
SPICE_STATUS=$(curl -s http://localhost:5003/health | grep -o '"status":"healthy"' || echo "")
if [ -n "$SPICE_STATUS" ]; then
    echo "✅ SPICE 서버 정상 동작 중"
else
    echo "❌ SPICE 서버 오프라인 - 수동으로 시작하세요"
    echo "   cd /Users/seoyeongbin/crepe_setup && source crepe_env/bin/activate && python spice_server.py"
fi

# Flutter 앱 시작
echo ""
echo "🚀 Flutter 앱 시작 중..."
echo "브라우저에서 http://localhost:8081 으로 접속하세요"
echo ""
echo "중지하려면 Ctrl+C를 누르세요"
echo ""

# 기존 Flutter 프로세스 종료
pkill -f "flutter run" 2>/dev/null

# Flutter 앱 실행
flutter run -d chrome --web-port=8081 --web-hostname=localhost