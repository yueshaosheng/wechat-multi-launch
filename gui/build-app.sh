#!/bin/zsh
# Builds "WeChat Multi Launch.app" from the SwiftUI sources, embedding the
# existing launch script and icons so the GUI runs fully offline.
set -euo pipefail

GUI_DIR="${0:A:h}"
REPO_DIR="${GUI_DIR:h}"
BUILD_DIR="$GUI_DIR/build"
APP="$BUILD_DIR/WeChat Multi Launch.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
TARGET="arm64-apple-macosx13.0"

command -v swiftc >/dev/null 2>&1 || { print -u2 "swiftc not found. Install Xcode or the Command Line Tools."; exit 1; }

print "Compiling SwiftUI sources..."
mkdir -p "$MACOS" "$RESOURCES"
swiftc -O -parse-as-library -target "$TARGET" \
  -framework SwiftUI -framework AppKit \
  "$GUI_DIR"/Sources/*.swift \
  -o "$MACOS/WeChatMultiLaunch"

print "Assembling bundle..."
cp "$GUI_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$REPO_DIR/WeChat-Multi-Launch.command" "$RESOURCES/WeChat-Multi-Launch.command"
chmod +x "$RESOURCES/WeChat-Multi-Launch.command"
rm -rf "$RESOURCES/wechat_icons"
cp -R "$REPO_DIR/wechat_icons" "$RESOURCES/wechat_icons"
# Build the app icon from the source PNG into a multi-resolution .icns.
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$GUI_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$GUI_DIR/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
rm -rf "$ICONSET"

print "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

print "Done: $APP"