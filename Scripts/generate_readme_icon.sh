#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ICON_SOURCE_DIR="${ICON_SOURCE_DIR:-$ROOT_DIR/Assets/AppIcon.icon}"
ICON_SOURCE_PNG="$ICON_SOURCE_DIR/Assets/FolderBar.png"

OUTPUT_PATH_DEFAULT="$ROOT_DIR/Assets/Readme/FolderBar.png"
OUTPUT_PATH="${1:-${OUTPUT_PATH:-$OUTPUT_PATH_DEFAULT}}"

README_ICON_POINTS="${README_ICON_POINTS:-1024}"
README_ICON_SCALE="${README_ICON_SCALE:-1}"
README_ICON_INSET_SCALE="${README_ICON_INSET_SCALE:-${ICON_INSET_SCALE:-0.8125}}"

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

if [[ ! -f "$ICON_SOURCE_PNG" ]]; then
  echo "Icon source image not found: $ICON_SOURCE_PNG" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/folderbar-readme-icon.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

ICON_MASK_TOOL="$WORK_DIR/iconmask"
ICON_MASK_SRC="$WORK_DIR/iconmask.swift"

cat >"$ICON_MASK_SRC" <<'SWIFT'
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

OUTPUT_TMP="$WORK_DIR/readme-icon.png"
BASE="$WORK_DIR/base.png"
MASK="$WORK_DIR/mask.png"

if [[ -n "$ICTOOL" && -d "$ICON_SOURCE_DIR" ]]; then
  "$ICTOOL" "$ICON_SOURCE_DIR" \
    --export-image --output-file "$BASE" \
    --platform macOS --rendition Default \
    --width "$README_ICON_POINTS" --height "$README_ICON_POINTS" --scale "$README_ICON_SCALE" >/dev/null

  "$ICTOOL" "$ICON_SOURCE_DIR" \
    --export-image --output-file "$MASK" \
    --platform macOS --rendition ClearDark \
    --width "$README_ICON_POINTS" --height "$README_ICON_POINTS" --scale "$README_ICON_SCALE" >/dev/null

  "$ICON_MASK_TOOL" "$BASE" "$MASK" "$OUTPUT_TMP" "$README_ICON_INSET_SCALE"
else
  echo "Warning: Icon Composer ictool not found; falling back to resizing $ICON_SOURCE_PNG" >&2
  out_px="$((README_ICON_POINTS * README_ICON_SCALE))"
  sips -z "$out_px" "$out_px" "$ICON_SOURCE_PNG" --out "$OUTPUT_TMP" >/dev/null
fi

mv -f "$OUTPUT_TMP" "$OUTPUT_PATH"
echo "Wrote $OUTPUT_PATH"

