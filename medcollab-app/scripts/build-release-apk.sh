#!/usr/bin/env bash
# Build a release APK pointed at the production backend.
# Usage: ./scripts/build-release-apk.sh https://your-api.up.railway.app
set -euo pipefail

API_BASE_URL="${1:?Usage: $0 <API_BASE_URL> [SOCKET_URL]}"
SOCKET_URL="${2:-}"

cd "$(dirname "$0")/.."
API_BASE_URL="${API_BASE_URL%/}"

echo "Building MedCollab release APK"
echo "  API_BASE_URL: $API_BASE_URL"

flutter analyze

DEFINES=(
  "--dart-define=API_BASE_URL=$API_BASE_URL"
  "--dart-define=ENABLE_API_LOGGING=false"
)
if [[ -n "$SOCKET_URL" ]]; then
  DEFINES+=("--dart-define=SOCKET_URL=${SOCKET_URL%/}")
fi

flutter build apk --release "${DEFINES[@]}"

echo ""
echo "Done. APK: build/app/outputs/flutter-apk/app-release.apk"
