#!/bin/bash

echo "🔧 CREPE + SPICE 서버 시작 스크립트"
echo "===================================="

# 스크립트 디렉토리로 이동
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 선택적: 로컬 가상환경 있으면 활성화
if [ -f "venv/bin/activate" ]; then
  echo "🐍 Python 가상환경 활성화..."
  source venv/bin/activate
fi

# CREPE 서버 시작 확인
echo "📡 CREPE 서버 확인 중..."
if ! curl -s http://localhost:5002/health | grep -q '"status":"healthy"'; then
  echo "🚀 CREPE 서버 시작 중..."
  python3 crepe_server.py > /tmp/crepe_server.log 2>&1 &
  CREPE_PID=$!
  echo "CREPE PID: $CREPE_PID"
  sleep 3
else
  echo "✅ CREPE 서버 이미 실행 중"
fi

# SPICE 서버 시작 확인
echo "📡 SPICE 서버 확인 중..."
if ! curl -s http://localhost:5003/health | grep -q '"status":"healthy"'; then
  echo "🚀 SPICE 서버 시작 중..."
  python3 spice_server.py > /tmp/spice_server.log 2>&1 &
  SPICE_PID=$!
  echo "SPICE PID: $SPICE_PID"
  sleep 3
else
  echo "✅ SPICE 서버 이미 실행 중"
fi

# 서버 상태 최종 확인
echo ""
echo "🔍 서버 상태 최종 확인..."
sleep 2

if curl -s http://localhost:5002/health | grep -q '"status":"healthy"'; then
  echo "✅ CREPE 서버: http://localhost:5002 (정상)"
else
  echo "❌ CREPE 서버: 시작 실패"
fi

if curl -s http://localhost:5003/health | grep -q '"status":"healthy"'; then
  echo "✅ SPICE 서버: http://localhost:5003 (정상)"
else
  echo "❌ SPICE 서버: 시작 실패"
fi

echo ""
echo "🎯 이제 다른 터미널에서 Flutter 앱을 시작하세요:"
echo "cd \"$SCRIPT_DIR\" && ./start_app.sh"
