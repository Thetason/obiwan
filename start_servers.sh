#!/bin/bash

echo "🔧 CREPE + SPICE 서버 시작 스크립트"
echo "=" * 40

cd /Users/seoyeongbin/crepe_setup

# Python 가상환경 활성화
echo "🐍 Python 가상환경 활성화..."
source crepe_env/bin/activate

# CREPE 서버 시작 확인
echo "📡 CREPE 서버 확인 중..."
CREPE_RUNNING=$(curl -s http://localhost:5002/health 2>/dev/null | grep -o '"status":"healthy"' || echo "")
if [ -z "$CREPE_RUNNING" ]; then
    echo "🚀 CREPE 서버 시작 중..."
    python official_crepe_server.py > crepe_server.log 2>&1 &
    CREPE_PID=$!
    echo "CREPE PID: $CREPE_PID"
    sleep 5
else
    echo "✅ CREPE 서버 이미 실행 중"
fi

# SPICE 서버 시작 확인
echo "📡 SPICE 서버 확인 중..."
SPICE_RUNNING=$(curl -s http://localhost:5003/health 2>/dev/null | grep -o '"status":"healthy"' || echo "")
if [ -z "$SPICE_RUNNING" ]; then
    echo "🚀 SPICE 서버 시작 중..."
    python spice_server.py > spice_server.log 2>&1 &
    SPICE_PID=$!
    echo "SPICE PID: $SPICE_PID"
    sleep 5
else
    echo "✅ SPICE 서버 이미 실행 중"
fi

# 서버 상태 최종 확인
echo ""
echo "🔍 서버 상태 최종 확인..."
sleep 2

CREPE_FINAL=$(curl -s http://localhost:5002/health 2>/dev/null | grep -o '"status":"healthy"' || echo "")
SPICE_FINAL=$(curl -s http://localhost:5003/health 2>/dev/null | grep -o '"status":"healthy"' || echo "")

if [ -n "$CREPE_FINAL" ]; then
    echo "✅ CREPE 서버: http://localhost:5002 (정상)"
else
    echo "❌ CREPE 서버: 시작 실패"
fi

if [ -n "$SPICE_FINAL" ]; then
    echo "✅ SPICE 서버: http://localhost:5003 (정상)"
else
    echo "❌ SPICE 서버: 시작 실패"
fi

echo ""
echo "🎯 이제 다른 터미널에서 Flutter 앱을 시작하세요:"
echo "cd /Users/seoyeongbin/vocal_trainer_ai && ./start_app.sh"