#!/usr/bin/env bash
# Claude Code `PostToolUse` hook adapter.
#
# Input (stdin):   Claude Code's PostToolUse JSON (`tool_name`, `tool_input`).
# Output (stdout): nothing to stay silent, or
#   {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": "..."}}
#
# Set CANVAS_HOOK_DEBUG=1 to append each invocation's tool_name and input keys
# to /tmp/agent-canvas-hook.log.
set -uo pipefail

input="$(cat)"
command -v jq >/dev/null 2>&1 || exit 0

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"
path="$(printf '%s' "$input" | jq -r '
  .tool_input
  | if type == "object" then (.file_path // .path // .notebook_path // empty) else empty end
' 2>/dev/null)"

if [ -n "${CANVAS_HOOK_DEBUG:-}" ]; then
  printf '%s\n' "$input" | jq -c '{harness: "claude", tool_name, input_keys: (.tool_input | if type == "object" then keys else type end)}' \
    >>/tmp/agent-canvas-hook.log 2>/dev/null
fi

case "$tool_name" in
  Write | Edit | MultiEdit | NotebookEdit) ;;
  *) exit 0 ;;
esac

context="$("$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/after-write.sh" "$path" 2>/dev/null)"
[ -z "$context" ] && exit 0

jq -cn --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
