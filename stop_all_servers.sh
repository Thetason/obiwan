#!/bin/bash

# AI Vocal Training - 전체 서버 종료 스크립트

echo "🛑 AI Vocal Training 서버 종료"
echo "=================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# PID 파일 경로
PID_DIR="/tmp/vocal_trainer"

# 서버 종료 함수
stop_server() {
    local name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        PID=$(cat $pid_file)
        if kill -0 $PID 2>/dev/null; then
            kill $PID
            echo -e "${GREEN}✓ $name 서버 종료됨 (PID: $PID)${NC}"
            rm $pid_file
        else
            echo -e "${YELLOW}! $name 서버가 이미 종료됨${NC}"
            rm $pid_file
        fi
    else
        echo -e "${YELLOW}! $name 서버 PID 파일 없음${NC}"
    fi
}

# 각 서버 종료
stop_server "CREPE" "$PID_DIR/crepe.pid"
stop_server "SPICE" "$PID_DIR/spice.pid"
stop_server "Formant" "$PID_DIR/formant.pid"

# 프로세스 이름으로도 종료 (백업)
echo -e "${YELLOW}남은 프로세스 정리 중...${NC}"
pkill -f "crepe_server.py" 2>/dev/null
pkill -f "spice_server.py" 2>/dev/null
pkill -f "formant_server.py" 2>/dev/null

echo ""
echo "=================================="
echo -e "${GREEN}✅ 모든 서버가 종료되었습니다${NC}"
echo "==================================">