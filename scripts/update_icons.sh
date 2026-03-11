#!/bin/bash
set -euo pipefail

cd ui/flutter_app

if [ ! -f "assets/icon.png" ]; then
  echo "Missing ui/flutter_app/assets/icon.png"
  exit 1
fi

flutter pub get
dart run flutter_launcher_icons
