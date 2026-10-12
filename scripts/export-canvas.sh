#!/usr/bin/env bash
# Export a canvas as a self-contained artifact.
#
# Usage: export-canvas.sh <path/to/name.canvas.tsx> [options]
#
#   --out <path>     Where to write. Default: <canvases dir>/exports/<name>.html
#                    (.png/.pdf for those formats).
#   --png            Also render a PNG screenshot of the exported HTML.
#   --pdf            Also render a PDF of the exported HTML.
#   --size WxH       Viewport for --png (default 1280x1800).
#   --no-fonts       Leave the self-hosted fonts out (roughly 30% smaller;
#                    the page falls back to system fonts).
#
# The HTML is one file — runtime, canvas, styles and fonts inlined — so it
# renders from disk or any static host with no server. Prints the output
# path(s), one per line, on stdout.
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

canvas=""
out=""
want_png=0
want_pdf=0
size="1280x1800"
fonts=1

while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2 ;;
    --png) want_png=1; shift ;;
    --pdf) want_pdf=1; shift ;;
    --size) size="${2:-}"; shift 2 ;;
    --no-fonts) fonts=0; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "export-canvas: unknown option $1" >&2; usage >&2; exit 64 ;;
    *) canvas="$1"; shift ;;
  esac
done

if [ -z "$canvas" ]; then
  usage >&2
  exit 64
fi

file="$(resolve_canvas_path "$canvas")" || exit 1
name="$(basename "$file" .canvas.tsx)"

ensure_node || { echo "export-canvas: node is not available." >&2; exit 1; }
ensure_runtime_installed || exit 1
if [ ! -d "$CANVAS_RUNTIME_DIR/node_modules/vite-plugin-singlefile" ]; then
  echo "export-canvas: vite-plugin-singlefile is missing. Run: $CANVAS_HOME/scripts/canvas setup" >&2
  exit 1
fi

# Default output lives beside the canvas, in a subdirectory the canvas index
# ignores (it only lists *.canvas.tsx directly inside canvases/).
if [ -z "$out" ]; then
  out="$(dirname "$file")/exports/$name.html"
fi
case "$out" in
  /*) ;;
  *) out="$(pwd)/$out" ;;
esac
case "$out" in
  *.html) ;;
  *) out="$out.html" ;;
esac
mkdir -p "$(dirname "$out")"

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

if ! (
  cd "$CANVAS_RUNTIME_DIR" &&
    CANVAS_EXPORT_FILE="$file" CANVAS_EXPORT_OUT="$build_dir" CANVAS_EXPORT_FONTS="$fonts" \
      ./node_modules/.bin/vite build --config vite.export.config.ts >"$build_dir/build.log" 2>&1
); then
  echo "export-canvas: build failed:" >&2
  tail -n 30 "$build_dir/build.log" >&2
  exit 1
fi

if [ ! -s "$build_dir/export.html" ]; then
  echo "export-canvas: build produced no export.html" >&2
  tail -n 30 "$build_dir/build.log" >&2
  exit 1
fi

cp "$build_dir/export.html" "$out"
echo "$out"

if [ "$want_png" -eq 1 ] || [ "$want_pdf" -eq 1 ]; then
  chromium="$(find_headless_chromium)" || {
    echo "export-canvas: no headless Chromium found for --png/--pdf (looked in ~/.cache/ms-playwright and PATH)." >&2
    exit 1
  }
  common=(--headless --disable-gpu --no-sandbox --allow-file-access-from-files --virtual-time-budget=8000 --hide-scrollbars)
  file_url="file://$out"

  if [ "$want_png" -eq 1 ]; then
    png="${out%.html}.png"
    width="${size%x*}"
    height="${size#*x}"
    if timeout 90 "$chromium" "${common[@]}" "--window-size=$width,$height" "--screenshot=$png" "$file_url" >/dev/null 2>&1 && [ -s "$png" ]; then
      echo "$png"
    else
      echo "export-canvas: PNG render failed" >&2
      exit 1
    fi
  fi

  if [ "$want_pdf" -eq 1 ]; then
    pdf="${out%.html}.pdf"
    if timeout 90 "$chromium" "${common[@]}" --no-pdf-header-footer "--print-to-pdf=$pdf" "$file_url" >/dev/null 2>&1 && [ -s "$pdf" ]; then
      echo "$pdf"
    else
      echo "export-canvas: PDF render failed" >&2
      exit 1
    fi
  fi
fi
