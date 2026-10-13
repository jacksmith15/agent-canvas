#!/usr/bin/env bash
# Cursor `sessionStart` hook adapter: make sure the tool is installed, export
# its location to later hooks, and tell the model where it is when that changed.
set -uo pipefail

cat >/dev/null # input is not needed
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="${CURSOR_PLUGIN_ROOT:-$(dirname "$here")}"

status="$("$here/ensure-installed.sh" "$plugin_root" 2>&1)" || true

command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }
# shellcheck source=../scripts/lib.sh
. "$(dirname "$here")/scripts/lib.sh"
jq -cn --arg ctx "$status" --arg home "$CANVAS_HOME" '
  {env: {CANVAS_HOME: $home}} + (if $ctx == "" then {} else {additional_context: $ctx} end)
'
