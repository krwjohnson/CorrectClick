#!/bin/bash
# Generates/updates appcast.xml with an entry for a just-built release DMG,
# signed with the Sparkle EdDSA private key (Epic 3).
#
# Run after build_dmg.sh, with VERSION matching what it was built with.
# Requires SPARKLE_PRIVATE_KEY (the base64 EdDSA private key — see
# RELEASING.md for how it's generated/stored) and, optionally,
# SPARKLE_BIN_DIR pointing at an extracted Sparkle-X.Y.Z.tar.xz's bin/
# directory (defaults to build/sparkle_tools/bin, where CI downloads it).
#
# Usage: VERSION=1.2.3 SPARKLE_PRIVATE_KEY="..." ./scripts/generate_appcast.sh
#
# How this avoids needing every past release's DMG on disk: generate_appcast
# only discovers versions from files physically present in its target
# directory, but it also *merges into* an appcast.xml already there rather
# than rebuilding from scratch — so this script seeds that directory with
# the repo's current appcast.xml (if any) plus just the one new DMG, and
# copies the merged result back. Existing entries are left as they were;
# only the new version gets a freshly-signed entry.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:?VERSION env var is required}"
: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY env var is required (see RELEASING.md)}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-$REPO/build/sparkle_tools/bin}"
DMG="$REPO/build/CorrectClick-${VERSION}.dmg"
APPCAST_SRC_DIR="$REPO/build/appcast_source"
# Must match how `gh release create` names the uploaded asset in release.yml
# (the DMG's own basename) — GitHub's download URL is always
# .../releases/download/<tag>/<asset-filename>.
DOWNLOAD_PREFIX="https://github.com/krwjohnson/CorrectClick/releases/download/v${VERSION}/"

if [ ! -x "$SPARKLE_BIN_DIR/generate_appcast" ]; then
  echo "ERROR: generate_appcast not found at $SPARKLE_BIN_DIR." >&2
  echo "Download it from https://github.com/sparkle-project/Sparkle/releases (Sparkle-X.Y.Z.tar.xz, bin/generate_appcast)" >&2
  echo "or set SPARKLE_BIN_DIR to point at an already-extracted copy." >&2
  exit 1
fi

if [ ! -f "$DMG" ]; then
  echo "ERROR: $DMG not found — run scripts/build_dmg.sh (with the same VERSION) first." >&2
  exit 1
fi

rm -rf "$APPCAST_SRC_DIR"
mkdir -p "$APPCAST_SRC_DIR"
cp "$DMG" "$APPCAST_SRC_DIR/"
if [ -f "$REPO/appcast.xml" ]; then
  cp "$REPO/appcast.xml" "$APPCAST_SRC_DIR/"
fi

echo "=== Signing and generating appcast entry for $VERSION ==="
echo "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN_DIR/generate_appcast" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  "$APPCAST_SRC_DIR"

cp "$APPCAST_SRC_DIR/appcast.xml" "$REPO/appcast.xml"

echo ""
echo "=== Done ==="
echo "appcast.xml updated at $REPO/appcast.xml"
