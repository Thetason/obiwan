#!/bin/bash

# 오비완 v3 앱 실행 스크립트
echo "🎤 오비완 v3 앱을 시작합니다..."
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_ENVIRONMENT="${APP_ENV:-development}"
ENV_FILE=".env.${APP_ENVIRONMENT}"

if [ -f "$ENV_FILE" ]; then
  echo "📦 환경 설정 로드: $ENV_FILE"
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
  APP_ENVIRONMENT="${APP_ENV:-$APP_ENVIRONMENT}"
else
  echo "⚠️ 환경 파일 $ENV_FILE 을(를) 찾을 수 없습니다. 기존 환경 변수를 사용합니다."
fi

ENV_SUFFIX="DEV"
case "$APP_ENVIRONMENT" in
  production)
    ENV_SUFFIX="PROD"
    ;;
  test)
    ENV_SUFFIX="TEST"
    ;;
esac

FLUTTER_CMD=(flutter run -d macos "--dart-define=APP_ENV=$APP_ENVIRONMENT")

if [ -n "$CREPE_BASE_URL" ]; then
  FLUTTER_CMD+=("--dart-define=CREPE_BASE_URL=$CREPE_BASE_URL")
fi

if [ -n "$SPICE_BASE_URL" ]; then
  FLUTTER_CMD+=("--dart-define=SPICE_BASE_URL=$SPICE_BASE_URL")
fi

CREPE_KEY="CREPE_URL_${ENV_SUFFIX}"
SPICE_KEY="SPICE_URL_${ENV_SUFFIX}"
CREPE_OVERRIDE="${!CREPE_KEY}"
SPICE_OVERRIDE="${!SPICE_KEY}"

if [ -n "$CREPE_OVERRIDE" ]; then
  FLUTTER_CMD+=("--dart-define=${CREPE_KEY}=$CREPE_OVERRIDE")
fi

if [ -n "$SPICE_OVERRIDE" ]; then
  FLUTTER_CMD+=("--dart-define=${SPICE_KEY}=$SPICE_OVERRIDE")
fi

echo "🚀 실행 환경: $APP_ENVIRONMENT"

# Flutter 앱 실행
"${FLUTTER_CMD[@]}"

# 종료 시 메시지
echo "================================"
echo "👋 오비완 v3 앱이 종료되었습니다."
