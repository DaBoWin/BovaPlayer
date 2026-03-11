#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <macos|windows|android>"
  exit 1
fi

PLATFORM="$1"

cd ui/flutter_app
flutter pub get

case "$PLATFORM" in
  macos)
    flutter build macos --release
    ;;
  windows)
    flutter build windows --release
    ;;
  android)
    flutter build apk --release
    ;;
  *)
    echo "Unsupported platform: $PLATFORM"
    exit 1
    ;;
esac
