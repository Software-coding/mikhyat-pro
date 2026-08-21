@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found in PATH.
  echo Install Flutter SDK first, then reopen this file.
  pause
  exit /b 1
)
if not exist android\settings.gradle if not exist android\settings.gradle.kts (
  echo Creating Android platform files...
  flutter create . --platforms=android --org com.mikhyat --project-name mikhyat_pro
  if errorlevel 1 goto :fail
)
flutter pub get
if errorlevel 1 goto :fail
flutter run
exit /b %errorlevel%
:fail
echo.
echo An error occurred while preparing the project.
pause
exit /b 1
