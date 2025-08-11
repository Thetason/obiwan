# 오비완 v3 프로젝트 상태 문서
**작성일**: 2025-08-11  
**작성자**: Claude  
**목적**: 새 세션 시작 시 프로젝트 상태 복원용

---

## 🚨 현재 상태 요약
- **앱 상태**: 기능 작동하나 중간에 크래시 발생
- **최근 작업**: 실제 음성 분석 UI 연결 완료
- **주요 이슈**: 메모리 관리 문제로 앱이 갑자기 종료됨

---

## 📊 프로젝트 개요
**프로젝트명**: 오비완 v3 - AI 보컬 트레이닝 앱  
**기술 스택**: Flutter + Swift(macOS) + CREPE/SPICE AI  
**핵심 목표**: 실시간 음성 분석 및 시각적 피드백

---

## ✅ 완료된 작업 (2025-08-06 ~ 2025-08-11)

### 1. 오디오 시스템 구축
```swift
// MainFlutterWindow.swift
class RealTimeAudioRecorder {
  private var audioEngine: AVAudioEngine?
  private var recordedSamples: [Float] = []
  
  // ✅ AVAudioEngine 크래시 해결 (error -10879)
  // ✅ 48kHz 실시간 녹음
  // ✅ Swift-Flutter 브리지 구현
}
```

**핵심 수정사항**:
- `stopRecording()`에서 `setupAudioEngine()` 호출 제거
- 녹음 데이터 보존을 위해 엔진 재초기화 지연

### 2. AI 엔진 통합
```dart
// dual_engine_service.dart
class DualEngineService {
  // ✅ CREPE 서버 (Port 5002) - CNN 기반 피치 분석
  // ✅ SPICE 서버 (Port 5003) - 구글 다중 피치 분석
  // ✅ Base64 인코딩으로 JSON 에러 해결
  
  Future<List<DualResult>> analyzeTimeBasedPitch(Float32List audioData) async {
    // windowSize: 4096, hopSize: 2048
    // 시간별 피치 분석 결과 반환
  }
}
```

### 3. UI/UX 구현
```dart
// recording_flow_modal.dart
class RecordingFlowModal extends StatefulWidget {
  // 4단계 플로우:
  // 1. 녹음 → 실시간 웨이브폼
  // 2. 재생 확인 → 파형 시각화  
  // 3. 실시간 분석 → 피치 그래프 + 시각적 피드백
  // 4. 결과 → 등급 (A+/A/B/C) + 통계
}
```

### 4. 실제 음성 분석 구현 (2025-08-11)
```dart
// ❌ 제거된 더미 데이터
// _realtimeWaveform.add(math.Random().nextDouble() * 0.8 + 0.1);

// ✅ 실제 데이터 사용
_audioService.getCurrentAudioLevel().then((level) {
  if (mounted) {
    _realtimeWaveform.add(level);
  }
});

// ✅ 실시간 피치 업데이트 (50ms마다)
_waveformTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
  if (_pitchData.isNotEmpty && _currentPitchIndex < _pitchData.length) {
    setState(() {
      _currentFrequency = _pitchData[_currentPitchIndex].frequency;
      _currentConfidence = _pitchData[_currentPitchIndex].confidence;
    });
    _currentPitchIndex++;
  }
});
```

---

## 🐛 해결된 이슈들

### 1. AVAudioEngine 크래시
- **문제**: error -10879 발생
- **원인**: 엔진 재초기화 시 탭 중복
- **해결**: 
  ```swift
  // stopRecording에서 setupAudioEngine() 호출 제거
  // 재생 시작 시에만 필요하면 초기화
  ```

### 2. 더미 데이터 사용
- **문제**: Random() 사용으로 가짜 데이터 표시
- **원인**: 개발 원칙 위반 (NO DUMMY DATA)
- **해결**: 모든 Random() 제거, 실제 녹음 데이터만 사용

### 3. UI 피드백 없음
- **문제**: 분석 결과가 UI에 표시 안 됨
- **원인**: 데이터 플로우 단절
- **해결**: 
  ```dart
  // 실시간 업데이트 추가
  _currentFrequency = currentPitch.frequency;
  _currentConfidence = currentPitch.confidence;
  ```

---

## ⚠️ 현재 문제점

### 1. 앱 크래시
- **증상**: 녹음/분석 중 갑자기 종료
- **예상 원인**: 
  - 메모리 누수
  - Timer 정리 안 됨
  - 대용량 오디오 데이터 처리
- **필요 조치**:
  ```dart
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _waveformTimer?.cancel();
    _recordedAudioData?.clear();  // 메모리 해제
    _pitchData.clear();
    super.dispose();
  }
  ```

### 2. setState after dispose
- **에러 로그**: 
  ```
  setState() called after dispose(): _RecordingFlowModalState
  ```
- **원인**: Timer가 위젯 dispose 후에도 실행
- **해결 필요**:
  ```dart
  if (!mounted) return;  // 모든 setState 전에 체크
  ```

---

## 📁 핵심 파일 위치

### Flutter (Dart)
- `/lib/widgets/recording_flow_modal.dart` - 메인 녹음 플로우
- `/lib/widgets/realtime_visual_feedback.dart` - 시각적 피드백
- `/lib/widgets/realtime_pitch_graph.dart` - 피치 그래프
- `/lib/services/native_audio_service.dart` - 네이티브 브리지
- `/lib/services/dual_engine_service.dart` - AI 엔진 서비스

### Swift (macOS)
- `/macos/Runner/MainFlutterWindow.swift` - 오디오 녹음/재생
- `/macos/Runner/AppDelegate.swift` - 앱 델리게이트

### Python (AI 서버)
- `/Users/seoyeongbin/crepe_setup/crepe_server_optimized.py` - CREPE 서버 (Port 5002)
- `/Users/seoyeongbin/crepe_setup/spice_server.py` - SPICE 서버 (Port 5003)

---

## 🚀 다음 세션 시작 방법

### 1. 프로젝트 디렉토리 이동
```bash
cd /Users/seoyeongbin/vocal_trainer_ai
```

### 2. 이 문서 읽기
```bash
cat CLAUDE_PROJECT_STATE_2025_08_11.md
```

### 3. CREPE/SPICE 서버 확인
```bash
ps aux | grep -E "(crepe|spice|5002|5003)" | grep -v grep
```

### 4. 서버 실행 (필요시)
```bash
# CREPE 서버
cd /Users/seoyeongbin/crepe_setup
source crepe_env/bin/activate
python crepe_server_optimized.py &

# SPICE 서버  
python spice_server.py &
```

### 5. Flutter 앱 실행
```bash
flutter run -d macos
```

---

## 📝 개발 원칙 (필수 준수)

### DEVELOPMENT_PRINCIPLES.md 핵심
1. **NO DUMMY DATA** - 절대 가짜 데이터 사용 금지
2. **Real Implementation Only** - 실제 기능만 구현
3. **User-Driven Workflow** - 사용자가 플로우 제어
4. **Clean Code** - SOLID 원칙 준수
5. **Refactoring** - 항상 코드를 깨끗하게

---

## 🔧 긴급 수정 필요 사항

### 1. 메모리 관리
```dart
// recording_flow_modal.dart dispose() 메서드 개선
@override
void dispose() {
  // 모든 Timer 취소
  _recordingTimer?.cancel();
  _waveformTimer?.cancel();
  
  // AnimationController dispose
  _recordingPulseController.dispose();
  _waveformController.dispose();
  
  // 대용량 데이터 정리
  _recordedAudioData = null;
  _pitchData.clear();
  _realtimeWaveform.clear();
  
  // 서비스 정리
  if (_isRecording) {
    _audioService.stopRecording();
  }
  
  super.dispose();
}
```

### 2. mounted 체크 추가
```dart
// 모든 비동기 콜백에서
Timer.periodic(duration, (timer) {
  if (!mounted) {
    timer.cancel();
    return;
  }
  // setState 등 UI 업데이트
});
```

### 3. 에러 핸들링
```dart
try {
  final audioData = await _audioService.getRecordedAudioData();
  if (audioData == null || audioData.isEmpty) {
    // 에러 처리
    return;
  }
  // 정상 처리
} catch (e) {
  print('오디오 분석 실패: $e');
  // 사용자에게 에러 표시
}
```

---

## 📊 테스트 결과

### 성공한 테스트
- ✅ 758,400 샘플 (15.8초) 녹음 성공
- ✅ CREPE 분석: 94개 피치 포인트 생성
- ✅ 신뢰도: 76~90% 
- ✅ 실시간 UI 업데이트 작동

### 실패한 테스트  
- ❌ 장시간 녹음 시 크래시
- ❌ 모달 닫기 후 setState 에러
- ❌ 메모리 사용량 지속 증가

---

## 💡 사용자 피드백
- "녹음, 재생, 분석 UI까지 다 돼"
- "중간에 하다가 꺼졌다"
- "새로운 UI 좋긴 한데!"
- "재생은 돼. 그런데 여전히 내가 낸 소리에 대한 시각적 가이드가 없어"

---

## 🎯 우선순위 작업 목록

### 긴급 (P0)
1. 메모리 누수 해결
2. Timer dispose 처리
3. mounted 체크 추가

### 중요 (P1)
1. 에러 핸들링 강화
2. 사용자 피드백 메시지
3. 크래시 리포팅

### 개선 (P2)
1. 코드 리팩토링 (SOLID 원칙)
2. 테스트 코드 작성
3. 성능 최적화

---

## 📌 중요 메모

### 작동하는 것
- 실제 음성 녹음 (Swift AVAudioEngine)
- CREPE/SPICE AI 분석
- 실시간 피치 표시
- 4단계 플로우 UI

### 작동 안 하는 것
- 장시간 사용 시 안정성
- 메모리 관리
- 에러 복구

---

**이 문서를 새 Claude 세션에 보여주면 프로젝트를 즉시 이어서 작업할 수 있습니다.**

마지막 수정: 2025-08-11 01:20 AM