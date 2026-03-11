#!/bin/bash
set -euo pipefail

cd ui/flutter_app

PASS=0
FAIL=0

check_file() {
  if [ -f "$1" ]; then
    echo "OK  $1"
    PASS=$((PASS + 1))
  else
    echo "MISS $1"
    FAIL=$((FAIL + 1))
  fi
}

check_text() {
  if grep -q "$2" "$1" 2>/dev/null; then
    echo "OK  $3"
    PASS=$((PASS + 1))
  else
    echo "MISS $3"
    FAIL=$((FAIL + 1))
  fi
}

echo "Android SMB sanity check"
echo

check_file "android/app/build.gradle.kts"
check_file "android/app/src/main/AndroidManifest.xml"
check_file "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt"
check_file "lib/services/smb_service.dart"
check_file "lib/network_browser_page.dart"

check_text "android/app/build.gradle.kts" "jcifs-ng" "jcifs-ng dependency"
check_text "android/app/src/main/AndroidManifest.xml" "android.permission.INTERNET" "internet permission"
check_text "android/app/src/main/kotlin/com/example/bova_player_flutter/SmbHandler.kt" "fun connect" "Android connect method"
check_text "lib/services/smb_service.dart" "MethodChannel" "Dart SMB method channel"

echo
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
