#!/bin/bash
# Builds a release archive, exports the app, and packages it as a DMG.
# Usage: ./scripts/build_dmg.sh
#   VERSION env var overrides the version to build (defaults to the
#   repo-root VERSION file, e.g. for CI). Written into CFBundleShortVersionString
#   / CFBundleVersion via MARKETING_VERSION / CURRENT_PROJECT_VERSION.
#
# Prerequisites:
#   - xcodegen: brew install xcodegen
#   - create-dmg: brew install create-dmg
#
# Without a DEVELOPMENT_TEAM configured in project.yml, exportArchive can't
# produce a signed export ("No Team Found in Archive") — this script detects
# that and falls back to the ad-hoc-signed app straight from the archive, so
# local/CI builds keep working before notarisation is set up. See
# developer_documentation/06-distribution.md for notarising a real release.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-$(cat "$REPO/VERSION" 2>/dev/null || echo "1.0.0")}"
ARCHIVE="$REPO/build/CorrectClick.xcarchive"
EXPORT_DIR="$REPO/build/export"
DMG_SRC_DIR="$REPO/build/dmg_source"
DMG_OUT="$REPO/build/CorrectClick-${VERSION}.dmg"

# Start from a clean slate every time — a failed step must never leave a
# stale directory behind for a later step to mistake for fresh output.
rm -rf "$ARCHIVE" "$EXPORT_DIR" "$DMG_SRC_DIR" "$DMG_OUT"
mkdir -p "$REPO/build"

echo "=== Generating Xcode project ==="
cd "$REPO"
xcodegen generate

echo ""
echo "=== Archiving (Release, version $VERSION) ==="
xcodebuild \
  -project CorrectClick.xcodeproj \
  -scheme CorrectClick \
  -configuration Release \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$VERSION" \
  -archivePath "$ARCHIVE" \
  archive

echo ""
echo "=== Exporting ==="
if xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$REPO/scripts/ExportOptions.plist"; then
  APP_SRC="$EXPORT_DIR/CorrectClick.app"
else
  echo ""
  echo "exportArchive failed (likely no DEVELOPMENT_TEAM configured in project.yml yet)."
  echo "Falling back to the ad-hoc-signed app directly from the archive."
  APP_SRC="$ARCHIVE/Products/Applications/CorrectClick.app"
fi

if [ ! -d "$APP_SRC" ]; then
  echo "ERROR: no built app found at $APP_SRC. Aborting DMG build."
  exit 1
fi

echo ""
echo "=== Building DMG ==="
mkdir -p "$DMG_SRC_DIR"
cp -R "$APP_SRC" "$DMG_SRC_DIR/"

# Also drop a loose copy of the uninstaller in the DMG itself (not just inside
# the app bundle), as a fallback for when the installed app won't launch.
cp "$REPO/scripts/uninstall.sh" "$DMG_SRC_DIR/Uninstall CorrectClick.command"
chmod +x "$DMG_SRC_DIR/Uninstall CorrectClick.command"

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
  "$DMG_SRC_DIR/"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_OUT"
echo ""
echo "Next steps (notarisation):"
echo "  xcrun notarytool submit '$DMG_OUT' --apple-id YOUR@EMAIL --team-id TEAMID --password APP_PASSWORD --wait"
echo "  xcrun stapler staple '$DMG_OUT'"
