#!/usr/bin/env bash
# Install the tool: runtime dependencies, SDK declarations, the `canvas` command.
#
# Usage: setup.sh [--into <dir>] [--quiet]
#
# Without --into, this checkout becomes the tool home (developer install).
# With --into, the checkout is first synced to <dir> (minus .git, node_modules
# and local state) and <dir> becomes the tool home; this is how the hooks
# install from a plugin manager's cache into a stable location. Either way the
# location is recorded in the config file so hooks anywhere can find it.
set -euo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SOURCE="$(cd "$(dirname "$(real_path "${BASH_SOURCE[0]}")")/.." && pwd)"
target="$SOURCE"
quiet=0

while [ $# -gt 0 ]; do
  case "$1" in
    --into) target="${2:-}"; shift 2 ;;
    --quiet) quiet=1; shift ;;
    -h | --help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "setup: unknown option $1" >&2; exit 64 ;;
  esac
done
target="${target/#\~/$HOME}"

say() { [ "$quiet" -eq 1 ] || echo "$@"; }

ensure_node || {
  echo "agent-canvas: node is required (install via nvm or your package manager)." >&2
  exit 1
}

# Sync the checkout into the target when installing somewhere else.
managed=false
if [ "$(cd "$target" 2>/dev/null && pwd || echo "$target")" != "$SOURCE" ]; then
  managed=true
  mkdir -p "$target"
  say "syncing $SOURCE -> $target"
  tar -C "$SOURCE" \
    --exclude=./.git --exclude=./.github \
    --exclude=./runtime/node_modules --exclude=./runtime/.export-dist --exclude=./runtime/.wrangler \
    --exclude='./runtime/.server.*' --exclude=./runtime/.canvas-errors.log \
    --exclude=./runtime/.opened-canvases --exclude=./runtime/.published.jsonl \
    -cf - . | tar -C "$target" -xf -
fi

cd "$target/runtime"
install_log="$(mktemp)"
run_install() {
  if command -v pnpm >/dev/null 2>&1; then
    pnpm install --frozen-lockfile
  elif command -v corepack >/dev/null 2>&1 && corepack pnpm --version >/dev/null 2>&1; then
    corepack pnpm install --frozen-lockfile
  elif command -v npx >/dev/null 2>&1; then
    npx --yes pnpm@11 install --frozen-lockfile
  else
    say "agent-canvas: pnpm not found; falling back to npm (lockfile will be ignored)."
    npm install
  fi
}
if [ "$quiet" -eq 1 ]; then
  run_install >"$install_log" 2>&1 || { tail -n 20 "$install_log" >&2; rm -f "$install_log"; exit 1; }
else
  run_install
fi
rm -f "$install_log"

./node_modules/.bin/tsc --noEmit -p tsconfig.json
say "runtime ready at $target/runtime"

CANVAS_HOME="$target" "$target/scripts/fetch-sdk.sh" >/dev/null 2>&1 && say "SDK declarations in $target/sdk" || say "note: SDK declarations could not be fetched (component discovery falls back to the shim source)."

config_set home "$target"
config_set managed "$managed"
config_set version "$(plugin_version_of "$target")"
say "recorded home=$target in $CANVAS_CONFIG_FILE"

# Put `canvas` on PATH when ~/.local/bin is the conventional user bin dir.
if [ -d "$HOME/.local/bin" ]; then
  ln -sfn "$target/scripts/canvas" "$HOME/.local/bin/canvas"
  say "linked ~/.local/bin/canvas -> $target/scripts/canvas"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) say "note: ~/.local/bin is not on your PATH; add it, or call $target/scripts/canvas directly." ;;
  esac
fi

[ "$quiet" -eq 1 ] && exit 0
cat <<EOF

Next steps (skip if you installed the plugin through a marketplace; its hooks are already registered):
  canvas install cursor     register the skill and hook with the Cursor CLI
  canvas install claude     register the skill and hook with Claude Code
  canvas config             show the effective configuration
Sharing (optional): (cd $target/runtime && ./node_modules/.bin/wrangler login)
EOF
