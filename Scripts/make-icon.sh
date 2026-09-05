#!/bin/bash
# PlaceTimer simgesini uretir: cizim -> tum boyutlar -> .icns
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

ICONSET="build/AppIcon.iconset"
OUTPUT="Resources/AppIcon.icns"

rm -rf "$ICONSET"
mkdir -p "$ICONSET" Resources

echo "==> Simge ciziliyor"
swift Scripts/make-icon.swift "$ICONSET"

echo "==> .icns paketleniyor"
iconutil -c icns "$ICONSET" -o "$OUTPUT"

echo "==> Hazir: $OUTPUT"
