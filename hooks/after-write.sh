#!/usr/bin/env bash
# Harness-neutral core of the post-write hook.
#
# Usage: after-write.sh <path>
#
# Given a path that a file-writing tool just touched, do nothing unless it is
# a `.canvas.tsx`; otherwise:
#   1. Run the canvas type check (the "Canvas TypeScript check" line).
#   2. The first time the canvas passes, open it in the browser and report the
#      URL; on later clean checks just report the URL.
# Prints plain text for the harness adapter to wrap; always exits 0 with no
# output when there is nothing to say.
set -uo pipefail

# shellcheck source=../scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/lib.sh"

path="${1:-}"
case "$path" in
  *.canvas.tsx) ;;
  *) exit 0 ;;
esac
[ -f "$path" ] || exit 0

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# First canvas on a machine where the session-start hook did not run (or has
# not finished): install the tool now, then re-resolve where it lives.
install_note="$("$here/ensure-installed.sh" "$(dirname "$here")" 2>&1)" || true
if [ -n "$install_note" ]; then
  unset CANVAS_HOME
  # shellcheck source=../scripts/lib.sh
  . "$here/../scripts/lib.sh"
fi

check_status=0
context="$("$CANVAS_HOME/scripts/canvas-check.sh" "$path" 2>&1)" || check_status=$?
[ -n "$install_note" ] && context="$install_note"$'\n'"$context"

if [ "$check_status" -eq 0 ]; then
  if canvas_was_opened "$path"; then
    context="$context"$'\n'"Canvas URL: $(canvas_url_for "$path")"
  else
    # First clean check: surface it. open-canvas.sh starts the server if
    # needed, opens the browser when a display is available, prints the URL
    # either way, and records the canvas as opened.
    open_output="$("$CANVAS_HOME/scripts/open-canvas.sh" "$path" 2>&1)" || true
    context="$context"$'\n'"$open_output"
  fi
fi

printf '%s\n' "$context"
