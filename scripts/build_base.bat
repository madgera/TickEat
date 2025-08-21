@echo off
echo Building TickEat BASE...
flutter build windows --dart-define=APP_MODE=base --target=lib/main.dart
echo Build completed: build/windows/x64/runner/Release/
pause
