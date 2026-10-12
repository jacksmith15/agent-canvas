#!/usr/bin/env bash
# Type-check and lint one .canvas.tsx file against the CLI canvas runtime.
#
# Usage: canvas-check.sh <path/to/name.canvas.tsx>
#
# Prints a "Canvas TypeScript check" summary (the same signal the IDE attaches
# to canvas edits). Exit 0 when clean, 1 when there are errors or rule
# violations, 64 on usage error.
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ -z "${1:-}" ]; then
  echo "usage: canvas-check.sh <path/to/name.canvas.tsx>" >&2
  exit 64
fi

file="$(resolve_canvas_path "$1")" || {
  echo "Canvas TypeScript check: $1 could not be checked (see above)."
  exit 1
}
name="$(basename "$file")"

ensure_node || {
  echo "Canvas TypeScript check ($name): node is not available; cannot run tsc."
  exit 1
}
ensure_runtime_installed || {
  echo "Canvas TypeScript check ($name): runtime not installed."
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# globals.d.ts declares compile-time constants injected by Vite that the
# runtime's alias module depends on; `files` replaces the base config's list,
# so it has to be named here alongside the canvas.
cat >"$tmp/tsconfig.json" <<EOF
{
  "extends": "$CANVAS_RUNTIME_DIR/tsconfig.canvas.json",
  "files": ["$file", "$CANVAS_RUNTIME_DIR/src/globals.d.ts"]
}
EOF

# Run from the canvas's directory so diagnostics print as `name.canvas.tsx(line,col)`.
tsc_status=0
tsc_out="$(cd "$(dirname "$file")" && "$CANVAS_RUNTIME_DIR/node_modules/.bin/tsc" -p "$tmp/tsconfig.json" --pretty false 2>&1)" || tsc_status=$?

# Rules from the canvas skill that tsc cannot express.
rule_errors=()

while IFS= read -r line; do
  [ -n "$line" ] && rule_errors+=("$line: canvases may import only from 'cursor/canvas'")
done < <(grep -nE "^[[:space:]]*import[[:space:]].*from[[:space:]]+['\"]" "$file" \
  | grep -vE "from[[:space:]]+['\"]cursor/canvas['\"]" \
  | cut -d: -f1 | sed 's/^/line /')

while IFS= read -r line; do
  [ -n "$line" ] && rule_errors+=("$line: canvases must embed data inline; no fetch() or network calls")
done < <(grep -nE "\bfetch[[:space:]]*\(" "$file" | cut -d: -f1 | sed 's/^/line /')

if ! grep -qE "^export default" "$file"; then
  rule_errors+=("file: no 'export default' — the top-level component must be the default export")
fi

tsc_error_count=0
if [ -n "$tsc_out" ]; then
  tsc_error_count="$(printf '%s\n' "$tsc_out" | grep -cE "error TS[0-9]+" || true)"
fi
total=$((tsc_error_count + ${#rule_errors[@]}))

if [ "$total" -eq 0 ] && [ "$tsc_status" -eq 0 ]; then
  echo "Canvas TypeScript check ($name): no errors"
  exit 0
fi

echo "Canvas TypeScript check ($name): $total error(s)"
if [ -n "$tsc_out" ]; then
  printf '%s\n' "$tsc_out"
fi
if [ "${#rule_errors[@]}" -gt 0 ]; then
  echo "Canvas rules:"
  for e in "${rule_errors[@]}"; do
    echo "  - $e"
  done
fi
exit 1
