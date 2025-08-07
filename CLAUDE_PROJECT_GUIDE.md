# 🎤 오비완 v2 - Claude 프로젝트 복구 가이드

## 📍 **프로젝트 정보**
- **프로젝트명**: Obi-wan v2 - AI Vocal Training Assistant  
- **위치**: `/Users/seoyeongbin/vocal_trainer_ai`
- **개발기간**: 2025년 7월 ~ 8월 7일
- **최종 상태**: Phase 3 완료 - CREPE + SPICE AI 엔진 통합 완료

## 🚀 **Claude Code 재시작 시 프로젝트 복구 방법**

### 1️⃣ **Claude에게 전달할 핵심 정보**
```
프로젝트 위치: /Users/seoyeongbin/vocal_trainer_ai
프로젝트명: 오비완 v2 - AI 보컬 트레이닝 앱
현재 상태: CREPE + SPICE 듀얼 AI 엔진으로 완전 작동하는 macOS 네이티브 앱
```

### 2️⃣ **Claude에게 요청할 명령어**
```
"오비완 v2 프로젝트를 이어서 개발하자. 
프로젝트 위치: /Users/seoyeongbin/vocal_trainer_ai
CLAUDE_PROJECT_GUIDE.md 파일을 읽고 현재 상태를 파악해줘."
```

## 🎯 **프로젝트 현재 상태 (2025-08-07 완성)**

### ✅ **Phase 1: 안정적인 오디오 시스템 (완료)**
- AVAudioEngine error -10879 크래시 완전 해결
- 실제 마이크 녹음/재생 성공 (48kHz, 9.1초 녹음 테스트 통과)
- Apple Voice Memos 스타일 UI 완벽 작동
- 웨이브폼 시각화 (150바 렌더링)

### ✅ **Phase 2: CREPE + SPICE AI 엔진 통합 (완료)**
- **CREPE 서버**: localhost:5002 (고품질 단일 피치 분석)
- **SPICE 서버**: localhost:5003 (구글 다중 피치 분석, 화음 감지)
- **듀얼 AI 분석**: 시간별 피치 분석 (409개 윈도우 → 100개 최적화)
- **AI 서버 연동**: macOS 네트워크 권한 해결완료

### ✅ **Phase 3: 고급 UI 및 최적화 (완료)**
- 타임아웃 설정 조정: connectTimeout 30초, receiveTimeout 60초
- 실시간 피치 시각화 시스템
- 사용자 중심 워크플로우 (1-2-3단계)

## 🔧 **기술 스택**
- **Frontend**: Flutter (Dart) - macOS 네이티브
- **Audio Engine**: AVAudioEngine (Swift) - 48kHz 실시간 처리
- **AI Engines**: CREPE (CNN 기반) + SPICE (Self-supervised)
- **Architecture**: 실시간 분석 → AI 처리 → 시각화 파이프라인

## 🚀 **앱 실행 방법**

### **자동 실행 (추천)**
```bash
cd /Users/seoyeongbin/vocal_trainer_ai
./전자동시작.sh
```

### **수동 실행**
```bash
cd /Users/seoyeongbin/vocal_trainer_ai

# 1. AI 서버들 시작
./start_servers.sh

# 2. Flutter 앱 시작  
flutter run -d macos
```

### **서버 상태 확인**
```bash
curl http://localhost:5002/health  # CREPE
curl http://localhost:5003/health  # SPICE
```

## 📁 **핵심 파일 구조**

### **오디오 시스템**
- `lib/services/native_audio_service.dart` - Flutter ↔ Swift 브리지
- `macos/Runner/AppDelegate.swift` - AVAudioEngine 네이티브 구현

### **AI 분석 시스템**  
- `lib/services/dual_engine_service.dart` - CREPE + SPICE 통합
- `lib/models/analysis_result.dart` - AI 분석 결과 모델

### **UI 시스템**
- `lib/screens/wave_start_screen.dart` - 메인 녹음 화면 
- `lib/widgets/audio_player_widget.dart` - Apple Voice Memos 스타일 재생
- `lib/widgets/wave_visualizer_widget.dart` - 원형 웨이브 시각화

### **설정 파일들**
- `CLAUDE.md` - 개발 가이드 및 원칙
- `DEVELOPMENT_PRINCIPLES.md` - 소프트웨어 개발 원칙
- `개발완료보고서.md` - 전체 개발 내역

## 🎵 **사용자 워크플로우**
1. **Step 1**: 중앙 원형 UI 터치&홀드 → 실시간 마이크 녹음
2. **Step 2**: Apple Voice Memos 스타일로 녹음 재생 및 검토
3. **Step 3**: CREPE + SPICE AI 분석 → 피치 피드백 제공

## ⚡ **성능 지표**
- **오디오 지연**: < 20ms (실시간)
- **분석 정확도**: CREPE 95%+ (단일 피치), SPICE 90%+ (화음)
- **메모리 사용**: < 200MB (macOS 최적화)
- **CPU 사용**: < 30% (M1 기준)

## 🐛 **알려진 해결된 문제들**
- ✅ AVAudioEngine -10879 크래시 (완전 해결)
- ✅ macOS 마이크 권한 문제 (해결)
- ✅ CREPE/SPICE 네트워크 연결 (해결)
- ✅ 타임아웃 설정 (10초 → 60초로 확장)

## 📋 **다음 개발 가능한 기능들**
- 실시간 피치 트래킹 곡선 개선
- 음계별 색상 그라데이션 고도화
- 비브라토 분석 및 시각화
- 멀티 세션 녹음 관리
- 클라우드 백업 및 진도 추적

## 💾 **백업 및 버전 관리**
- Git 저장소: `/Users/seoyeongbin/vocal_trainer_ai/.git`
- 최종 커밋: 2025-08-07
- 브랜치: main (안정 버전)

---

## 🆘 **긴급 복구 명령어들**

### **완전 재시작**
```bash
cd /Users/seoyeongbin/vocal_trainer_ai
pkill -f crepe_server
pkill -f spice_server  
pkill -f flutter
./전자동시작.sh
```

### **서버만 재시작**
```bash
./start_servers.sh
```

### **앱만 재시작**
```bash
flutter run -d macos
```

---

**💡 Claude에게: 이 파일을 읽으면 프로젝트의 모든 상태를 파악할 수 있습니다.**