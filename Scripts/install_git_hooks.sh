#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d .git ]]; then
  echo "Not a git repository: $ROOT_DIR" >&2
  exit 1
fi

HOOKS_DIR="$ROOT_DIR/.git/hooks"
SOURCE_HOOK="$ROOT_DIR/.githooks/pre-push"
TARGET_HOOK="$HOOKS_DIR/pre-push"

if [[ ! -f "$SOURCE_HOOK" ]]; then
  echo "Missing hook source: $SOURCE_HOOK" >&2
  exit 1
fi

mkdir -p "$HOOKS_DIR"

chmod +x "$SOURCE_HOOK"

if [[ -f "$TARGET_HOOK" ]]; then
  if grep -qE '\.githooks/pre-push' "$TARGET_HOOK" 2>/dev/null; then
    echo "pre-push hook already invokes .githooks/pre-push; nothing to do." >&2
    exit 0
  fi

  backup="$TARGET_HOOK.backup.$(date +%Y%m%d%H%M%S)"
  cp "$TARGET_HOOK" "$backup"
  echo "Backed up existing pre-push hook to: $backup" >&2

  cat >>"$TARGET_HOOK" <<'EOF'

# FolderBar: repo-managed SwiftFormat + SwiftLint pre-push hook
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 1
"$ROOT/.githooks/pre-push" "$@" || exit $?
EOF

  chmod +x "$TARGET_HOOK"
  echo "Updated pre-push hook (appended): $TARGET_HOOK" >&2
else
  cat >"$TARGET_HOOK" <<'EOF'
#!/bin/sh
set -e

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 1
exec "$ROOT/.githooks/pre-push" "$@"
EOF

  chmod +x "$TARGET_HOOK"
  echo "Installed pre-push hook: $TARGET_HOOK" >&2
fi

echo "To skip once: git push --no-verify (or SKIP_SWIFTLINT=1 git push / SKIP_SWIFTFORMAT=1 git push)" >&2
