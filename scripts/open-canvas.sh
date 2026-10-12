#!/usr/bin/env bash
# Open a .canvas.tsx in the browser, starting the local canvas server if needed.
#
# Usage: open-canvas.sh [--no-open] <path/to/name.canvas.tsx>
#
# Always prints the canvas URL. Launches the default browser unless --no-open is
# given or no graphical session is detected (e.g. over SSH), in which case the
# URL alone is printed for the user to open.
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

no_open=0
if [ "${1:-}" = "--no-open" ]; then
  no_open=1
  shift
fi

if [ -z "${1:-}" ]; then
  echo "usage: open-canvas.sh [--no-open] <path/to/name.canvas.tsx>" >&2
  exit 64
fi

file="$(resolve_canvas_path "$1")" || exit 1

"$CANVAS_HOME/scripts/canvas-server.sh" start >/dev/null || exit 1

url="$(canvas_url_for "$file")"

opened=0
if [ "$no_open" -eq 0 ]; then
  if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
    opened=1
  elif [ "$(uname -s)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 &
    opened=1
  fi
fi

mark_canvas_opened "$file"

if [ "$opened" -eq 1 ]; then
  echo "Opened canvas in browser: $url"
else
  echo "Canvas URL (open in a browser): $url"
fi
echo "All canvases: $CANVAS_URL/"
