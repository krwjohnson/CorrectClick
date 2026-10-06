#!/bin/bash
# Sets the app version everywhere it's recorded, in one step:
#   - VERSION (the source of truth — CI releases whatever this says)
#   - project.yml's MARKETING_VERSION / CURRENT_PROJECT_VERSION (so local
#     Xcode builds report the same version a release build would)
#
# Usage: ./scripts/set_version.sh 1.2.3
# Then add release notes to RELEASE_NOTES.md and push to main to release.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
NEW="${1:-}"

if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 MAJOR.MINOR.PATCH (e.g. 1.2.3)" >&2
  exit 1
fi

echo "$NEW" > "$REPO/VERSION"
sed -i '' -E \
  -e "s/^( *MARKETING_VERSION: ).*/\1\"$NEW\"/" \
  -e "s/^( *CURRENT_PROJECT_VERSION: ).*/\1\"$NEW\"/" \
  "$REPO/project.yml"

echo "Version set to $NEW (VERSION, project.yml)."
