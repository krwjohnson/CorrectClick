#!/bin/bash
# Generates all icon sizes from a 1024x1024 source PNG and produces an .icns file.
# Usage: ./scripts/build_icns.sh

set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO/scripts/iconbuild/icon_1024.png"
ICONSET="$REPO/scripts/iconbuild/AppIcon.iconset"
DEST_ICNS="$REPO/scripts/iconbuild/AppIcon.icns"
DEST_ASSET="$REPO/CorrectClick/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$ICONSET"

sips -z 16   16   "$SRC" --out "$ICONSET/icon_16x16.png"        > /dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_16x16@2x.png"     > /dev/null
sips -z 32   32   "$SRC" --out "$ICONSET/icon_32x32.png"        > /dev/null
sips -z 64   64   "$SRC" --out "$ICONSET/icon_32x32@2x.png"     > /dev/null
sips -z 128  128  "$SRC" --out "$ICONSET/icon_128x128.png"      > /dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_128x128@2x.png"   > /dev/null
sips -z 256  256  "$SRC" --out "$ICONSET/icon_256x256.png"      > /dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_256x256@2x.png"   > /dev/null
sips -z 512  512  "$SRC" --out "$ICONSET/icon_512x512.png"      > /dev/null
cp "$SRC"                      "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$DEST_ICNS"
echo "Built $DEST_ICNS"

# Copy all sizes into the Xcode asset catalog
cp "$ICONSET/icon_16x16.png"      "$DEST_ASSET/icon_16x16.png"
cp "$ICONSET/icon_16x16@2x.png"   "$DEST_ASSET/icon_16x16@2x.png"
cp "$ICONSET/icon_32x32.png"      "$DEST_ASSET/icon_32x32.png"
cp "$ICONSET/icon_32x32@2x.png"   "$DEST_ASSET/icon_32x32@2x.png"
cp "$ICONSET/icon_128x128.png"    "$DEST_ASSET/icon_128x128.png"
cp "$ICONSET/icon_128x128@2x.png" "$DEST_ASSET/icon_128x128@2x.png"
cp "$ICONSET/icon_256x256.png"    "$DEST_ASSET/icon_256x256.png"
cp "$ICONSET/icon_256x256@2x.png" "$DEST_ASSET/icon_256x256@2x.png"
cp "$ICONSET/icon_512x512.png"    "$DEST_ASSET/icon_512x512.png"
cp "$ICONSET/icon_512x512@2x.png" "$DEST_ASSET/icon_512x512@2x.png"
echo "Copied PNGs to asset catalog"
