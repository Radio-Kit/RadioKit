#!/usr/bin/env bash
# Build the rk-arduino library ZIP for bundling as a Flutter asset.
# Run from the repo root: bash scripts/build-library-zip.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_DIR="$REPO_ROOT/rk-arduino"
OUT_DIR="$REPO_ROOT/radiokit-app/assets"
OUT_FILE="$OUT_DIR/rk-arduino.zip"

if [ ! -d "$SRC_DIR" ]; then
  echo "Error: $SRC_DIR not found" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Remove old ZIP if it exists
rm -f "$OUT_FILE"

# Create ZIP from the rk-arduino directory, storing paths relative to it
# Exclude IDE/build config files that aren't needed for library distribution
(cd "$SRC_DIR" && zip -r "$OUT_FILE" . \
  -x '*.pio/*' \
  -x '.cache/*' \
  -x '.vscode/*' \
  -x 'compile_commands.json' \
  -x '.clangd' \
  -x '.clang-format')

echo "Created $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
