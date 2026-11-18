#!/usr/bin/env bash
# Builds the DXP Studio preview (this app's DXP renderer, web) and installs it
# into the DXP platform, which serves it at /app/ for the console's preview.
#
# Usage: ./scripts/build_dxp_preview.sh [path-to-dxp-platform]
#   default platform path: /d/Digital/dxp-platform
#
# Run it again whenever lib/src/sdui changes, so the Studio preview keeps
# drawing exactly what the app draws. Reload the console page afterwards.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${1:-/d/Digital/dxp-platform}"
TARGET="$PLATFORM/backend/public/app"
FLUTTER="${FLUTTER:-$USERPROFILE/flutter/bin/flutter.bat}"
[[ -x "$FLUTTER" ]] || FLUTTER=flutter

if [[ ! -d "$PLATFORM/backend/public" ]]; then
  echo "DXP platform not found at $PLATFORM" >&2
  exit 1
fi

cd "$ROOT"
# --base-href /app/: the platform serves the preview there.
# --no-web-resources-cdn: CanvasKit is served by the platform itself; its
#   Content-Security-Policy allows scripts only from the same origin.
# MSYS_NO_PATHCONV: stops Git Bash on Windows turning /app/ into a path.
MSYS_NO_PATHCONV=1 "$FLUTTER" build web \
  -t lib/dxp_preview_main.dart \
  --base-href /app/ \
  --no-web-resources-cdn \
  -o build/dxp_preview

# Keep the prototype's preview once, so it can be put back.
if [[ -d "$TARGET" && ! -d "$PLATFORM/backend/public/app_prototype" ]]; then
  cp -r "$TARGET" "$PLATFORM/backend/public/app_prototype"
fi
rm -rf "$TARGET"
cp -r build/dxp_preview "$TARGET"
echo "Installed the Demo Bank preview into $TARGET. Reload the console."
