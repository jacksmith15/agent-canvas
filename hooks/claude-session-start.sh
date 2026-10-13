#!/usr/bin/env bash
# Claude Code `SessionStart` hook adapter: make sure the tool is installed and
# tell the model where it is when that changed.
set -uo pipefail

cat >/dev/null # input is not needed
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(dirname "$here")}"

status="$("$here/ensure-installed.sh" "$plugin_root" 2>&1)" || true
[ -z "$status" ] && exit 0

command -v jq >/dev/null 2>&1 || exit 0
jq -cn --arg ctx "$status" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
