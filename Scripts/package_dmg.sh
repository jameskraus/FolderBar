#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
APP_DIR="${APP_DIR:-$OUTPUT_DIR/$APP_NAME.app}"
DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-$APP_NAME Installer}"
DMG_BACKGROUND="${DMG_BACKGROUND:-$ROOT_DIR/Assets/Installer/FolderBar-DMG-Background@2x.png}"
VERSION_FILE="$ROOT_DIR/version.env"
ENV_FILES=("$ROOT_DIR/.env")

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
DMG_PATH="${DMG_PATH:-$OUTPUT_DIR/$APP_NAME-$VERSION.dmg}"
DMG_RW_PATH="${DMG_RW_PATH:-$OUTPUT_DIR/$APP_NAME-$VERSION-rw.dmg}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${OUTPUT_DIR}/dmg.XXXX")"

cleanup() {
  if [[ -n "${MOUNT_DIR:-}" && -d "$MOUNT_DIR" ]]; then
    if mount | grep -q "$MOUNT_DIR"; then
      /usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null || true
    fi
    rm -rf "$MOUNT_DIR"
  fi
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
if [[ -f "$DMG_BACKGROUND" ]]; then
  bg_basename="$(basename "$DMG_BACKGROUND")"
  mkdir -p "$STAGING_DIR/.background"
  cp "$DMG_BACKGROUND" "$STAGING_DIR/.background/$bg_basename"

  if [[ -d "/Volumes/$DMG_VOLUME_NAME" ]]; then
    /usr/bin/hdiutil detach "/Volumes/$DMG_VOLUME_NAME" >/dev/null || true
  fi

  /usr/bin/hdiutil create -srcfolder "$STAGING_DIR" -volname "$DMG_VOLUME_NAME" -ov -format UDRW "$DMG_RW_PATH" >/dev/null
  attach_output="$(/usr/bin/hdiutil attach "$DMG_RW_PATH" -noverify -nobrowse)"
  MOUNT_DIR="$(echo "$attach_output" | awk -F $'\t' '/\/Volumes\// {print $NF; exit}')"
  if [[ -z "$MOUNT_DIR" ]]; then
    echo "Failed to determine mount point for DMG." >&2
    exit 1
  fi

  /usr/bin/osascript <<EOF
tell application "Finder"
  repeat 30 times
    if exists disk "$DMG_VOLUME_NAME" then exit repeat
    delay 0.2
  end repeat
  tell disk "$DMG_VOLUME_NAME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {240, 240, 1020, 720}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to (POSIX file "$MOUNT_DIR/.background/$bg_basename") as alias
    set position of item "Applications" of container window to {580, 220}
    set position of item "$APP_NAME.app" of container window to {200, 220}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
EOF

  /usr/bin/hdiutil detach "$MOUNT_DIR" >/dev/null
  /usr/bin/hdiutil convert "$DMG_RW_PATH" -format UDZO -ov -o "$DMG_PATH" >/dev/null
  rm -f "$DMG_RW_PATH"
else
  /usr/bin/hdiutil create -volname "$DMG_VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
fi

echo "DMG artifact: $DMG_PATH"
