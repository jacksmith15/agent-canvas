#!/usr/bin/env bash
# Make sure the tool is installed, installing or updating it from a plugin
# checkout when it is not.
#
# Usage: ensure-installed.sh [<plugin-root>]
#
# Called by the session-start hooks and, as a fallback, by the post-write hook.
# Fast path (no output, exit 0): the config points at an installed tool that is
# either a developer checkout or a managed install already at this plugin's
# version. Otherwise the plugin checkout is synced into the managed location
# (~/.local/share/agent-canvas/tool) and its runtime installed, which takes a
# while the first time. Prints one status line when it did something.
set -uo pipefail

# shellcheck source=../scripts/lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/lib.sh"

plugin_root="${1:-$(cd "$(dirname "$(real_path "${BASH_SOURCE[0]}")")/.." && pwd)}"
plugin_root="$(cd "$plugin_root" && pwd)"
plugin_version="$(plugin_version_of "$plugin_root")"

home="$(config_get home)"
home="${home/#\~/$HOME}"
managed="$(config_get managed)"
installed_version="$(config_get version)"

if [ -n "$home" ] && is_tool_home "$home" && runtime_installed_at "$home"; then
  # A developer checkout is left alone; a managed install is refreshed only
  # when the plugin has moved on.
  if [ "$managed" != "true" ] || [ -z "$plugin_version" ] || [ "$installed_version" = "$plugin_version" ]; then
    exit 0
  fi
  action="updated to $plugin_version"
else
  action="installed"
fi

# Serialise concurrent bootstraps (session start and a first write can race).
lock="$CANVAS_DATA_DIR/.install.lock"
mkdir -p "$CANVAS_DATA_DIR"
waited=0
until mkdir "$lock" 2>/dev/null; do
  sleep 1
  waited=$((waited + 1))
  if [ "$waited" -ge 180 ]; then
    echo "agent-canvas: another install has held $lock for 3 minutes; remove it if no install is running." >&2
    exit 1
  fi
done
trap 'rmdir "$lock" 2>/dev/null' EXIT

# Re-check after acquiring the lock: the other process may have finished.
home="$(config_get home)"
home="${home/#\~/$HOME}"
if [ -n "$home" ] && is_tool_home "$home" && runtime_installed_at "$home" && [ "$(config_get version)" = "$plugin_version" ]; then
  exit 0
fi

if ! "$plugin_root/scripts/setup.sh" --into "$CANVAS_MANAGED_HOME" --quiet; then
  echo "agent-canvas: runtime install failed. Run $plugin_root/scripts/setup.sh --into $CANVAS_MANAGED_HOME to see why." >&2
  exit 1
fi

if [ -x "$HOME/.local/bin/canvas" ]; then
  echo "agent-canvas: runtime $action at $CANVAS_MANAGED_HOME; the \`canvas\` command is ~/.local/bin/canvas ($CANVAS_MANAGED_HOME/scripts/canvas)."
else
  echo "agent-canvas: runtime $action at $CANVAS_MANAGED_HOME; the \`canvas\` command is $CANVAS_MANAGED_HOME/scripts/canvas."
fi
