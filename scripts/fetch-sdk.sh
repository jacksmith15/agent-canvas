#!/usr/bin/env bash
# Populate sdk/ with the official `cursor/canvas` type declarations.
#
# The declarations are Cursor's and are not redistributed in this repository.
# They are copied from a local Cursor IDE install when one is present
# (~/.cursor/skills-cursor/canvas/sdk/), otherwise fetched from a public mirror.
# The agent reads them for component discovery; type-checking uses the vendored
# shim's own types, so the runtime works without them.
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

SDK_DIR="$CANVAS_HOME/sdk"
LOCAL_SDK="$HOME/.cursor/skills-cursor/canvas/sdk"
MIRROR="https://raw.githubusercontent.com/awesome-skills/canvas-skill/main/sdk"
FILES=(
  callout-tone-icons canvas-tokens chart-primitives collapsible-section dag-layout
  diff-view form-primitives hooks index swatch theme todo-list ui-primitives usage-bar
)

mkdir -p "$SDK_DIR"

if [ -f "$SDK_DIR/index.d.ts" ] && [ "${1:-}" != "--force" ]; then
  echo "sdk/ already populated ($SDK_DIR); use --force to refresh."
  exit 0
fi

if [ -f "$LOCAL_SDK/index.d.ts" ]; then
  cp "$LOCAL_SDK"/*.d.ts "$SDK_DIR/"
  echo "Copied SDK declarations from the local Cursor install."
  exit 0
fi

echo "Fetching SDK declarations from $MIRROR ..."
failed=0
for f in "${FILES[@]}"; do
  if ! curl -sfL -o "$SDK_DIR/$f.d.ts" "$MIRROR/$f.d.ts"; then
    echo "  failed: $f.d.ts" >&2
    failed=1
  fi
done
if [ "$failed" -eq 1 ]; then
  echo "Some declarations could not be fetched; the skill still works, with less precise component discovery." >&2
  exit 1
fi
echo "SDK declarations written to $SDK_DIR"
