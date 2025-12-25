#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
PACKAGE_SCRIPT="$ROOT_DIR/Scripts/package_app.sh"
NOTARIZE_SCRIPT="$ROOT_DIR/Scripts/notarize.sh"
DMG_SCRIPT="$ROOT_DIR/Scripts/package_dmg.sh"
APPCAST_PATH="$ROOT_DIR/appcast.xml"
UPDATE_APPCAST_SCRIPT="$ROOT_DIR/Scripts/update_appcast.py"
APPCAST_RELATIVE_PATH="appcast.xml"
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
TAG="v$VERSION"
RELEASE_TITLE="${RELEASE_TITLE:-$APP_NAME $VERSION}"
RELEASE_NOTES="${RELEASE_NOTES:-}"
FORCE_TAG="${FORCE_TAG:-0}"
FORCE_RELEASE="${FORCE_RELEASE:-0}"
SKIP_PUBLISH="${SKIP_PUBLISH:-0}"
SPARKLE_ED_PRIVATE_KEY_FILE="${SPARKLE_ED_PRIVATE_KEY_FILE:-}"
SIGN_UPDATE_BIN="${SIGN_UPDATE_BIN:-}"
REPO_OWNER="${REPO_OWNER:-jameskraus}"
REPO_NAME="${REPO_NAME:-FolderBar}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-11.0}"

RELEASE_SIGNING_IDENTITY="${RELEASE_SIGNING_IDENTITY:-${SIGNING_IDENTITY:-}}"

if [[ -z "$RELEASE_SIGNING_IDENTITY" ]]; then
  echo "RELEASE_SIGNING_IDENTITY is not set (Developer ID Application identity required)" >&2
  exit 1
fi

if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY is not set (required for release builds; see README Updates (Sparkle))" >&2
  exit 1
fi

if [[ ! -f "$APPCAST_PATH" ]]; then
  echo "appcast.xml not found: $APPCAST_PATH" >&2
  exit 1
fi

if [[ ! -f "$UPDATE_APPCAST_SCRIPT" ]]; then
  echo "Appcast updater script not found: $UPDATE_APPCAST_SCRIPT" >&2
  exit 1
fi

current_branch="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "main" ]]; then
  echo "Refusing to release from non-main branch: $current_branch" >&2
  exit 1
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Working tree is not clean; commit/stash before releasing." >&2
  exit 1
fi

if [[ "$(git -C "$ROOT_DIR" rev-parse HEAD)" != "$(git -C "$ROOT_DIR" rev-parse @{u})" ]]; then
  echo "Local branch is not up to date with upstream; run 'git pull --rebase' first." >&2
  exit 1
fi

if [[ "$SKIP_PUBLISH" != "1" ]]; then
  if [[ -n "$SPARKLE_ED_PRIVATE_KEY_FILE" && ! -f "$SPARKLE_ED_PRIVATE_KEY_FILE" ]]; then
    echo "SPARKLE_ED_PRIVATE_KEY_FILE not found: $SPARKLE_ED_PRIVATE_KEY_FILE" >&2
    exit 1
  fi

  if [[ -z "$SIGN_UPDATE_BIN" ]]; then
    if command -v sign_update >/dev/null 2>&1; then
      SIGN_UPDATE_BIN="$(command -v sign_update)"
    elif [[ -x "/Applications/Sparkle.app/Contents/Resources/bin/sign_update" ]]; then
      SIGN_UPDATE_BIN="/Applications/Sparkle.app/Contents/Resources/bin/sign_update"
    elif [[ -x "/opt/homebrew/Caskroom/sparkle/2.8.1/bin/sign_update" ]]; then
      SIGN_UPDATE_BIN="/opt/homebrew/Caskroom/sparkle/2.8.1/bin/sign_update"
    else
      for candidate in /opt/homebrew/Caskroom/sparkle/*/bin/sign_update; do
        if [[ -x "$candidate" ]]; then
          SIGN_UPDATE_BIN="$candidate"
          break
        fi
      done
    fi
  fi

  if [[ -z "$SIGN_UPDATE_BIN" || ! -x "$SIGN_UPDATE_BIN" ]]; then
    echo "sign_update tool not found. Install Sparkle (brew install --cask sparkle) or set SIGN_UPDATE_BIN." >&2
    exit 1
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI 'gh' not found; install it to publish releases." >&2
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "'gh' is not authenticated; run 'gh auth login'." >&2
    exit 1
  fi
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

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Release build dirtied the working tree; refusing to continue." >&2
  exit 1
fi

if [[ "$SKIP_PUBLISH" == "1" ]]; then
  echo "Skipping publish steps (SKIP_PUBLISH=1)."
  echo "Release artifacts:"
  echo "  $FINAL_ZIP"
  echo "  $FINAL_DMG"
  exit 0
fi

if git -C "$ROOT_DIR" rev-parse "$TAG" >/dev/null 2>&1; then
  if [[ "$FORCE_TAG" != "1" ]]; then
    echo "Git tag already exists: $TAG (set FORCE_TAG=1 to replace)" >&2
    exit 1
  fi
  git -C "$ROOT_DIR" tag -f "$TAG"
else
  git -C "$ROOT_DIR" tag "$TAG"
fi

if [[ "$FORCE_TAG" == "1" ]]; then
  git -C "$ROOT_DIR" push --force origin "$TAG"
else
  git -C "$ROOT_DIR" push origin "$TAG"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  if [[ "$FORCE_RELEASE" != "1" ]]; then
    echo "GitHub release already exists: $TAG (set FORCE_RELEASE=1 to upload assets with --clobber)" >&2
    exit 1
  fi
  gh release upload "$TAG" "$FINAL_ZIP" "$FINAL_DMG" --clobber
else
  notes_args=()
  if [[ -n "$RELEASE_NOTES" ]]; then
    notes_args+=(--notes "$RELEASE_NOTES")
  else
    notes_args+=(--notes "Release $VERSION")
  fi
  gh release create "$TAG" "$FINAL_ZIP" "$FINAL_DMG" --title "$RELEASE_TITLE" "${notes_args[@]}"
fi

sign_update_args=()
if [[ -n "$SPARKLE_ED_PRIVATE_KEY_FILE" ]]; then
  sign_update_args=(--ed-key-file "$SPARKLE_ED_PRIVATE_KEY_FILE")
fi

signature="$("$SIGN_UPDATE_BIN" -p "${sign_update_args[@]}" "$FINAL_ZIP" | tr -d '\n' | xargs)"
if [[ -z "$signature" ]]; then
  echo "Failed to generate Sparkle signature (sign_update returned empty output)" >&2
  exit 1
fi

size="$(stat -f%z "$FINAL_ZIP")"
pubdate="$(LC_ALL=C date '+%a, %d %b %Y %H:%M:%S %z')"
enclosure_url="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/$APP_NAME-$VERSION.zip"

python3 "$UPDATE_APPCAST_SCRIPT" \
  --appcast "$APPCAST_PATH" \
  --version "$VERSION" \
  --pubdate "$pubdate" \
  --min-system-version "$MIN_SYSTEM_VERSION" \
  --url "$enclosure_url" \
  --length "$size" \
  --signature "$signature"

if ! git -C "$ROOT_DIR" diff --quiet -- "$APPCAST_RELATIVE_PATH"; then
  git -C "$ROOT_DIR" add "$APPCAST_RELATIVE_PATH"
  git -C "$ROOT_DIR" commit -m "docs: update appcast for $VERSION"
  git -C "$ROOT_DIR" push origin main
fi

echo "Release artifacts:"
echo "  $FINAL_ZIP"
echo "  $FINAL_DMG"
echo "Git tag:"
echo "  $TAG"
