#!/usr/bin/env bash
# Share a canvas: export it to one self-contained HTML file and publish that
# to Cloudflare Pages, printing a link anyone can open in a browser.
#
# Usage: share-canvas.sh <path/to/name.canvas.tsx> [--name <alias>] [--no-fonts]
#
# This uploads the canvas, including every piece of data embedded in it, and
# makes it reachable by anyone who has the URL. Only run it when the user has
# asked for the canvas to be shared. Undo with:
#   publish-html.sh --unpublish <alias>
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

canvas=""
export_args=()
publish_args=()

while [ $# -gt 0 ]; do
  case "$1" in
    --name) publish_args+=(--name "${2:-}"); shift 2 ;;
    --no-fonts) export_args+=(--no-fonts); shift ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "share-canvas: unknown option $1" >&2; usage >&2; exit 64 ;;
    *) canvas="$1"; shift ;;
  esac
done

if [ -z "$canvas" ]; then
  usage >&2
  exit 64
fi

file="$(resolve_canvas_path "$canvas")" || exit 1

html="$("$CANVAS_HOME/scripts/export-canvas.sh" "$file" "${export_args[@]}")" || exit 1
echo "Exported: $html"
exec "$CANVAS_HOME/scripts/publish-html.sh" "$html" "${publish_args[@]}"
