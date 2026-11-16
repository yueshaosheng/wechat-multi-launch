#!/bin/zsh
# Packages the built app into a drag-to-install DMG: the app on the left, an
# /Applications alias on the right, and a background arrow between them.
set -euo pipefail

GUI_DIR="${0:A:h}"
APP="$GUI_DIR/build/WeChat Multi Launch.app"
[[ -d "$APP" ]] || { print -u2 "App not built. Run build-app.sh first."; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
VOL="WeChat Multi Launch"
STAGE="$GUI_DIR/build/dmg-stage"
RW="$GUI_DIR/build/rw.dmg"
OUT="$GUI_DIR/build/WeChat-Multi-Launch-GUI-v${VERSION}.dmg"
MOUNT="/Volumes/$VOL"

print "Staging DMG contents..."
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$GUI_DIR/Resources/dmg-background.png" "$STAGE/.background/background.png"

print "Creating read-write image..."
hdiutil create -srcfolder "$STAGE" -volname "$VOL" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -o '/dev/disk[0-9]*' | head -1)

print "Laying out the install window..."
if ! osascript <<EOF
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set pathbar visible of container window to false
    set the icon size of the icon view options of container window to 128
    set the arrangement of the icon view options of container window to not arranged
    set the background picture of the icon view options of container window to (POSIX file "$MOUNT/.background/background.png" as alias)
    set position of item "WeChat Multi Launch.app" of container window to {150, 190}
    set position of item "Applications" of container window to {510, 190}
    set the bounds of container window to {100, 100, 760, 548}
    delay 0.5
    close
  end tell
end tell
EOF
then
  print -u2 "Warning: Finder layout failed; DMG will still install by dragging."
fi

sync
hdiutil detach "$DEVICE" >/dev/null
print "Compressing..."
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT" >/dev/null
rm -f "$RW"
rm -rf "$STAGE"
print "Done: $OUT"