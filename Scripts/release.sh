#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
PACKAGE_SCRIPT="$ROOT_DIR/Scripts/package_app.sh"
NOTARIZE_SCRIPT="$ROOT_DIR/Scripts/notarize.sh"
DMG_SCRIPT="$ROOT_DIR/Scripts/package_dmg.sh"
VERSION_FILE="$ROOT_DIR/version.env"
ENV_FILES=("$ROOT_DIR/.env" "$ROOT_DIR/.env.local")

for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [[ -f "$VERSION_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$VERSION_FILE"
fi

VERSION="${VERSION:-0.1.0}"
RELEASE_SIGNING_IDENTITY="${RELEASE_SIGNING_IDENTITY:-${SIGNING_IDENTITY:-}}"

if [[ -z "$RELEASE_SIGNING_IDENTITY" ]]; then
  echo "RELEASE_SIGNING_IDENTITY is not set (Developer ID Application identity required)" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SIGNING_IDENTITY="$RELEASE_SIGNING_IDENTITY" \
SIGN_ADHOC=0 \
SIGNING_FLAGS="--options runtime --timestamp" \
CONFIG=release \
"$PACKAGE_SCRIPT" release

APP_DIR="$OUTPUT_DIR/$APP_NAME.app"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict "$APP_DIR"

NOTARY_ZIP="$OUTPUT_DIR/$APP_NAME-$VERSION-notarize.zip"
FINAL_ZIP="$OUTPUT_DIR/$APP_NAME-$VERSION.zip"
FINAL_DMG="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"

rm -f "$NOTARY_ZIP" "$FINAL_ZIP" "$FINAL_DMG"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ZIP"
"$NOTARIZE_SCRIPT" "$NOTARY_ZIP"
xcrun stapler staple "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$FINAL_ZIP"

"$DMG_SCRIPT"

echo "Release artifacts:"
echo "  $FINAL_ZIP"
echo "  $FINAL_DMG"
