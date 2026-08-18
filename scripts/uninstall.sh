#!/bin/bash
# Cleanly removes CorrectClick: quits running processes, disables and
# unregisters the Finder Sync extension, deletes the installed app, and
# clears saved preferences/state so the machine is back to a fresh-install
# state.
#
# Usage: ./scripts/uninstall.sh [--yes]
#   --yes   skip the confirmation prompt (for scripted/automated use)

set -e

APP_BUNDLE_ID="com.correctclick.CorrectClick"
EXT_BUNDLE_ID="com.correctclick.CorrectClick.FinderSyncExtension"
APP_PATH="/Applications/CorrectClick.app"
EXT_PATH="$APP_PATH/Contents/PlugIns/CorrectClickExtension.appex"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

AUTO_YES=false
[ "$1" = "--yes" ] && AUTO_YES=true

confirm() {
  $AUTO_YES && return 0
  read -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

echo "This will remove CorrectClick and all its saved state:"
echo "  - $APP_PATH"
echo "  - Finder Sync extension registration"
echo "  - Preferences and sandbox container data"
echo ""
confirm "Continue?" || { echo "Aborted."; exit 0; }

echo ""
echo "=== Quitting CorrectClick ==="
osascript -e 'tell application "CorrectClick" to quit' 2>/dev/null || true
pkill -f "$APP_PATH/Contents/MacOS/CorrectClick" 2>/dev/null || true
pkill -f "CorrectClickExtension.appex/Contents/MacOS/CorrectClickExtension" 2>/dev/null || true
sleep 1

echo "=== Disabling and unregistering the Finder Sync extension ==="
pluginkit -e ignore -i "$EXT_BUNDLE_ID" 2>/dev/null || true
if [ -d "$EXT_PATH" ]; then
  pluginkit -r "$EXT_PATH" 2>/dev/null || true
fi

echo "=== Unregistering from Launch Services ==="
if [ -d "$APP_PATH" ]; then
  "$LSREGISTER" -u "$APP_PATH" 2>/dev/null || true
fi

echo "=== Removing app bundle ==="
if [ -d "$APP_PATH" ]; then
  rm -rf "$APP_PATH"
  echo "Removed $APP_PATH"
else
  echo "Not installed at $APP_PATH — skipping"
fi

echo "=== Removing preferences and sandbox container data ==="
rm -f ~/Library/Preferences/"$APP_BUNDLE_ID".plist
CONTAINERS_FAILED=false
rm -rf ~/Library/Containers/"$APP_BUNDLE_ID" 2>/dev/null || CONTAINERS_FAILED=true
rm -rf ~/Library/Containers/"$EXT_BUNDLE_ID" 2>/dev/null || CONTAINERS_FAILED=true
rm -rf ~/Library/Saved\ Application\ State/"$APP_BUNDLE_ID".savedState 2>/dev/null || true

if $CONTAINERS_FAILED; then
  echo "Warning: couldn't remove ~/Library/Containers/$APP_BUNDLE_ID (macOS protects sandbox"
  echo "containers from Terminal by default). To finish clearing it, either:"
  echo "  - grant your terminal app Full Disk Access in System Settings > Privacy & Security,"
  echo "    then re-run this script, or"
  echo "  - delete it manually in Finder (Cmd+Shift+G to jump to ~/Library/Containers)."
  echo "This is just leftover preference data — the app itself is fully uninstalled."
fi

echo "=== Relaunching Finder ==="
killall Finder 2>/dev/null || true

echo ""
echo "Done. CorrectClick has been fully removed."
