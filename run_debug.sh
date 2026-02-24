#!/bin/bash

cd ui/flutter_app
flutter run -d macos --verbose 2>&1 | tee /tmp/flutter_debug.log
