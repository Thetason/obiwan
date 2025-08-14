# YouTube 보컬 라벨링 봇 개발 진행 상황

## 📅 2025-08-14 개발 요약

### 🎯 목표
오비완 v3.3 고도화를 위한 AI 라벨링 봇 개발 - YouTube 영상에서 자동으로 보컬 데이터를 수집하고 라벨링

### ✅ 완료된 작업

#### 1. YouTube 라벨링 시스템 구축
- **`youtube_vocal_labeler.py`** - 완전한 YouTube 보컬 라벨링 시스템
  - yt-dlp를 통한 YouTube 오디오 다운로드
  - CREPE/SPICE 서버 연동 (포트 5002/5003)
  - 포먼트 분석 통합
  - JSON 형식 라벨 생성 및 저장
  - 배치 처리 지원

#### 2. Flutter UI 통합
- **`url_input_screen.dart`** - YouTube URL 입력 화면
  - 5개 프리셋 URL 자동 로딩 (Adele, Sam Smith, Bruno Mars, 아이유, 박효신)
  - URL 리스트 관리 (추가/삭제)
  - AI 라벨링 대시보드 연결

#### 3. 프리셋 URL 자동 로딩 버그 수정
```dart
// 문제: final List에 직접 할당 불가
// _urlList = presetURLs; // ❌ 에러

// 해결: addAll() 메서드 사용
_urlList.addAll(presetURLs); // ✅ 정상 작동
```

#### 4. 시뮬레이션 모드 구현
- ffmpeg 없이도 테스트 가능한 시뮬레이션 모드
- 실제 다운로드 없이 라벨 구조 검증
- `youtube_simple_test.py` - 간단한 시뮬레이션 테스트

### 📊 현재 상태

| 컴포넌트 | 상태 | 설명 |
|---------|------|------|
| YouTube 다운로드 | ⏳ | ffmpeg 설치 필요 |
| CREPE 서버 | ✅ | 포트 5002에서 정상 작동 |
| SPICE 서버 | ✅ | 포트 5003에서 정상 작동 |
| URL 프리셋 | ✅ | 5개 URL 자동 로딩 |
| Flutter UI | ✅ | URL 입력 화면 완성 |
| 라벨 생성 | ✅ | 시뮬레이션 모드로 작동 |

### 🔧 기술 스택
- **Backend**: Python (yt-dlp, requests, numpy)
- **AI**: CREPE + SPICE 듀얼 엔진
- **Frontend**: Flutter/Dart
- **Data**: JSON 형식 라벨링

### 📁 주요 파일
```
/Users/seoyeongbin/vocal_trainer_ai/
├── youtube_vocal_labeler.py    # 메인 라벨링 시스템
├── youtube_simple_test.py       # 시뮬레이션 테스트
├── quick_test.py               # 빠른 테스트
├── lib/screens/
│   ├── url_input_screen.dart   # URL 입력 UI
│   └── ai_labeling_dashboard.dart # 라벨링 대시보드
└── labels/                      # 생성된 라벨 저장
```

### 🚀 다음 단계
1. [ ] ffmpeg 설치 완료
2. [ ] 실제 YouTube 다운로드 테스트
3. [ ] Flutter 앱 성능 최적화 (릴리즈 빌드)
4. [ ] 라벨 데이터 품질 검증
5. [ ] 대량 URL 처리 최적화

### 💡 핵심 개선사항
- URL 프리셋 자동 로딩으로 사용성 향상
- 시뮬레이션 모드로 개발/테스트 효율성 증대
- CREPE/SPICE 듀얼 엔진으로 높은 정확도

### 📝 사용법
```bash
# 시뮬레이션 모드 테스트
python3 youtube_simple_test.py

# 실제 라벨링 (ffmpeg 필요)
python3 youtube_vocal_labeler.py

# Flutter 앱 실행
flutter run -d macos
```

### 🐛 알려진 이슈
- Flutter 디버그 모드 느림 → 릴리즈 빌드 필요
- ffmpeg 설치 시간 오래 걸림
- file_picker 패키지 경고 (무시 가능)

### 📈 성과
- 5개 프리셋 URL 정상 로드 ✅
- CREPE/SPICE 서버 안정적 작동 ✅
- 라벨 생성 및 저장 성공 ✅
- UI/UX 통합 완료 ✅