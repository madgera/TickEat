@echo off
echo Building all TickEat versions...

echo.
echo ============================
echo    Building BASE version
echo ============================
flutter build windows --dart-define=APP_MODE=base --target=lib/main.dart
if not exist "builds\base" mkdir "builds\base"
xcopy "build\windows\x64\runner\Release\*" "builds\base\" /E /I /Y

echo.
echo ============================
echo   Building PRO CLIENT
echo ============================
flutter build windows --dart-define=APP_MODE=pro_client --target=lib/main.dart
if not exist "builds\pro_client" mkdir "builds\pro_client"
xcopy "build\windows\x64\runner\Release\*" "builds\pro_client\" /E /I /Y

echo.
echo ============================
echo   Building PRO SERVER
echo ============================
flutter build windows --dart-define=APP_MODE=pro_server --target=lib/main.dart
if not exist "builds\pro_server" mkdir "builds\pro_server"
xcopy "build\windows\x64\runner\Release\*" "builds\pro_server\" /E /I /Y

echo.
echo ============================
echo      BUILD COMPLETED
echo ============================
echo BASE version:       builds\base\
echo PRO CLIENT version: builds\pro_client\
echo PRO SERVER version: builds\pro_server\
echo.
pause
