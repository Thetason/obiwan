#!/bin/bash

echo "🎤 오비완 v2 - 빠른 복구 스크립트"
echo "================================"

# 현재 디렉토리 확인
if [ ! -f "CLAUDE_PROJECT_GUIDE.md" ]; then
    echo "❌ 잘못된 디렉토리입니다. 다음 명령어로 이동하세요:"
    echo "cd /Users/seoyeongbin/vocal_trainer_ai"
    exit 1
fi

echo "✅ 올바른 프로젝트 디렉토리입니다."
echo ""

# 기존 프로세스 정리
echo "🧹 기존 프로세스 정리 중..."
pkill -f crepe_server 2>/dev/null
pkill -f spice_server 2>/dev/null
pkill -f flutter 2>/dev/null
sleep 2

# 서버 상태 확인
echo "🔍 서버 상태 확인 중..."
if curl -s http://localhost:5002/health > /dev/null 2>&1; then
    echo "✅ CREPE 서버 이미 실행 중"
else
    echo "🚀 CREPE 서버 시작 필요"
fi

if curl -s http://localhost:5003/health > /dev/null 2>&1; then
    echo "✅ SPICE 서버 이미 실행 중"
else
    echo "🚀 SPICE 서버 시작 필요"
fi

echo ""
echo "🎯 다음 중 하나를 선택하세요:"
echo "1. 전자동 시작: ./전자동시작.sh"
echo "2. 서버만 시작: ./start_servers.sh"
echo "3. 앱만 시작: flutter run -d macos"
echo ""
echo "💡 추천: ./전자동시작.sh 를 실행하세요!"