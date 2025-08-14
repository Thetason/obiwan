#!/bin/bash

# 오비완 v3 - Vocal Trainer AI
# 더블클릭으로 실행 가능한 Command 파일

clear
echo "🎤 =============================== 🎤"
echo "     오비완 v3 - Vocal Trainer AI     "
echo "🎤 =============================== 🎤"
echo ""
echo "앱을 시작하는 중..."
echo ""

# 프로젝트 디렉토리로 이동
cd /Users/seoyeongbin/vocal_trainer_ai

# Flutter 앱 실행
flutter run -d macos

# 종료 대기
read -p "Press any key to exit..."