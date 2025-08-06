#!/bin/bash

# 자동화된 오디오 녹음 테스트 스크립트

echo "🎯 자동 오디오 녹음 테스트 시작"

# Flutter 앱이 실행되었는지 확인
if pgrep -f "vocal_trainer_ai" > /dev/null; then
    echo "✅ Flutter 앱이 실행 중"
else
    echo "❌ Flutter 앱이 실행되지 않음"
    exit 1
fi

# 마이크 권한 확인
echo "🔐 마이크 권한 확인 중..."
system_profiler SPAudioDataType | grep -q "Built-in Microphone"
if [ $? -eq 0 ]; then
    echo "✅ 마이크 디바이스 감지됨"
else
    echo "⚠️ 마이크 디바이스를 찾을 수 없음"
fi

# 오디오 레벨 확인 (시스템 오디오 입력 확인)
echo "📊 시스템 오디오 입력 레벨 확인..."
osascript -e "get volume input" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ 시스템 오디오 입력 접근 가능"
else
    echo "⚠️ 시스템 오디오 입력 접근 제한"
fi

echo "📱 앱에서 녹음 테스트를 수동으로 진행하세요."
echo "   1. 파란색 버튼을 길게 눌러 녹음 시작"
echo "   2. 3-5초간 말하기"
echo "   3. 버튼에서 손 떼기"

# Flutter 앱 로그 모니터링
echo "📊 Flutter 앱 로그 모니터링 중..."
timeout 30 tail -f ~/Library/Logs/DiagnosticReports/vocal_trainer_ai_*.crash 2>/dev/null &

# macOS 콘솔 로그에서 오디오 관련 메시지 확인
echo "📊 시스템 오디오 로그 확인 중..."
timeout 10 log stream --predicate 'process == "vocal_trainer_ai"' --level info &

echo "🎯 테스트 완료"
echo "   - 녹음 시작 시 '[RealTime] 실시간 녹음 시작 성공!' 메시지 확인"
echo "   - 샘플 카운트가 증가하는지 확인"
echo "   - '[RealTime] 실제 녹음 데이터 반환' 메시지 확인"