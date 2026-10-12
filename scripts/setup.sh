#!/usr/bin/env bash
# One-time setup: install the runtime's dependencies, verify it compiles, and
# fetch the SDK declarations. Safe to re-run.
set -euo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ensure_node || {
  echo "agent-canvas: node is required (install via nvm or your package manager)." >&2
  exit 1
}

cd "$CANVAS_RUNTIME_DIR"
if command -v pnpm >/dev/null 2>&1; then
  pnpm install --frozen-lockfile
elif command -v corepack >/dev/null 2>&1; then
  corepack pnpm install --frozen-lockfile
else
  echo "agent-canvas: pnpm not found; falling back to npm (lockfile will be ignored)." >&2
  npm install
fi

./node_modules/.bin/tsc --noEmit -p tsconfig.json
echo "runtime ready at $CANVAS_RUNTIME_DIR"

"$CANVAS_HOME/scripts/fetch-sdk.sh" || true

# Put `canvas` on PATH when ~/.local/bin is the conventional user bin dir.
if [ -d "$HOME/.local/bin" ]; then
  ln -sfn "$CANVAS_HOME/scripts/canvas" "$HOME/.local/bin/canvas"
  echo "linked ~/.local/bin/canvas -> $CANVAS_HOME/scripts/canvas"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "note: ~/.local/bin is not on your PATH; add it, or call $CANVAS_HOME/scripts/canvas directly." ;;
  esac
fi

cat <<EOF

Next steps:
  canvas install cursor     register the skill and hook with the Cursor CLI
  canvas install claude     register the skill and hook with Claude Code
  canvas config             show the effective configuration
Sharing (optional): (cd $CANVAS_RUNTIME_DIR && ./node_modules/.bin/wrangler login)
EOF
