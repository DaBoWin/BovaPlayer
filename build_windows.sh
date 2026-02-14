#!/bin/bash
set -e

echo "🪟 Building BovaPlayer for Windows..."

cd core

echo "⚠️  Note: Cross-compiling to Windows from macOS requires additional setup."
echo "For best results, build on a Windows machine using:"
echo "  cargo build --release --bin bova-gui"
echo ""
echo "Attempting cross-compilation..."

# 尝试构建 Windows 版本（如果已安装 target）
if cargo build --release --bin bova-gui --target x86_64-pc-windows-gnu 2>/dev/null; then
    # 创建发布目录
    RELEASE_DIR="target/windows-release"
    mkdir -p "${RELEASE_DIR}"

    # 复制可执行文件
    cp "target/x86_64-pc-windows-gnu/release/bova-gui.exe" "${RELEASE_DIR}/BovaPlayer.exe"

    # 创建 ZIP 包
    echo "📦 Creating ZIP archive..."
    cd "${RELEASE_DIR}"
    zip -r "../BovaPlayer-Windows-v0.0.1.zip" .
    cd ../..

    echo "✅ Windows build complete!"
    echo "📦 Executable: core/${RELEASE_DIR}/BovaPlayer.exe"
    echo "📦 ZIP: core/target/BovaPlayer-Windows-v0.0.1.zip"
else
    echo "❌ Windows cross-compilation failed."
    echo ""
    echo "To build for Windows, you need to:"
    echo "1. Install the Windows target: rustup target add x86_64-pc-windows-gnu"
    echo "2. Install mingw-w64: brew install mingw-w64"
    echo "3. Or build on a Windows machine directly"
    exit 1
fi
