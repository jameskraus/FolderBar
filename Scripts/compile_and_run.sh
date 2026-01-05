#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="FolderBar"
CONFIG="${1:-${CONFIG:-debug}}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
PACKAGE_SCRIPT="$ROOT_DIR/Scripts/package_app.sh"
ENV_FILES=("$ROOT_DIR/.env")
BUNDLE_ID="${BUNDLE_ID:-com.folderbar.app}"

cd "$ROOT_DIR"

for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

APP_DIR="$OUTPUT_DIR/$APP_NAME.app"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  for _ in {1..50}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  sleep 0.2
fi

"$PACKAGE_SCRIPT" "$CONFIG"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

max_attempts=5
for attempt in $(seq 1 "$max_attempts"); do
  set +e
  out="$(open -n -g "$APP_DIR" 2>&1)"
  status=$?
  set -e

  if [[ $status -eq 0 ]]; then
    exit 0
  fi

  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "open failed (exit $status) but $APP_NAME is running; continuing." >&2
    if [[ -n "$out" ]]; then
      echo "$out" >&2
    fi
    exit 0
  fi

  if [[ "$out" == *"-600"* ]]; then
    echo "open hit LaunchServices -600; retry $attempt/$max_attempts..." >&2
    if [[ -n "$out" ]]; then
      echo "$out" >&2
    fi
    sleep 0.25
    continue
  fi

  if [[ -n "$out" ]]; then
    echo "$out" >&2
  fi
  exit "$status"
done

echo "Failed to launch $APP_NAME after $max_attempts attempts." >&2
exit 1
