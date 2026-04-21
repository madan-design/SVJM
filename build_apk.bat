@echo off
echo Building SVJM Quote Generator APK...
echo.

echo Step 1: Cleaning project...
flutter clean
if %errorlevel% neq 0 (
    echo Clean failed!
    pause
    exit /b 1
)

echo Step 2: Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo Pub get failed!
    pause
    exit /b 1
)

echo Step 3: Building APK...
flutter build apk --release --verbose
if %errorlevel% neq 0 (
    echo APK build failed!
    pause
    exit /b 1
)

echo.
echo ✅ APK built successfully!
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo.
pause