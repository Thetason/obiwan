#!/bin/bash

echo "🔧 오비완 v3 오디오 디버깅 테스트 스크립트"
echo "=========================================="

# 1. macOS 권한 확인
echo ""
echo "1. macOS 마이크 권한 확인"
echo "------------------------"
tccutil list Microphone | grep vocal_trainer_ai || echo "⚠️ 마이크 권한이 설정되지 않았습니다."

# 2. 오디오 장치 확인
echo ""
echo "2. 시스템 오디오 장치 확인"
echo "-------------------------"
system_profiler SPAudioDataType | grep -A5 "Input"

# 3. 프로젝트 빌드 및 실행
echo ""
echo "3. Flutter 프로젝트 빌드 및 실행"
echo "------------------------------"
cd /Users/seoyeongbin/vocal_trainer_ai

# macOS 빌드
echo "🔨 macOS 빌드 시작..."
flutter build macos --debug

if [ $? -eq 0 ]; then
    echo "✅ 빌드 성공!"
    echo ""
    echo "4. 앱 실행 (디버그 모드)"
    echo "---------------------"
    echo "💡 앱이 실행되면 다음을 확인하세요:"
    echo "   - 콘솔에서 '[RealTime]' 태그 로그 확인"
    echo "   - 마이크 권한 요청 대화상자 허용"
    echo "   - 'TAP CALLBACK WORKING' 메시지 확인"
    echo ""
    
    # 앱 실행
    flutter run -d macos --debug
else
    echo "❌ 빌드 실패"
    echo "Error Log:"
    echo "----------"
fi