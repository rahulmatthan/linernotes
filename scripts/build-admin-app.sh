#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/LinerNotes.xcodeproj"
SCHEME="LinerNotesAdmin"
CONFIG="Release"
DERIVED_DATA="$ROOT_DIR/.build-admin"
APP_NAME="LinerNotesAdmin.app"
OUTPUT_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIG/$APP_NAME"
FINAL_APP_PATH="$OUTPUT_DIR/$APP_NAME"

mkdir -p "$OUTPUT_DIR"

echo "Building $SCHEME ($CONFIG)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but app bundle was not found at:"
  echo "  $APP_PATH"
  exit 1
fi

rm -rf "$FINAL_APP_PATH"
cp -R "$APP_PATH" "$FINAL_APP_PATH"

echo
echo "Standalone app created:"
echo "  $FINAL_APP_PATH"
echo
echo "You can now drag it into /Applications."
