@echo off
echo Building BovaPlayer for Windows...
echo.

cd core

echo Building Rust binary...
cargo build --release --bin bova-gui

if %ERRORLEVEL% NEQ 0 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Creating release directory...
set RELEASE_DIR=target\windows-release
if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"

echo Copying executable...
copy "target\release\bova-gui.exe" "%RELEASE_DIR%\BovaPlayer.exe"

echo.
echo ✅ Windows build complete!
echo 📦 Executable: core\%RELEASE_DIR%\BovaPlayer.exe
echo.
echo To create a ZIP archive, use:
echo   powershell Compress-Archive -Path "%RELEASE_DIR%\*" -DestinationPath "target\BovaPlayer-Windows-v0.0.1.zip"
echo.
pause
