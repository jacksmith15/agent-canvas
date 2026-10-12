#!/usr/bin/env bash
# Cursor `postToolUse` hook adapter.
#
# Input (stdin):   Cursor's postToolUse JSON (`tool_name`, `tool_input`).
# Output (stdout): `{}` to stay silent, or `{"additional_context": "..."}`.
#
# Set CANVAS_HOOK_DEBUG=1 to append each invocation's tool_name and input keys
# to /tmp/agent-canvas-hook.log (useful for tightening a hooks.json matcher).
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || { echo '{}'; exit 0; }

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
path="$(printf '%s' "$input" | jq -r '
  .tool_input
  | if type == "object" then (.path // .file_path // .target_file // empty) else empty end
' 2>/dev/null)"

if [ -n "${CANVAS_HOOK_DEBUG:-}" ]; then
  printf '%s\n' "$input" | jq -c '{harness: "cursor", tool_name, input_keys: (.tool_input | if type == "object" then keys else type end)}' \
    >>/tmp/agent-canvas-hook.log 2>/dev/null
fi

# Only tools that write files; reads of a canvas must not trigger tsc.
case "$tool_name" in
  *[Ww]rite* | *[Ee]dit* | *[Rr]eplace*) ;;
  *) echo '{}'; exit 0 ;;
esac

context="$("$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/after-write.sh" "$path" 2>/dev/null)"
if [ -z "$context" ]; then
  echo '{}'
else
  jq -cn --arg ctx "$context" '{additional_context: $ctx}'
fi
