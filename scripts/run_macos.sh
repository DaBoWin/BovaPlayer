#!/bin/bash
set -euo pipefail

cd ui/flutter_app
flutter pub get
flutter run -d macos
