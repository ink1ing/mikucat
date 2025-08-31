#!/usr/bin/env bash
set -euo pipefail

# Simple DMG packager for Mikucat (macOS)
# Usage:
#   tools/package_dmg.sh [path_to_app]
# If app path is not provided, tries common locations.

PROJ_ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$PROJ_ROOT_DIR/dist"
VOL_NAME="Mikucat"

APP_PATH="${1:-}"
if [[ -z "${APP_PATH}" ]]; then
  # Try common build output paths
  CANDIDATES=(
    "$PROJ_ROOT_DIR/build/Release/mikumac02.app"
    "$PROJ_ROOT_DIR/mikumac02/build/Release/mikumac02.app"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -d "$c" ]]; then APP_PATH="$c"; break; fi
  done
fi

if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "[!] Could not find mikumac02.app."
  echo "    Please build Release in Xcode, then run:"
  echo "    tools/package_dmg.sh /path/to/mikumac02.app"
  exit 1
fi

echo "[i] Using app: $APP_PATH"

# Read version from the built app's Info.plist
INFO_PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "[!] Info.plist not found in app bundle: $INFO_PLIST"
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "1.0")
DMG_NAME="${VOL_NAME}-${VERSION}.dmg"

mkdir -p "$DIST_DIR"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

DMG_ROOT="$WORK_DIR/${VOL_NAME}Root"
mkdir -p "$DMG_ROOT"

echo "[i] Staging files..."
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

OUT_DMG="$DIST_DIR/$DMG_NAME"
echo "[i] Creating DMG: $OUT_DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$OUT_DMG" >/dev/null

echo "[✓] DMG created at: $OUT_DMG"

