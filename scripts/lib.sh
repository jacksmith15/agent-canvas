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

CANVAS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANVAS_RUNTIME_DIR="$CANVAS_HOME/runtime"
CANVAS_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-canvas/config.json"

# Read one key from the config file; empty when absent or unreadable.
config_get() {
  [ -f "$CANVAS_CONFIG_FILE" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg k "$1" '.[$k] // empty' "$CANVAS_CONFIG_FILE" 2>/dev/null
}

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
export CANVAS_ROOT CANVAS_THEME CANVAS_PORT CANVAS_PAGES_PROJECT

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
    echo "agent-canvas: runtime dependencies are missing. Run: $CANVAS_HOME/scripts/canvas setup" >&2
    return 1
  fi
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
