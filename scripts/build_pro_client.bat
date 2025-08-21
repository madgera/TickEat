@echo off
echo Building TickEat PRO CLIENT...
flutter build windows --dart-define=APP_MODE=pro_client --target=lib/main.dart
echo Build completed: build/windows/x64/runner/Release/
pause
