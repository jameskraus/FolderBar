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
DEBUG_SETTINGS_ICON_SOURCE_DIR="$ROOT_DIR/Assets/AppIcon-Debug.icon"
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

output_dir_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$OUTPUT_DIR")"
root_dir_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$ROOT_DIR")"
if [[ -z "$output_dir_real" || "$output_dir_real" == "/" || "$output_dir_real" == "$root_dir_real" ]]; then
  echo "Refusing to clean unsafe OUTPUT_DIR: '$OUTPUT_DIR' -> '$output_dir_real'" >&2
  exit 1
fi
if [[ "$output_dir_real" != "$root_dir_real/"* ]]; then
  echo "Refusing to clean OUTPUT_DIR outside repo: '$OUTPUT_DIR' -> '$output_dir_real'" >&2
  exit 1
fi
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

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
DEBUG_SETTINGS_ICON_OUTPUT="$RESOURCES_DIR/SettingsHeaderIcon-Debug.png"

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

find_ictool() {
  local ictool_path="/Applications/Icon Composer.app/Contents/Executables/ictool"
  if [[ -x "$ictool_path" ]]; then
    echo "$ictool_path"
    return 0
  fi
  if command -v ictool >/dev/null 2>&1; then
    command -v ictool
    return 0
  fi
  return 1
}

ICTOOL="$(find_ictool || true)"

if [[ -n "$ICTOOL" && -d "$ICON_SOURCE_DIR" ]]; then
  ICON_WORK_DIR="$OUTPUT_DIR/icon_work"
  ICON_MASK_TOOL="$ICON_WORK_DIR/iconmask"
  ICON_MASK_SRC="$ICON_WORK_DIR/iconmask.swift"

  mkdir -p "$ICON_WORK_DIR"
  cat > "$ICON_MASK_SRC" <<'SWIFT'
import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

if CommandLine.arguments.count != 4 && CommandLine.arguments.count != 5 {
  fputs("Usage: iconmask <base.png> <mask.png> <out.png> [insetScale]\n", stderr)
  exit(2)
}

let baseURL = URL(fileURLWithPath: CommandLine.arguments[1])
let maskURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outURL = URL(fileURLWithPath: CommandLine.arguments[3])
let insetScale = (CommandLine.arguments.count == 5 ? Double(CommandLine.arguments[4]) : nil) ?? 1.0

guard let base = CIImage(contentsOf: baseURL), let mask = CIImage(contentsOf: maskURL) else {
  fputs("Failed to load input images\n", stderr)
  exit(1)
}

let extent = base.extent
let clear = CIImage(color: .clear).cropped(to: extent)
guard let filter = CIFilter(name: "CIBlendWithAlphaMask") else {
  fputs("Missing CIBlendWithAlphaMask\n", stderr)
  exit(1)
}
filter.setValue(base, forKey: kCIInputImageKey)
filter.setValue(clear, forKey: kCIInputBackgroundImageKey)
filter.setValue(mask, forKey: kCIInputMaskImageKey)
guard let output = filter.outputImage?.cropped(to: extent) else {
  fputs("Failed to render output\n", stderr)
  exit(1)
}

let finalImage: CIImage
if insetScale > 0 && insetScale < 1 {
  let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
  scaleFilter.setValue(output, forKey: kCIInputImageKey)
  scaleFilter.setValue(insetScale, forKey: kCIInputScaleKey)
  scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
  guard let scaled = scaleFilter.outputImage else {
    fputs("Failed to scale output\n", stderr)
    exit(1)
  }

  let tx = (extent.width - scaled.extent.width) / 2.0 - scaled.extent.origin.x
  let ty = (extent.height - scaled.extent.height) / 2.0 - scaled.extent.origin.y
  let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))

  let composite = CIFilter(name: "CISourceOverCompositing")!
  composite.setValue(centered, forKey: kCIInputImageKey)
  composite.setValue(clear, forKey: kCIInputBackgroundImageKey)
  finalImage = composite.outputImage!.cropped(to: extent)
} else {
  finalImage = output
}

let context = CIContext(options: [.useSoftwareRenderer: false])
guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else {
  fputs("Failed to create CGImage\n", stderr)
  exit(1)
}

guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
  fputs("Failed to create output destination\n", stderr)
  exit(1)
}
CGImageDestinationAddImage(dest, cgImage, nil)
if !CGImageDestinationFinalize(dest) {
  fputs("Failed to write output\n", stderr)
  exit(1)
}
SWIFT

  xcrun swiftc "$ICON_MASK_SRC" -O -o "$ICON_MASK_TOOL"

  render_icon_png() {
    local points="$1"
    local scale="$2"
    local out="$3"
    local base="$ICON_WORK_DIR/base_${points}_${scale}.png"
    local mask="$ICON_WORK_DIR/mask_${points}_${scale}.png"
    local source_doc="${4:-$ICON_SOURCE_DIR}"
    local inset_scale="${5:-${ICON_INSET_SCALE:-0.8125}}"

    "$ICTOOL" "$source_doc" \
      --export-image --output-file "$base" \
      --platform macOS --rendition Default \
      --width "$points" --height "$points" --scale "$scale" >/dev/null

    "$ICTOOL" "$source_doc" \
      --export-image --output-file "$mask" \
      --platform macOS --rendition ClearDark \
      --width "$points" --height "$points" --scale "$scale" >/dev/null

    "$ICON_MASK_TOOL" "$base" "$mask" "$out" "$inset_scale"
  }

  render_icon_png 16 1 "$ICONSET_DIR/icon_16x16.png"
  render_icon_png 16 2 "$ICONSET_DIR/icon_16x16@2x.png"
  render_icon_png 32 1 "$ICONSET_DIR/icon_32x32.png"
  render_icon_png 32 2 "$ICONSET_DIR/icon_32x32@2x.png"
  render_icon_png 128 1 "$ICONSET_DIR/icon_128x128.png"
  render_icon_png 128 2 "$ICONSET_DIR/icon_128x128@2x.png"
  render_icon_png 256 1 "$ICONSET_DIR/icon_256x256.png"
  render_icon_png 256 2 "$ICONSET_DIR/icon_256x256@2x.png"
  render_icon_png 512 1 "$ICONSET_DIR/icon_512x512.png"
  render_icon_png 512 2 "$ICONSET_DIR/icon_512x512@2x.png"

  if [[ "$CONFIG" == "debug" && -d "$DEBUG_SETTINGS_ICON_SOURCE_DIR" ]]; then
    render_icon_png 1024 1 "$DEBUG_SETTINGS_ICON_OUTPUT" "$DEBUG_SETTINGS_ICON_SOURCE_DIR" "1.0" || true
  fi
else
  echo "Warning: Icon Composer ictool not found; falling back to resizing $ICON_SOURCE_PNG" >&2
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

  if [[ "$CONFIG" == "debug" && -f "$DEBUG_SETTINGS_ICON_SOURCE_DIR/Assets/FolderBar-Debug.png" ]]; then
    cp "$DEBUG_SETTINGS_ICON_SOURCE_DIR/Assets/FolderBar-Debug.png" "$DEBUG_SETTINGS_ICON_OUTPUT" || true
  fi
fi
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
