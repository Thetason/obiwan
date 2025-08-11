# 오비완 v3 - 프로젝트 현황 및 맥락 저장
**작성일: 2025-08-08**
**프로젝트명: 오비완 v3 (Obi-wan v3)**

## 🎯 현재 작업 목표
**단일 음정을 정확히 감지하는 시스템 구축** - 사용자가 자유롭게 부르는 멜로디를 알고리즘이 자동으로 정확히 캐치

## 📌 핵심 개발 철학
- **사용자는 자유롭게 부르고, 알고리즘이 알아서 캐치해야 함**
- "내가 왜 정확하게 도레미파솔라시도를 불러줘야하냐??" - 사용자 피드백
- 1초씩 명확하게 부르는 것이 아니라 자유로운 멜로디를 시스템이 추적해야 함

## 🏗️ 시스템 아키텍처

### 1. SinglePitchTracker 시스템
**위치**: `/Users/seoyeongbin/vocal_trainer_ai/lib/services/single_pitch_tracker.dart`

**구성**:
- 3가지 피치 검출 방법 앙상블
  - CREPE (CNN 기반) - 현재 비활성화 (너무 느림)
  - YIN 알고리즘
  - Autocorrelation (자기상관)
- 중간값(median) 융합으로 안정성 확보
- 이동평균 필터로 노이즈 제거
- 음정 스냅 기능 (±50센트 이내)
- 완전한 주파수 테이블 (C0~C8)

### 2. 통합 구조
```
1단계: 녹음 (WaveStartScreen)
    ↓
2단계: 재생/분석 (AudioPlayerWidget)
    ↓ [SinglePitchTracker 통합 완료]
3단계: 결과 표시 (FixedVocalTrainingScreen)
```

### 3. 현재 구현 상태
- ✅ SinglePitchTracker 클래스 완성
- ✅ DualEngineService에 `analyzeSinglePitchAccurate()` 메서드 추가
- ✅ AudioPlayerWidget에서 SinglePitchTracker 사용하도록 변경
- ✅ 백그라운드 분석으로 2단계 정체 해결
- ❌ 실제 호출 확인 필요 (로그에 `🎯🎯🎯` 미출력)

## 🐛 발견된 문제들

### 1. CREPE 서버 성능 문제
**증상**:
- 단일 청크 분석에 수십 초 소요
- 1465.3Hz만 반복 감지 (무음/노이즈)
- 신뢰도 매우 낮음 (2-8%)

**원인**:
- Python/TensorFlow CPU 추론 느림
- M1/M2 Mac 최적화 안 됨
- 큰 CNN 모델 (20MB+)

**해결책**:
```dart
// CREPE 비활성화
Future<double> _detectWithCREPE(...) async {
  return 0; // YIN과 Autocorrelation만 사용
}
```

### 2. 2단계에서 3단계로 못 넘어가는 문제
**원인**: AI 분석 완료까지 대기

**해결책**: 백그라운드 분석
```dart
// 분석을 시작하되 await 하지 않음
_performTimeBasedAnalysis().then((_) {
  print('✅ 백그라운드 분석 완료');
});
// 1초 후 바로 다음 단계로 진행
await Future.delayed(const Duration(seconds: 1));
widget.onAnalyze?.call([]);
```

### 3. SinglePitchTracker 실제 호출 안 됨
**증상**: 로그에 `🎯 [SinglePitch]` 메시지 없음

**확인 필요**:
- `_performTimeBasedAnalysis()`에서 실제로 `analyzeSinglePitchAccurate()` 호출되는지
- DualEngineService 순환 참조 문제 해결 확인

## 📊 테스트 결과
- 5.8초 녹음 → 230,400 샘플
- CREPE: 1465Hz 반복 (비정상)
- SPICE: 95-98Hz 감지
- SinglePitchTracker: 아직 미실행

## 🔧 기술 스택
- **Frontend**: Flutter (Dart)
- **Audio**: AVAudioEngine (48kHz, macOS native)
- **AI Engines**: 
  - CREPE (localhost:5002) - 고품질 단일 피치
  - SPICE (localhost:5003) - Google 다중 피치
  - SinglePitchTracker - 통합 고정밀 분석
- **알고리즘**: YIN, Autocorrelation, 이동평균, 칼만 필터

## 📝 중요 파일들
```
/Users/seoyeongbin/vocal_trainer_ai/
├── lib/
│   ├── services/
│   │   ├── single_pitch_tracker.dart [핵심]
│   │   ├── dual_engine_service.dart [통합]
│   │   └── native_audio_service.dart
│   ├── widgets/
│   │   └── audio_player_widget.dart [2단계 UI]
│   ├── screens/
│   │   ├── wave_start_screen.dart [1단계]
│   │   ├── fixed_vocal_training_screen.dart [3단계]
│   │   └── pitch_test_screen.dart [테스트용]
│   └── models/
│       └── analysis_result.dart [DualResult 확장]
├── macos/
│   └── Runner/
│       ├── AppDelegate.swift [오디오 엔진]
│       └── GPUAccelerator.swift [GPU 가속]
└── /Users/seoyeongbin/crepe_setup/
    ├── crepe_server.py [CREPE 서버]
    └── spice_server.py [SPICE 서버]
```

## 🎯 다음 작업
1. SinglePitchTracker 실제 호출 확인
2. 로그 `🎯🎯🎯` 출력 확인
3. 실시간 적응형 피치 추적
4. 음정 변화 자동 감지
5. CREPE 서버 GPU 최적화 (선택)

## 💡 개발 인사이트
- 사용자는 자유롭게 부르고 싶어함
- 알고리즘이 사용자를 따라가야 함 (반대 아님)
- 실시간성 > 정확도 (10ms 이하 목표)
- 백그라운드 처리로 UX 개선

## 🚀 실행 명령어
```bash
# 앱 실행
flutter run -d macos

# CREPE 서버 (필요시)
cd /Users/seoyeongbin/crepe_setup
python3.11 crepe_server.py

# SPICE 서버 (필요시)
python3.11 spice_server.py
```

## 📌 기억해야 할 사용자 피드백
1. "대충 초안만 만들지 말고 정교한 고도화된 기능이 구현된거야?"
2. "미쳤냐? 야 10초이상 걸리면 다음으로 자동으로 가면 안돼"
3. "화음분리 알고리즘은 지금단계에서는 필요없어"
4. "응 단일 음정을 정확히 해치하는것부터 시작해"
5. "1초씩 명확하게 부르는거 아니고 내가 부르고 싶은 음을 알고리즘이 알아서 잘 캐치해야지"

## 🔄 프로젝트 진화
- v1: 기본 녹음/재생
- v2: CREPE+SPICE 듀얼 엔진
- **v3: SinglePitchTracker 고정밀 단일 음정 (현재)**

---
**이 문서는 오비완 v3 개발 맥락을 보존하기 위한 것입니다.**
**다음 작업 시작 시 이 문서를 먼저 읽어주세요.**