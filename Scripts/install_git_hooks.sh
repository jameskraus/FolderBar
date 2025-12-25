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

if [[ -f "$TARGET_HOOK" ]] && ! grep -qE '\.githooks/pre-push' "$TARGET_HOOK" 2>/dev/null; then
  backup="$TARGET_HOOK.backup.$(date +%Y%m%d%H%M%S)"
  cp "$TARGET_HOOK" "$backup"
  echo "Backed up existing pre-push hook to: $backup" >&2
fi

cat >"$TARGET_HOOK" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/.githooks/pre-push" "$@"
EOF

chmod +x "$TARGET_HOOK" "$SOURCE_HOOK"

echo "Installed pre-push hook: $TARGET_HOOK" >&2
echo "To skip once: git push --no-verify (or SKIP_SWIFTLINT=1 git push)" >&2

