#!/bin/bash

# AI Vocal Training - 전체 서버 시작 스크립트
# CREPE, SPICE, Formant 서버 모두 실행

echo "🎵 AI Vocal Training 서버 시작"
echo "=================================="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 서버 디렉토리
SERVER_DIR="/Users/seoyeongbin/vocal_trainer_ai"

# PID 파일 경로
PID_DIR="/tmp/vocal_trainer"
mkdir -p $PID_DIR

# 기존 서버 종료
echo -e "${YELLOW}기존 서버 종료 중...${NC}"
pkill -f "crepe_server.py" 2>/dev/null
pkill -f "spice_server.py" 2>/dev/null
pkill -f "formant_server.py" 2>/dev/null
sleep 2

# CREPE 서버 시작 (포트 5002)
echo -e "${BLUE}[1/3] CREPE 서버 시작 (포트 5002)...${NC}"
cd $SERVER_DIR
python3 crepe_server.py > /tmp/crepe_server.log 2>&1 &
CREPE_PID=$!
echo $CREPE_PID > $PID_DIR/crepe.pid
echo -e "${GREEN}✓ CREPE 서버 시작됨 (PID: $CREPE_PID)${NC}"

# SPICE 서버 시작 (포트 5003)
echo -e "${BLUE}[2/3] SPICE 서버 시작 (포트 5003)...${NC}"
python3 spice_server.py > /tmp/spice_server.log 2>&1 &
SPICE_PID=$!
echo $SPICE_PID > $PID_DIR/spice.pid
echo -e "${GREEN}✓ SPICE 서버 시작됨 (PID: $SPICE_PID)${NC}"

# Formant 서버 시작 (포트 5004)
echo -e "${PURPLE}[3/3] Formant 서버 시작 (포트 5004)...${NC}"
python3 formant_server.py > /tmp/formant_server.log 2>&1 &
FORMANT_PID=$!
echo $FORMANT_PID > $PID_DIR/formant.pid
echo -e "${GREEN}✓ Formant 서버 시작됨 (PID: $FORMANT_PID)${NC}"

# 서버 상태 확인
sleep 3
echo ""
echo -e "${YELLOW}서버 상태 확인 중...${NC}"

# CREPE 상태
if curl -s http://localhost:5002/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ CREPE 서버: 정상 작동${NC}"
else
    echo -e "${RED}✗ CREPE 서버: 응답 없음${NC}"
fi

# SPICE 상태
if curl -s http://localhost:5003/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SPICE 서버: 정상 작동${NC}"
else
    echo -e "${RED}✗ SPICE 서버: 응답 없음${NC}"
fi

# Formant 상태
if curl -s http://localhost:5004/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Formant 서버: 정상 작동${NC}"
else
    echo -e "${RED}✗ Formant 서버: 응답 없음${NC}"
fi

echo ""
echo "=================================="
echo -e "${GREEN}🚀 모든 서버가 시작되었습니다!${NC}"
echo ""
echo "서버 엔드포인트:"
echo "  • CREPE:   http://localhost:5002"
echo "  • SPICE:   http://localhost:5003"
echo "  • Formant: http://localhost:5004"
echo ""
echo "로그 파일:"
echo "  • CREPE:   /tmp/crepe_server.log"
echo "  • SPICE:   /tmp/spice_server.log"
echo "  • Formant: /tmp/formant_server.log"
echo ""
echo "서버 종료: ./stop_all_servers.sh"
echo "=================================="