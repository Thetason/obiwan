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

set -e

# 스크립트가 위치한 디렉토리로 이동(경로 하드코딩 제거)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔧 서버와 앱을 순서대로 시작합니다 (자동 설치 포함)."

ARCH="$(uname -m)"
echo "🧭 ARCH=$ARCH"

# 1) Python 및 가상환경 자동 준비
if [ "$ARCH" = "x86_64" ]; then
  echo "🔧 Intel mac: Python 3.10 + TF 2.14 경로로 진행"
  brew install python@3.10 >/dev/null 2>&1 || true
  PY="$(brew --prefix python@3.10)/bin/python3.10"
  if [ ! -x "$PY" ]; then
    echo "🧹 brew 링크 정리(gdbm)"
    brew unlink gdbm >/dev/null 2>&1 || true
    brew link --overwrite gdbm >/dev/null 2>&1 || true
    brew reinstall python@3.10 >/dev/null 2>&1 || true
    PY="$(brew --prefix python@3.10)/bin/python3.10"
  fi
  echo "🐍 Using $PY"
  if [ ! -d "venv310" ]; then "$PY" -m venv venv310; fi
  source venv310/bin/activate
  python -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  # 안정 조합 설치
  python -m pip install \
    numpy==1.26.4 scipy==1.10.1 scikit-learn==1.3.2 h5py==3.8.0 \
    matplotlib==3.7.2 resampy==0.2.2 hmmlearn==0.2.8 imageio==2.31.2 \
    flask==3.0.3 flask-cors==4.0.1 >/dev/null 2>&1 || true
  python -m pip install crepe==0.0.12 tensorflow==2.14.0 >/dev/null 2>&1 || true
else
  echo "🔧 Apple Silicon: Python 3.11 + TF-macos 경로로 진행"
  brew install python@3.11 >/dev/null 2>&1 || true
  PY="$(brew --prefix python@3.11)/bin/python3.11"
  if [ ! -d "venv311" ]; then "$PY" -m venv venv311; fi
  source venv311/bin/activate
  python -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 || true
  python -m pip install numpy==1.26.4 resampy==0.4.3 crepe==0.0.12 \
    flask==3.0.3 flask-cors==4.0.1 tensorflow-macos==2.14.0 tensorflow-metal==1.1.0 \
    >/dev/null 2>&1 || true
fi

# 2) CREPE 모델 워밍업(검증)
python - <<'PY'
import numpy as np, crepe
try:
    crepe.predict(np.zeros(16000,dtype=np.float32),16000,viterbi=False,verbose=0)
    print('CREPE warmup ok')
except Exception as e:
    print('CREPE warmup failed:', e)
PY

# 3) 서버 기동: 최소 CREPE만 우선 (실패율 최소화)
chmod +x start_min_servers.sh
./start_min_servers.sh || { echo "❌ CREPE 서버 기동 실패"; read -p "Press any key to exit..."; exit 1; }

# 4) Flutter 앱 실행
echo "🎵 Flutter 앱 실행"
flutter clean >/dev/null 2>&1 || true
flutter pub get >/dev/null 2>&1 || true
flutter run -d macos

# 종료 대기
read -p "Press any key to exit..."
