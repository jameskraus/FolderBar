#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
CONFIG="${1:-${CONFIG:-debug}}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
BUNDLE_ID="${BUNDLE_ID:-com.folderbar.app}"
ICON_NAME="AppIcon"
ICON_SOURCE_DIR="$ROOT_DIR/Assets/AppIcon.icon"
ICON_SOURCE_PNG="$ICON_SOURCE_DIR/Assets/FolderBar.png"
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
DEFAULT_SPARKLE_FEED_URL="https://raw.githubusercontent.com/jameskraus/FolderBar/main/appcast.xml"

SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

if [[ "$CONFIG" == "release" ]]; then
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    echo "SIGNING_IDENTITY is required for release builds (Developer ID Application recommended)" >&2
    exit 1
  fi
  if [[ "$SIGN_ADHOC" == "1" ]]; then
    echo "SIGN_ADHOC must be 0 for release builds" >&2
    exit 1
  fi

  SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-$DEFAULT_SPARKLE_FEED_URL}"
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SPARKLE_PUBLIC_ED_KEY is not set (required for release builds)" >&2
    exit 1
  fi
fi

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
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
ICONSET_DIR="$OUTPUT_DIR/$ICON_NAME.iconset"
ICON_OUTPUT="$RESOURCES_DIR/$ICON_NAME.icns"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

SPARKLE_FRAMEWORK_SOURCE="$BIN_DIR/Sparkle.framework"
SPARKLE_FRAMEWORK_DEST="$FRAMEWORKS_DIR/Sparkle.framework"

if [[ ! -d "$SPARKLE_FRAMEWORK_SOURCE" ]]; then
  echo "Sparkle.framework not found at expected path: $SPARKLE_FRAMEWORK_SOURCE" >&2
  exit 1
fi

ditto "$SPARKLE_FRAMEWORK_SOURCE" "$SPARKLE_FRAMEWORK_DEST"

if ! otool -l "$MACOS_DIR/$APP_NAME" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME"
fi

if [[ ! -f "$ICON_SOURCE_PNG" ]]; then
  echo "Icon source image not found: $ICON_SOURCE_PNG" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICON_OUTPUT"

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
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME.icns</string>
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
  <key>SUEnableAutomaticChecks</key>
  <false/>
  <key>SUFeedURL</key>
  <string>$SPARKLE_FEED_URL</string>
  <key>SUPublicEDKey</key>
  <string>$SPARKLE_PUBLIC_ED_KEY</string>
</dict>
</plist>
PLIST

sign_path() {
  local path="$1"
  /usr/bin/codesign "${SIGNING_ARGS[@]}" "$path"
}

sign_sparkle_framework() {
  local sparkle="$1"
  if [[ ! -d "$sparkle" ]]; then
    return 0
  fi

  while IFS= read -r -d '' container; do
    local macos_dir="$container/Contents/MacOS"
    if [[ -d "$macos_dir" ]]; then
      while IFS= read -r -d '' executable; do
        sign_path "$executable"
      done < <(find "$macos_dir" -type f -perm -111 -print0)
    fi
  done < <(find "$sparkle" -type d \( -name "*.xpc" -o -name "*.app" \) -print0)

  while IFS= read -r -d '' container; do
    sign_path "$container"
  done < <(find "$sparkle" -type d \( -name "*.xpc" -o -name "*.app" \) -print0)

  while IFS= read -r -d '' executable; do
    sign_path "$executable"
  done < <(find "$sparkle/Versions" -maxdepth 2 -type f -perm -111 -print0)

  sign_path "$sparkle"
}

if [[ -n "$SIGNING_IDENTITY" ]]; then
  echo "Signing app with identity: $SIGNING_IDENTITY"
  SIGNING_ARGS=(--force --sign "$SIGNING_IDENTITY")
  if [[ -n "$SIGNING_FLAGS" ]]; then
    # shellcheck disable=SC2206
    SIGNING_ARGS+=($SIGNING_FLAGS)
  fi
  sign_sparkle_framework "$SPARKLE_FRAMEWORK_DEST"
  sign_path "$APP_DIR"
elif [[ "$SIGN_ADHOC" == "1" ]]; then
  echo "Ad-hoc signing app (set SIGNING_IDENTITY for Developer ID signing)"
  SIGNING_ARGS=(--force --sign -)
  sign_sparkle_framework "$SPARKLE_FRAMEWORK_DEST"
  sign_path "$APP_DIR"
else
  echo "Skipping code signing (set SIGNING_IDENTITY or SIGN_ADHOC=1 to sign)"
fi

echo "Packaged $APP_DIR"
