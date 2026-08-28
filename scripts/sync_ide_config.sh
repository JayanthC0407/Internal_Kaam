#!/usr/bin/env bash
# Syncs local .env into Android Studio Flutter run configuration
# (also writes dart_defines.json and optional .vscode/settings.json).
# Usage: ./scripts/sync_ide_config.sh
#
# After editing .env, run this script then do a full app restart (not hot restart).

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

mkdir -p .vscode .idea/runConfigurations

ARGS=(
  "--dart-define=OBDX_BASE_URL=${OBDX_BASE_URL}"
  "--dart-define=APP_ENV=${APP_ENV:-dev}"
)

if [[ -n "${OBDX_WEB_FALLBACK_URL:-}" ]]; then
  ARGS+=("--dart-define=OBDX_WEB_FALLBACK_URL=${OBDX_WEB_FALLBACK_URL}")
fi

if [[ -n "${OBDX_INIT_SESSION_PATH:-}" ]]; then
  ARGS+=("--dart-define=OBDX_INIT_SESSION_PATH=${OBDX_INIT_SESSION_PATH}")
fi

python3 - "$ROOT" "${ARGS[@]}" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
args = sys.argv[2:]

# Optional .vscode/settings.json (local editor; not required for Android Studio)
vscode_settings = root / ".vscode" / "settings.json"
settings = {}
if vscode_settings.exists():
    settings = json.loads(vscode_settings.read_text())
settings["dart.flutterRunAdditionalArgs"] = args
vscode_settings.write_text(json.dumps(settings, indent=2) + "\n")

# Flutter --dart-define-from-file (Android Studio + CLI)
defines = {}
for arg in args:
    if arg.startswith("--dart-define="):
        key, value = arg.removeprefix("--dart-define=").split("=", 1)
        defines[key] = value

dart_defines = root / "dart_defines.json"
dart_defines.write_text(json.dumps(defines, indent=2) + "\n")

# Android Studio run configuration (local .idea — gitignored)
run_xml = root / ".idea" / "runConfigurations" / "UBCI_Bank.xml"
run_xml.write_text(
    """<?xml version="1.0" encoding="UTF-8"?>
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="UBCI Bank" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="filePath" value="$PROJECT_DIR$/lib/main.dart" />
    <option name="additionalArgs" value="--dart-define-from-file=dart_defines.json" />
    <method v="2" />
  </configuration>
</component>
"""
)
PY

echo "Updated:"
echo "  ${ROOT}/.idea/runConfigurations/UBCI_Bank.xml  (Android Studio)"
echo "  ${ROOT}/dart_defines.json                      (Android Studio / CLI)"
echo "  ${ROOT}/.vscode/settings.json                  (optional local editor)"
echo ""
echo "Next steps:"
echo "  1. Stop the running app completely."
echo "  2. Android Studio: choose run configuration \"UBCI Bank\" (or add"
echo "     --dart-define-from-file=dart_defines.json under Additional run args)."
echo "  3. Run again — hot restart is NOT enough."
