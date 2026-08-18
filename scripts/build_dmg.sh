#!/bin/bash
# Builds a release archive, exports the app, and packages it as a DMG.
# Usage: ./scripts/build_dmg.sh
#
# Prerequisites:
#   - Xcode with a valid Development Team set in the project
#   - create-dmg: brew install create-dmg
#
# To notarise after this script, see developer_documentation/06-distribution.md.

set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="1.0.0"
ARCHIVE="$REPO/build/CorrectClick.xcarchive"
EXPORT_DIR="$REPO/build/export"
DMG_OUT="$REPO/build/CorrectClick-${VERSION}.dmg"

mkdir -p "$REPO/build"

echo "=== Generating Xcode project ==="
cd "$REPO"
xcodegen generate

echo ""
echo "=== Archiving (Release) ==="
xcodebuild \
  -project CorrectClick.xcodeproj \
  -scheme CorrectClick \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  archive \
  | xcpretty 2>/dev/null || cat  # fall back to raw output if xcpretty not installed

echo ""
echo "=== Exporting ==="
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$REPO/scripts/ExportOptions.plist" \
  | xcpretty 2>/dev/null || cat

echo ""
echo "=== Building DMG ==="

if [ ! -d "$EXPORT_DIR" ]; then
  echo "ERROR: Export directory not found — archive/export step failed. Aborting DMG build."
  exit 1
fi

# Also drop a loose copy of the uninstaller in the DMG itself (not just inside
# the app bundle), as a fallback for when the installed app won't launch.
cp "$REPO/scripts/uninstall.sh" "$EXPORT_DIR/Uninstall CorrectClick.command"
chmod +x "$EXPORT_DIR/Uninstall CorrectClick.command"

# Remove previous DMG if it exists
rm -f "$DMG_OUT"

create-dmg \
  --volname "CorrectClick" \
  --volicon "$REPO/scripts/iconbuild/AppIcon.icns" \
  --window-pos 200 150 \
  --window-size 560 380 \
  --icon-size 128 \
  --icon "CorrectClick.app" 140 185 \
  --hide-extension "CorrectClick.app" \
  --app-drop-link 420 185 \
  --background "$REPO/scripts/dmg_background.png" \
  "$DMG_OUT" \
  "$EXPORT_DIR/"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_OUT"
echo ""
echo "Next steps (notarisation):"
echo "  xcrun notarytool submit '$DMG_OUT' --apple-id YOUR@EMAIL --team-id TEAMID --password APP_PASSWORD --wait"
echo "  xcrun stapler staple '$DMG_OUT'"
