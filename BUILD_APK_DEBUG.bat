@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found in PATH.
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 goto :fail
flutter test
if errorlevel 1 goto :fail
flutter build apk --debug
if errorlevel 1 goto :fail
echo.
echo Debug APK created at:
echo build\app\outputs\flutter-apk\app-debug.apk
pause
exit /b 0
:fail
echo.
echo Build failed. Review the message above.
pause
exit /b 1
