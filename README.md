# AI 보컬 트레이닝 앱

실시간 음성 분석과 3D 시각적 가이드를 제공하는 AI 기반 보컬 트레이닝 애플리케이션입니다.

## 주요 기능

### 🎤 실시간 음성 분석
- 음정 안정성 분석 (±3 cent 정확도)
- 호흡 타입 분석 (복식호흡 vs 흉식호흡)
- 공명 위치 분석 (목, 구강, 두성, 혼합)
- 비브라토 품질 분석
- 입 모양 및 혀 위치 분석

### 🎯 3D 시각적 가이드
- 3D 해부학적 모델을 활용한 발성 교정
- 실시간 호흡 가이드 애니메이션
- 입 모양 및 혀 위치 시각화
- 자세 교정 가이드
- 단계별 학습 모드

### 🤖 AI 코칭 시스템
- 룰 기반 개인 맞춤형 조언
- 우선순위 기반 문제점 분석
- 실시간 피드백 제공
- 연습 계획 자동 생성

## 설치 및 실행

### 1. 개발 환경 설정

```bash
# Flutter 설치 (3.16 이상)
flutter --version

# 의존성 설치
flutter pub get

# 코드 분석
flutter analyze

# 테스트 실행
flutter test
```

### 2. 로컬 실행

```bash
# 디버그 모드로 실행
flutter run

# 릴리즈 모드로 실행
flutter run --release
```

### 3. 환경 변수 구성(AppConfig)

듀얼 엔진 서비스(DualEngineService)는 환경 변수로 CREPE/SPICE 서버 URL을 받아 초기화됩니다. 개발/테스트/프로덕션별 URL을 아래와 같이 설정하세요.

1. 예시 환경 파일을 복사하여 환경별 값을 입력합니다.

   ```bash
   cp .env.development.example .env.development
   cp .env.test.example .env.test
   cp .env.production.example .env.production
   ```

2. 각 파일에 다음 필드를 채웁니다.

   | 변수 | 설명 |
   | --- | --- |
   | `APP_ENV` | `development`, `test`, `production` 중 하나 |
   | `CREPE_BASE_URL` | 해당 환경의 CREPE API 기본 URL |
   | `SPICE_BASE_URL` | 해당 환경의 SPICE API 기본 URL |

   필요 시 `CREPE_URL_DEV/TEST/PROD`, `SPICE_URL_DEV/TEST/PROD` 값으로 환경별 세부 URL을 덮어쓸 수 있습니다.

3. 실행 시 `start_app.sh`가 `.env.<APP_ENV>` 파일을 자동으로 읽어 `--dart-define` 인자를 설정합니다. 수동으로 실행할 경우 다음 예시를 참고하세요.

   ```bash
   flutter run \
     --dart-define=APP_ENV=development \
     --dart-define=CREPE_BASE_URL=http://localhost:5002 \
     --dart-define=SPICE_BASE_URL=http://localhost:5003
   ```

환경 변수가 누락되면 앱 시작 단계에서 명확한 예외와 경고 로그가 출력됩니다.

### 4. 웹 실행 (테스트용)

```bash
# 웹 서버 시작
flutter run -d chrome

# 또는 웹 빌드 후 로컬 서버
flutter build web
cd build/web
python -m http.server 8000
```

## 테스트 방법

### 1. 기본 테스트
```bash
# 모든 테스트 실행
flutter test

# 특정 테스트 실행
flutter test test/domain/entities/vocal_analysis_test.dart
```

### 2. 앱 기능 테스트

1. **음성 분석 테스트**
   - 앱 실행 후 중앙의 빨간 녹음 버튼 클릭
   - 3-5초간 "아~" 소리로 발성
   - 상단에 실시간 파형과 피치 곡선 확인
   - 하단에 AI 코치 조언 확인

2. **3D 가이드 테스트**
   - 분석 완료 후 중앙 3D 영역에 가이드 표시 확인
   - 조언 섹션의 "호흡 가이드", "자세 교정" 등 버튼 클릭
   - 3D 모델 애니메이션 동작 확인

3. **단계별 학습 테스트**
   - 하단 "단계별" 버튼 클릭
   - 단계별 진행 및 가이드 텍스트 확인
- "이전/다음" 버튼으로 단계 이동 테스트

### 3. DTW 멜로디 정렬 피드백 (선택)
- 원곡의 레퍼런스 피치 시퀀스(Hz)를 준비한 경우, `VanidoStyleTrainingScreen`에 전달하면 DTW 정렬 기반의 정확도/요약/개선 포인트와 시각화가 표시됩니다.
- 사용: `VanidoStyleTrainingScreen(referencePitch: refPitches, ...)`
- 시각화 토글 버튼으로 정렬 경로와 노트 매칭을 확인할 수 있습니다.

## 문제 해결

### 1. 일반적인 문제들

**Q: 앱이 시작되지 않는 경우**
```bash
flutter clean
flutter pub get
flutter run
```

**Q: 권한 오류 발생**
- Android: 마이크 권한 확인
- iOS: 마이크 권한 확인

**Q: 3D 모델이 로드되지 않는 경우**
- `assets/models/` 폴더에 GLB 파일 존재 확인
- `pubspec.yaml`에서 assets 경로 확인

### 2. 성능 문제

**Q: 앱이 느린 경우**
- 릴리즈 모드로 실행: `flutter run --release`
- 성능 모니터링: `flutter run --profile`

**Q: 메모리 사용량이 높은 경우**
- 캐시 정리: 앱 설정에서 캐시 클리어
- 메모리 프로파일링: Flutter DevTools 사용
