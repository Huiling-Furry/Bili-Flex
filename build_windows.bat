@echo off
chcp 65001 >nul
echo ========================================
echo   BiliFlex Windows 一键构建脚本
echo ========================================
echo.

REM 检查 Flutter 是否可用
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Flutter SDK。
    echo 请先安装 Flutter: https://docs.flutter.dev/get-started/install/windows
    echo 并将 flutter\bin 加入 PATH 环境变量。
    pause
    exit /b 1
)

REM 检查 Visual Studio
flutter doctor -v 2>nul | findstr /C:"Visual Studio" >nul
if %errorlevel% neq 0 (
    echo [警告] 未检测到 Visual Studio C++ 工具链，Windows 构建可能失败。
    echo 请安装 Visual Studio 2022 并勾选"使用 C++ 的桌面开发"。
    echo.
)

echo [1/3] 拉取依赖...
flutter pub get
if %errorlevel% neq 0 (
    echo [错误] 依赖拉取失败
    pause
    exit /b 1
)

echo.
echo [2/3] 静态分析...
flutter analyze --no-fatal-infos

echo.
echo [3/3] 构建 Release 版...
flutter build windows --release
if %errorlevel% neq 0 (
    echo [错误] 构建失败
    pause
    exit /b 1
)

echo.
echo ========================================
echo   构建成功！
echo ========================================
echo 可执行文件位置:
echo   build\windows\x64\runner\Release\biliflex.exe
echo.
echo 整个 Release 文件夹即为绿色版程序，可直接复制分发。
echo.
explorer "build\windows\x64\runner\Release"
pause
