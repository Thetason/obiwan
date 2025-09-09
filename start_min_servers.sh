#!/bin/bash
set -e

echo "🎯 최소 서버 기동 (CREPE만)"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "venv310/bin/activate" ]; then
  echo "🐍 Using venv310 (Python 3.10)"
  source venv310/bin/activate
elif [ -f "venv311/bin/activate" ]; then
  echo "🐍 Using venv311 (Python 3.11)"
  source venv311/bin/activate
elif [ -f "venv/bin/activate" ]; then
  echo "🐍 Using venv (default)"
  source venv/bin/activate
fi

# 이미 떠 있으면 패스
if curl -s http://localhost:5002/health | grep -q '"status"'; then
  echo "✅ CREPE 서버 이미 실행 중"
  exit 0
fi

echo "🚀 CREPE 서버 시작..."
python3 crepe_server.py > /tmp/crepe_server.log 2>&1 &
CREPE_PID=$!
echo "PID: $CREPE_PID"

echo "⏳ 헬스체크 대기... (최대 120초)"
END=$((SECONDS+120))
until curl -s http://localhost:5002/health | grep -q '"status"'; do
  if [ $SECONDS -ge $END ]; then
    echo "❌ CREPE health timeout"
    echo "--- /tmp/crepe_server.log (tail) ---"
    tail -n 80 /tmp/crepe_server.log || true
    exit 1
  fi
  sleep 2
done
echo "✅ CREPE 서버 정상 응답"
