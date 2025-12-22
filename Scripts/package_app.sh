#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
CONFIG="${1:-${CONFIG:-debug}}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
BUNDLE_ID="${BUNDLE_ID:-com.folderbar.app}"
VERSION="${VERSION:-}"
VERSION_FILE="$ROOT_DIR/version.env"
ENV_FILES=("$ROOT_DIR/.env" "$ROOT_DIR/.env.local")
SIGNING_IDENTITY_ENV_VALUE="${SIGNING_IDENTITY-}"
SIGNING_IDENTITY_ENV_SET="${SIGNING_IDENTITY+1}"
SIGN_ADHOC_ENV_VALUE="${SIGN_ADHOC-}"
SIGN_ADHOC_ENV_SET="${SIGN_ADHOC+1}"
SIGNING_FLAGS_ENV_VALUE="${SIGNING_FLAGS-}"
SIGNING_FLAGS_ENV_SET="${SIGNING_FLAGS+1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY_ENV_VALUE:-}"
SIGN_ADHOC="${SIGN_ADHOC_ENV_VALUE:-1}"
SIGNING_FLAGS="${SIGNING_FLAGS_ENV_VALUE:-}"

cd "$ROOT_DIR"

for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

if [[ -n "$SIGNING_IDENTITY_ENV_SET" ]]; then
  SIGNING_IDENTITY="$SIGNING_IDENTITY_ENV_VALUE"
fi
if [[ -n "$SIGN_ADHOC_ENV_SET" ]]; then
  SIGN_ADHOC="$SIGN_ADHOC_ENV_VALUE"
fi
if [[ -n "$SIGNING_FLAGS_ENV_SET" ]]; then
  SIGNING_FLAGS="$SIGNING_FLAGS_ENV_VALUE"
fi

if [[ -f "$VERSION_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$VERSION_FILE"
fi

VERSION="${VERSION:-0.1.0}"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Executable not found: $EXECUTABLE" >&2
  exit 1
fi

APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing app with identity: $SIGNING_IDENTITY"
  SIGNING_ARGS=(--force --sign "$SIGNING_IDENTITY")
  if [[ -n "$SIGNING_FLAGS" ]]; then
    # shellcheck disable=SC2206
    SIGNING_ARGS+=($SIGNING_FLAGS)
  fi
  /usr/bin/codesign "${SIGNING_ARGS[@]}" "$APP_DIR"
elif [[ "$SIGN_ADHOC" == "1" ]]; then
  echo "Ad-hoc signing app (set SIGNING_IDENTITY for Developer ID signing)"
  /usr/bin/codesign --force --sign - "$APP_DIR"
else
  echo "Skipping code signing (set SIGNING_IDENTITY or SIGN_ADHOC=1 to sign)"
fi

echo "Packaged $APP_DIR"
