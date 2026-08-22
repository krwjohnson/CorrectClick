#!/bin/bash
# Builds a release archive, exports the app, packages it as a DMG, and (when
# a real Developer ID export + notarization credentials are available)
# notarizes and staples both the app and the DMG.
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
# local/CI builds keep working before a Developer Team is configured. See
# developer_documentation/06-distribution.md and RELEASING.md for the full
# story on notarization setup.
#
# Notarization (optional — only runs for a real Developer ID export):
#   Set NOTARY_KEY_ID and NOTARY_ISSUER_ID, plus one of:
#     - NOTARY_API_KEY: the .p8 key file's contents, inline (for CI secrets)
#     - a key already sitting at ~/.appstoreconnect/private_keys/AuthKey_<NOTARY_KEY_ID>.p8
#       (Apple's own conventional location — the easy path for local runs)
#   Missing credentials just skip notarization with a warning; they don't
#   fail the build (matches the ad-hoc fallback's philosophy of never
#   blocking local/CI DMG builds on distribution-signing prerequisites).

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
EXPORTED_REAL=false
if xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$REPO/scripts/ExportOptions.plist"; then
  APP_SRC="$EXPORT_DIR/CorrectClick.app"
  EXPORTED_REAL=true
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
echo "=== Notarizing the app ==="
NOTARY_KEY_FILE=""
if [ "$EXPORTED_REAL" = true ] && [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ]; then
  if [ -n "${NOTARY_API_KEY:-}" ]; then
    # CI: key contents come from a secret — write to a scratch file that
    # lives only for this run, alongside the rest of build/ (gitignored).
    NOTARY_KEY_FILE="$REPO/build/AuthKey_${NOTARY_KEY_ID}.p8"
    printf '%s' "$NOTARY_API_KEY" > "$NOTARY_KEY_FILE"
  elif [ -f "$HOME/.appstoreconnect/private_keys/AuthKey_${NOTARY_KEY_ID}.p8" ]; then
    # Local dev: reuse the key already sitting in Apple's conventional spot.
    NOTARY_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${NOTARY_KEY_ID}.p8"
  fi
fi

if [ -n "$NOTARY_KEY_FILE" ]; then
  APP_ZIP="$REPO/build/CorrectClick.app.zip"
  ditto -c -k --keepParent "$APP_SRC" "$APP_ZIP"
  xcrun notarytool submit "$APP_ZIP" \
    --key "$NOTARY_KEY_FILE" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait
  xcrun stapler staple "$APP_SRC"
  rm -f "$APP_ZIP"
else
  if [ "$EXPORTED_REAL" = true ]; then
    echo "Skipping — NOTARY_KEY_ID/NOTARY_ISSUER_ID and a key (NOTARY_API_KEY or ~/.appstoreconnect/private_keys/) are needed. See RELEASING.md."
  else
    echo "Skipping — not a Developer ID export (ad-hoc build isn't notarizable)."
  fi
fi

echo ""
echo "=== Building DMG ==="
mkdir -p "$DMG_SRC_DIR"
cp -R "$APP_SRC" "$DMG_SRC_DIR/"

# Also drop a loose copy of the uninstaller in the DMG itself (not just inside
# the app bundle), as a fallback for when the installed app won't launch.
cp "$REPO/scripts/uninstall.sh" "$DMG_SRC_DIR/Uninstall CorrectClick.command"
chmod +x "$DMG_SRC_DIR/Uninstall CorrectClick.command"

# Build the DMG's volume icon on the fly from the already-committed asset
# catalog (scripts/iconbuild/ is gitignored — a local-only intermediate — so
# this can't depend on it existing, e.g. on a fresh CI checkout). iconutil
# requires the source directory to be named *.iconset, so copy into one.
VOLICONSET="$REPO/build/AppIcon.iconset"
VOLICON="$REPO/build/AppIcon.icns"
rm -rf "$VOLICONSET"
mkdir -p "$VOLICONSET"
cp "$REPO"/CorrectClick/Assets.xcassets/AppIcon.appiconset/icon_*.png "$VOLICONSET/"
iconutil -c icns "$VOLICONSET" -o "$VOLICON"

create-dmg \
  --volname "CorrectClick" \
  --volicon "$VOLICON" \
  --window-pos 200 150 \
  --window-size 560 380 \
  --icon-size 128 \
  --icon "CorrectClick.app" 140 185 \
  --hide-extension "CorrectClick.app" \
  --app-drop-link 420 185 \
  --background "$REPO/scripts/dmg_background.png" \
  "$DMG_OUT" \
  "$DMG_SRC_DIR/"

if [ -n "$NOTARY_KEY_FILE" ]; then
  echo ""
  echo "=== Notarizing the DMG ==="
  xcrun notarytool submit "$DMG_OUT" \
    --key "$NOTARY_KEY_FILE" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait
  xcrun stapler staple "$DMG_OUT"
  # Only ever a scratch copy written above from a CI secret — never remove a
  # key the user placed themselves in ~/.appstoreconnect/private_keys/.
  if [ "$NOTARY_KEY_FILE" = "$REPO/build/AuthKey_${NOTARY_KEY_ID}.p8" ]; then
    rm -f "$NOTARY_KEY_FILE"
  fi
fi

echo ""
echo "=== Done ==="
echo "DMG: $DMG_OUT"
if [ -z "$NOTARY_KEY_FILE" ]; then
  echo ""
  echo "Not notarized this run. To notarize manually:"
  echo "  xcrun notarytool submit '$DMG_OUT' --key-id KEYID --issuer ISSUERID --key /path/to/AuthKey_KEYID.p8 --wait"
  echo "  xcrun stapler staple '$DMG_OUT'"
fi
