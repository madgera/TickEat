#!/bin/bash

echo "Building all TickEat versions..."

echo ""
echo "============================"
echo "   Building BASE version"
echo "============================"
flutter build linux --dart-define=APP_MODE=base --target=lib/main.dart
mkdir -p builds/base
cp -r build/linux/x64/release/bundle/* builds/base/

echo ""
echo "============================"
echo "  Building PRO CLIENT"
echo "============================"
flutter build linux --dart-define=APP_MODE=pro_client --target=lib/main.dart
mkdir -p builds/pro_client
cp -r build/linux/x64/release/bundle/* builds/pro_client/

echo ""
echo "============================"
echo "  Building PRO SERVER"
echo "============================"
flutter build linux --dart-define=APP_MODE=pro_server --target=lib/main.dart
mkdir -p builds/pro_server
cp -r build/linux/x64/release/bundle/* builds/pro_server/

echo ""
echo "============================"
echo "     BUILD COMPLETED"
echo "============================"
echo "BASE version:       builds/base/"
echo "PRO CLIENT version: builds/pro_client/"
echo "PRO SERVER version: builds/pro_server/"
echo ""
