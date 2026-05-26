#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DeskReset"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
swift build -c release --product DeskReset
swift build -c release --product deskresetctl

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$ROOT/dist/bin"
cp "$BUILD_DIR/DeskReset" "$MACOS/$APP_NAME"
cp "$BUILD_DIR/deskresetctl" "$ROOT/dist/bin/deskresetctl"
swift "$ROOT/scripts/generate-icon.swift" "$RESOURCES/AppIcon.icns" >/dev/null

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.andrewstelmach.deskreset</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>0.7.0</string>
  <key>CFBundleVersion</key>
  <string>7</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSUserNotificationUsageDescription</key>
  <string>DeskReset sends gentle reminders to rest your eyes and move.</string>
  <key>NSCameraUsageDescription</key>
  <string>DeskReset can optionally use local face presence detection to count natural away-from-screen breaks. Frames are not saved or sent anywhere.</string>
</dict>
</plist>
PLIST

touch "$APP_DIR"
echo "$APP_DIR"
