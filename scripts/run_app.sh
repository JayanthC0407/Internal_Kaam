#!/usr/bin/env bash
# Loads local .env and runs the Flutter app with matching --dart-define values.
# Usage: ./scripts/run_app.sh [device args passed to flutter run]
#
# Prerequisites:
#   cp .env.example .env
#   Edit .env with your API host ( .env is gitignored )

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env file. Copy .env.example to .env and set OBDX_BASE_URL." >&2
  echo "  cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

if [[ -z "${OBDX_BASE_URL:-}" ]]; then
  echo "OBDX_BASE_URL is required in .env" >&2
  exit 1
fi

# Flutter web cannot call internal OBDX hosts (CORS). Default to local proxy when
# targeting Chrome/web and OBDX_WEB_FALLBACK_URL is unset.
is_web_target=false
for arg in "$@"; do
  case "$arg" in
    chrome|web-server|edge|*chrome*) is_web_target=true ;;
  esac
  # flutter run -d chrome
  if [[ "$arg" == "-d" || "$arg" == "--device-id" ]]; then
    next_is_device=true
  elif [[ "${next_is_device:-}" == true ]]; then
    case "$arg" in
      chrome|web-server|edge) is_web_target=true ;;
    esac
    next_is_device=false
  fi
done

if [[ -z "${OBDX_WEB_FALLBACK_URL:-}" && "$is_web_target" == true ]]; then
  OBDX_WEB_FALLBACK_URL="http://localhost:8082"
  echo "OBDX_WEB_FALLBACK_URL unset — using ${OBDX_WEB_FALLBACK_URL} for web (CORS proxy)." >&2
  echo "Start proxy in another terminal: set -a && source .env && set +a && node proxy.js" >&2
fi

DEFINES=(
  "--dart-define=OBDX_BASE_URL=${OBDX_BASE_URL}"
  "--dart-define=APP_ENV=${APP_ENV:-dev}"
)

if [[ -n "${OBDX_WEB_FALLBACK_URL:-}" ]]; then
  DEFINES+=("--dart-define=OBDX_WEB_FALLBACK_URL=${OBDX_WEB_FALLBACK_URL}")
fi

if [[ "$is_web_target" == true && -n "${OBDX_WEB_FALLBACK_URL:-}" ]]; then
  echo "Web Dio base: ${OBDX_WEB_FALLBACK_URL}" >&2
fi

if [[ -n "${OBDX_INIT_SESSION_PATH:-}" ]]; then
  DEFINES+=("--dart-define=OBDX_INIT_SESSION_PATH=${OBDX_INIT_SESSION_PATH}")
fi

if [[ -n "${SSL_PIN_SHA256:-}" ]]; then
  DEFINES+=("--dart-define=SSL_PIN_SHA256=${SSL_PIN_SHA256}")
fi

if [[ -n "${SSL_PIN_ENABLED:-}" ]]; then
  DEFINES+=("--dart-define=SSL_PIN_ENABLED=${SSL_PIN_ENABLED}")
fi

if [[ -n "${SESSION_IDLE_TIMEOUT_MINUTES:-}" ]]; then
  DEFINES+=(
    "--dart-define=SESSION_IDLE_TIMEOUT_MINUTES=${SESSION_IDLE_TIMEOUT_MINUTES}"
  )
fi

if [[ -n "${DEVICE_SECURITY_MODE:-}" ]]; then
  DEFINES+=("--dart-define=DEVICE_SECURITY_MODE=${DEVICE_SECURITY_MODE}")
fi

if [[ -n "${BLOCK_EMULATOR_IN_RELEASE:-}" ]]; then
  DEFINES+=(
    "--dart-define=BLOCK_EMULATOR_IN_RELEASE=${BLOCK_EMULATOR_IN_RELEASE}"
  )
fi

if [[ -n "${SCREEN_PROTECTION_ENABLED:-}" ]]; then
  DEFINES+=(
    "--dart-define=SCREEN_PROTECTION_ENABLED=${SCREEN_PROTECTION_ENABLED}"
  )
fi

exec flutter run "${DEFINES[@]}" "$@"
