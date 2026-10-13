# shellcheck shell=bash
# shellcheck disable=SC2034  # variables here are consumed by the scripts that source this file
# Shared helpers for agent-canvas scripts. Source this file; do not execute it.
#
# Configuration precedence: environment variable, then
# ~/.config/agent-canvas/config.json, then the defaults below.
#
#   CANVAS_ROOT           Directory holding <workspace-slug>/canvases/*.canvas.tsx.
#                         Default: ~/.cursor/projects when it exists (keeps canvases
#                         where the Cursor IDE looks for them), else
#                         ~/.local/share/agent-canvas/projects.
#   CANVAS_THEME          "cursor" (default) or "oxide".
#   CANVAS_PORT           Local server port. Default 4817.
#   CANVAS_PAGES_PROJECT  Cloudflare Pages project for sharing. Default canvases-<user>.
#   CANVAS_HOME           Where the tool is installed (runtime/, scripts/, sdk/). See below.
#
# Plugin vs tool. Plugin managers (claude plugin install, agent plugin ...) copy
# this repository into a cache to get the skill and hooks, but never install the
# runtime there, and the cache is replaced on every update. The runtime
# therefore lives in exactly one stable place, the "tool home":
#   - managed: ${XDG_DATA_HOME:-~/.local/share}/agent-canvas/tool, installed and
#     kept in step with the plugin version by hooks/ensure-installed.sh;
#   - or a developer's checkout where `scripts/canvas setup` was run in place.
# Scripts and hooks resolve CANVAS_HOME rather than assuming it is beside them:
# CANVAS_HOME env, then `home` in the config file (written by setup), then the
# directory the `canvas` command on PATH points into, then this file's checkout.

CANVAS_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-canvas/config.json"
CANVAS_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/agent-canvas"
CANVAS_MANAGED_HOME="$CANVAS_DATA_DIR/tool"

# Read one key from the config file; empty when absent or unreadable.
config_get() {
  [ -f "$CANVAS_CONFIG_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg k "$1" '.[$k] // empty' "$CANVAS_CONFIG_FILE" 2>/dev/null
}

# Follow symlinks to a file's real path (portable; no readlink -f).
real_path() {
  local target="$1" dir
  while [ -L "$target" ]; do
    dir="$(cd "$(dirname "$target")" && pwd)"
    target="$(readlink "$target")"
    case "$target" in /*) ;; *) target="$dir/$target" ;; esac
  done
  printf '%s\n' "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}

is_tool_home() {
  [ -f "$1/scripts/lib.sh" ] && [ -d "$1/runtime" ]
}

runtime_installed_at() {
  [ -x "$1/runtime/node_modules/.bin/vite" ] && [ -x "$1/runtime/node_modules/.bin/tsc" ]
}

# Plugin version declared by a checkout (empty if unreadable).
plugin_version_of() {
  command -v jq >/dev/null 2>&1 || return 0
  jq -r '.version // empty' "$1/.cursor-plugin/plugin.json" 2>/dev/null
}

# Candidates in precedence order; the first with an installed runtime wins. A
# plugin cache looks like a tool home structurally but has no node_modules, so
# "installed" is the test that matters. With nothing installed anywhere, fall
# back to the first structurally valid candidate so error messages make sense.
resolve_canvas_home() {
  local candidates=() candidate first_valid=""
  [ -n "${CANVAS_HOME:-}" ] && candidates+=("${CANVAS_HOME/#\~/$HOME}")
  candidate="$(config_get home)"
  [ -n "$candidate" ] && candidates+=("${candidate/#\~/$HOME}")
  if command -v canvas >/dev/null 2>&1; then
    candidates+=("$(dirname "$(dirname "$(real_path "$(command -v canvas)")")")")
  fi
  candidates+=("$CANVAS_MANAGED_HOME")
  candidates+=("$(cd "$(dirname "$(real_path "${BASH_SOURCE[0]}")")/.." && pwd)")

  for candidate in "${candidates[@]}"; do
    is_tool_home "$candidate" || continue
    [ -z "$first_valid" ] && first_valid="$candidate"
    if runtime_installed_at "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "${first_valid:-${candidates[${#candidates[@]}-1]}}"
}

CANVAS_HOME="$(resolve_canvas_home)"
CANVAS_RUNTIME_DIR="$CANVAS_HOME/runtime"

default_root() {
  if [ -d "$HOME/.cursor/projects" ]; then
    printf '%s\n' "$HOME/.cursor/projects"
  else
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/agent-canvas/projects"
  fi
}

CANVAS_ROOT="${CANVAS_ROOT:-$(config_get root)}"
CANVAS_ROOT="${CANVAS_ROOT/#\~/$HOME}"
[ -z "$CANVAS_ROOT" ] && CANVAS_ROOT="$(default_root)"
CANVAS_THEME="${CANVAS_THEME:-$(config_get theme)}"
[ -z "$CANVAS_THEME" ] && CANVAS_THEME="cursor"
CANVAS_PORT="${CANVAS_PORT:-$(config_get port)}"
[ -z "$CANVAS_PORT" ] && CANVAS_PORT=4817
CANVAS_PAGES_PROJECT="${CANVAS_PAGES_PROJECT:-$(config_get pagesProject)}"
[ -z "$CANVAS_PAGES_PROJECT" ] && CANVAS_PAGES_PROJECT="canvases-${USER:-$(id -un)}"
export CANVAS_HOME CANVAS_ROOT CANVAS_THEME CANVAS_PORT CANVAS_PAGES_PROJECT

CANVAS_URL="http://127.0.0.1:$CANVAS_PORT"
CANVAS_PIDFILE="$CANVAS_RUNTIME_DIR/.server.pid"
CANVAS_LOGFILE="$CANVAS_RUNTIME_DIR/.server.log"
CANVAS_ERRLOG="$CANVAS_RUNTIME_DIR/.canvas-errors.log"
CANVAS_OPENED_REGISTRY="$CANVAS_RUNTIME_DIR/.opened-canvases"
CANVAS_PUBLISHED_LOG="$CANVAS_RUNTIME_DIR/.published.jsonl"

# Workspace slug used for the per-workspace canvases directory: the absolute
# path with the leading slash removed and every slash turned into a hyphen.
# This matches the Cursor IDE's ~/.cursor/projects/<slug> convention.
workspace_slug() {
  local dir="${1:-$PWD}"
  dir="$(cd "$dir" 2>/dev/null && pwd -P || printf '%s' "$dir")"
  dir="${dir#/}"
  printf '%s\n' "${dir//\//-}"
}

# Absolute path of a canvas for the current (or given) workspace.
canvas_path_for() {
  local name="$1" workspace="${2:-$PWD}"
  name="${name%.canvas.tsx}"
  printf '%s/%s/canvases/%s.canvas.tsx\n' "$CANVAS_ROOT" "$(workspace_slug "$workspace")" "$name"
}

# Hooks and non-interactive shells may not have node on PATH; fall back to nvm.
ensure_node() {
  if command -v node >/dev/null 2>&1; then
    return 0
  fi
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" >/dev/null 2>&1
  fi
  command -v node >/dev/null 2>&1
}

ensure_runtime_installed() {
  if [ ! -x "$CANVAS_RUNTIME_DIR/node_modules/.bin/vite" ] || [ ! -x "$CANVAS_RUNTIME_DIR/node_modules/.bin/tsc" ]; then
    echo "agent-canvas: runtime is not installed at $CANVAS_HOME. Clone the repository and run scripts/canvas setup there (plugin caches are not install locations)." >&2
    return 1
  fi
}

# Record a key in the config file, creating it if needed and keeping other keys.
config_set() {
  command -v jq >/dev/null 2>&1 || return 1
  mkdir -p "$(dirname "$CANVAS_CONFIG_FILE")"
  [ -s "$CANVAS_CONFIG_FILE" ] || echo '{}' >"$CANVAS_CONFIG_FILE"
  local tmp
  tmp="$(mktemp)"
  jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$CANVAS_CONFIG_FILE" >"$tmp" && mv "$tmp" "$CANVAS_CONFIG_FILE"
}

# Resolve to an absolute path and validate the canvas file-name contract.
# Prints the absolute path; returns non-zero with a message on stderr otherwise.
resolve_canvas_path() {
  local file="$1"
  case "$file" in
    /*) ;;
    *) file="$(pwd)/$file" ;;
  esac
  case "$file" in
    *.canvas.tsx) ;;
    *)
      echo "agent-canvas: not a .canvas.tsx file: $file" >&2
      return 1
      ;;
  esac
  if [ ! -f "$file" ]; then
    echo "agent-canvas: file not found: $file" >&2
    return 1
  fi
  printf '%s\n' "$file"
}

urlencode() {
  if command -v jq >/dev/null 2>&1; then
    jq -rn --arg s "$1" '$s|@uri'
  else
    printf '%s' "$1" | sed 's|/|%2F|g'
  fi
}

# URL for a canvas. Files under the canvas root get the short form
# `/c/<workspace>/<name>`; anything else falls back to `/?file=<abs path>`.
canvas_url_for() {
  local file="$1"
  case "$file" in
    "$CANVAS_ROOT"/*/canvases/*.canvas.tsx)
      local rel="${file#"$CANVAS_ROOT"/}"
      local workspace="${rel%%/*}"
      local base="${file##*/}"
      local name="${base%.canvas.tsx}"
      if [ "$rel" = "$workspace/canvases/$base" ]; then
        printf '%s/c/%s/%s\n' "$CANVAS_URL" "$(urlencode "$workspace")" "$(urlencode "$name")"
        return 0
      fi
      ;;
  esac
  printf '%s/?file=%s\n' "$CANVAS_URL" "$(urlencode "$file")"
}

# Registry of canvases already surfaced to the user, so the hook opens a
# browser tab once per canvas rather than on every edit.
canvas_was_opened() {
  [ -f "$CANVAS_OPENED_REGISTRY" ] && grep -qxF -- "$1" "$CANVAS_OPENED_REGISTRY"
}

mark_canvas_opened() {
  canvas_was_opened "$1" || printf '%s\n' "$1" >>"$CANVAS_OPENED_REGISTRY"
}

server_is_running() {
  curl -sf -o /dev/null --max-time 1 "$CANVAS_URL/__canvases"
}

# A headless Chromium for screenshots/PDFs: Playwright's cache first (no
# install needed if it is there), then system browsers. Prints the binary path.
find_headless_chromium() {
  local candidate
  for candidate in \
    "$HOME"/.cache/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell \
    "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux/chrome; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  for candidate in chromium chromium-browser google-chrome google-chrome-stable chrome; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  return 1
}

# PID of whatever is listening on the canvas port, if we can determine it.
listening_pid() {
  local pid=""
  if command -v lsof >/dev/null 2>&1; then
    pid="$(lsof -ti "tcp:$CANVAS_PORT" -sTCP:LISTEN 2>/dev/null | head -n1)"
  elif command -v ss >/dev/null 2>&1; then
    pid="$(ss -ltnp "sport = :$CANVAS_PORT" 2>/dev/null | sed -nE 's/.*pid=([0-9]+).*/\1/p' | head -n1)"
  fi
  [ -n "$pid" ] && printf '%s\n' "$pid"
}
