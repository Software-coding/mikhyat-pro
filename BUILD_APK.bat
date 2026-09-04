@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found in PATH.
  pause
  exit /b 1
)
if not exist android\settings.gradle if not exist android\settings.gradle.kts (
  flutter create . --platforms=android --org com.mikhyat --project-name mikhyat_pro
  if errorlevel 1 goto :fail
)
if not exist android\key.properties (
  echo Release signing is not configured.
  echo Copy android\key.properties.example to android\key.properties
  echo and configure your private keystore first.
  echo.
  echo For a local test APK, run BUILD_APK_DEBUG.bat instead.
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 goto :fail
flutter test
if errorlevel 1 goto :fail
flutter build apk --release
if errorlevel 1 goto :fail
echo.
echo APK created at:
echo build\app\outputs\flutter-apk\app-release.apk
pause
exit /b 0
:fail
echo.
echo Build failed. Review the message above.
pause
exit /b 1
