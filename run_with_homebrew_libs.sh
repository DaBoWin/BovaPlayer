#!/bin/bash

# 设置 Homebrew 库路径，让应用能找到 MPV 的依赖
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib:$DYLD_FALLBACK_LIBRARY_PATH"

# 运行应用
cd ui/flutter_app
flutter run -d macos
