#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILES=("$ROOT_DIR/.env" "$ROOT_DIR/.env.local")

for env_file in "${ENV_FILES[@]}"; do
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  fi
done

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <zip-or-app-path>" >&2
  exit 1
fi

if [[ ! -e "$TARGET" ]]; then
  echo "Notarization target not found: $TARGET" >&2
  exit 1
fi

: "${NOTARY_KEY_ID:?NOTARY_KEY_ID is not set}"
: "${NOTARY_ISSUER_ID:?NOTARY_ISSUER_ID is not set}"
: "${NOTARY_KEY_PATH:?NOTARY_KEY_PATH is not set}"

if [[ ! -f "$NOTARY_KEY_PATH" ]]; then
  echo "Notary API key not found at: $NOTARY_KEY_PATH" >&2
  exit 1
fi

xcrun notarytool submit "$TARGET" \
  --key "$NOTARY_KEY_PATH" \
  --key-id "$NOTARY_KEY_ID" \
  --issuer "$NOTARY_ISSUER_ID" \
  --wait
