#!/usr/bin/env bash
# Register agent-canvas with a harness without using its plugin system:
# symlink the skill into the harness's personal skills directory and merge the
# post-tool hook into its user-level hooks configuration. Idempotent.
#
# Usage: install.sh cursor|claude [--uninstall]
#
# Plugin-based installs (`agent plugin ...`, `claude plugin ...`) do this
# automatically from the manifests in .cursor-plugin/ and .claude-plugin/; this
# script is for harness versions or setups where that is not available.
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "install: jq is required." >&2; exit 1; }

harness="${1:-}"
uninstall=0
[ "${2:-}" = "--uninstall" ] && uninstall=1

SKILL_SRC="$CANVAS_HOME/skills/agent-canvas"
MARK="agent-canvas/hooks/"

link_skill() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  if [ "$uninstall" -eq 1 ]; then
    [ -L "$dest" ] && rm "$dest" && echo "removed $dest"
    return 0
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "install: $dest exists and is not a symlink; move it aside first." >&2
    exit 1
  fi
  ln -sfn "$SKILL_SRC" "$dest"
  echo "linked $dest -> $SKILL_SRC"
}

# Merge or remove a hook entry in a JSON file using a jq program. Creates the
# file when absent. The jq program receives $cmd (hook command) and $mark.
edit_json() {
  local file="$1" program="$2" cmd="$3"
  mkdir -p "$(dirname "$file")"
  [ -s "$file" ] || echo '{}' >"$file"
  local tmp
  tmp="$(mktemp)"
  if jq --arg cmd "$cmd" --arg mark "$MARK" "$program" "$file" >"$tmp"; then
    mv "$tmp" "$file"
  else
    rm -f "$tmp"
    echo "install: could not update $file (invalid JSON?)" >&2
    exit 1
  fi
}

case "$harness" in
  cursor)
    link_skill "$HOME/.cursor/skills/agent-canvas"
    hooks_file="$HOME/.cursor/hooks.json"
    cmd="$CANVAS_HOME/hooks/cursor.sh"
    if [ "$uninstall" -eq 1 ]; then
      edit_json "$hooks_file" '
        .hooks.postToolUse |= (map(select((.command // "") | contains($mark) | not)))
      ' "$cmd"
      echo "removed hook from $hooks_file"
    else
      edit_json "$hooks_file" '
        .version = (.version // 1)
        | .hooks = (.hooks // {})
        | .hooks.postToolUse = ((.hooks.postToolUse // []) | map(select((.command // "") | contains($mark) | not)))
          + [{command: $cmd, timeout: 120}]
      ' "$cmd"
      echo "added postToolUse hook to $hooks_file"
      echo "Start a new Cursor CLI session for the hook to load."
    fi
    ;;
  claude)
    link_skill "$HOME/.claude/skills/agent-canvas"
    settings_file="$HOME/.claude/settings.json"
    cmd="bash \"$CANVAS_HOME/hooks/claude.sh\""
    if [ "$uninstall" -eq 1 ]; then
      edit_json "$settings_file" '
        .hooks.PostToolUse |= (map(select(((.hooks // []) | map(.command // "") | join(" ")) | contains($mark) | not)))
      ' "$cmd"
      echo "removed hook from $settings_file"
    else
      edit_json "$settings_file" '
        .hooks = (.hooks // {})
        | .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(((.hooks // []) | map(.command // "") | join(" ")) | contains($mark) | not)))
          + [{matcher: "Write|Edit|MultiEdit|NotebookEdit", hooks: [{type: "command", command: $cmd, timeout: 120}]}]
      ' "$cmd"
      echo "added PostToolUse hook to $settings_file"
      echo "Start a new Claude Code session for the hook to load."
    fi
    ;;
  *)
    echo "usage: install.sh cursor|claude [--uninstall]" >&2
    exit 64
    ;;
esac
