#!/usr/bin/env bash
# Publish a single self-contained HTML file to Cloudflare Pages and print the
# URL. One Pages project holds every shared canvas; each canvas is deployed to
# its own branch so it gets a stable, readable alias:
#
#   https://<name>.<project>.pages.dev
#
# Usage:
#   publish-html.sh <file.html> [--name <alias>]
#   publish-html.sh --unpublish <alias or URL>
#   publish-html.sh --list
#
# Pages URLs are public to anyone who has them (noindex, but not access
# controlled). Re-publishing the same name updates the alias in place.
# --unpublish replaces the alias with a tombstone page, which takes effect
# immediately. Every event is recorded in the runtime's .published.jsonl.
#
# Setup (once): `wrangler login` from the runtime directory, or export
# CLOUDFLARE_API_TOKEN (+ CLOUDFLARE_ACCOUNT_ID). The project is created on
# first use; override its name with CANVAS_PAGES_PROJECT (default canvases-$USER).
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PROJECT="$CANVAS_PAGES_PROJECT"
WRANGLER="$CANVAS_RUNTIME_DIR/node_modules/.bin/wrangler"

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "publish-html: '$1' is required but not installed." >&2
    exit 1
  }
}

need jq

ensure_node || { echo "publish-html: node is not available." >&2; exit 1; }
if [ ! -x "$WRANGLER" ]; then
  echo "publish-html: wrangler is not installed in the runtime. Run: $CANVAS_HOME/scripts/canvas setup" >&2
  exit 1
fi

# Quiet, non-interactive wrangler.
export CI=true WRANGLER_SEND_METRICS=false NO_COLOR=1
wrangler() {
  (cd "$CANVAS_RUNTIME_DIR" && "$WRANGLER" "$@")
}

ensure_auth() {
  if ! wrangler whoami >/dev/null 2>&1; then
    echo "publish-html: not logged in to Cloudflare. Run:" >&2
    echo "  (cd $CANVAS_RUNTIME_DIR && ./node_modules/.bin/wrangler login)" >&2
    echo "or export CLOUDFLARE_API_TOKEN (Pages: Edit) and CLOUDFLARE_ACCOUNT_ID." >&2
    exit 1
  fi
}

ensure_project() {
  if wrangler pages project list 2>/dev/null | grep -qE "(^|[^a-z0-9-])$PROJECT([^a-z0-9-]|$)"; then
    return 0
  fi
  echo "Creating Pages project '$PROJECT' (first use)..." >&2
  if ! wrangler pages project create "$PROJECT" --production-branch main >/dev/null 2>/tmp/publish-html.err; then
    echo "publish-html: could not create Pages project '$PROJECT':" >&2
    grep -v '^\s*$' /tmp/publish-html.err | tail -n 5 >&2
    echo "If the name is taken, choose another with CANVAS_PAGES_PROJECT=<name>." >&2
    exit 1
  fi
}

# Cloudflare derives branch aliases from branch names: lowercase, runs of
# non [a-z0-9] become '-', trimmed, max 28 chars. Mirror that so the URL we
# print is the one that exists.
alias_for() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-28 | sed -E 's/-+$//'
}

alias_from() {
  # Accept an alias, or a URL of the form https://<alias>.<project>.pages.dev[/...]
  local s="$1"
  s="${s#https://}"
  s="${s#http://}"
  s="${s%%/*}"
  s="${s%.$PROJECT.pages.dev}"
  alias_for "$s"
}

record() {
  printf '%s\n' "$1" >>"$CANVAS_PUBLISHED_LOG"
}

# Deploy a directory to a branch; prints the deployment's unique URL.
deploy_dir() {
  local dir="$1" branch="$2" message="$3" out
  if ! out="$(wrangler pages deploy "$dir" --project-name "$PROJECT" --branch "$branch" --commit-dirty=true --commit-message "$message" 2>&1)"; then
    echo "publish-html: deploy failed:" >&2
    printf '%s\n' "$out" | grep -v '^\s*$' | tail -n 12 >&2
    exit 1
  fi
  printf '%s\n' "$out" | grep -oE 'https://[a-z0-9-]+\.[a-z0-9-]+\.pages\.dev' | head -n1
}

do_list() {
  if [ ! -s "$CANVAS_PUBLISHED_LOG" ]; then
    echo "nothing published"
    return 0
  fi
  # An alias is live if its most recent event is a publish. Events are
  # appended chronologically, so the last entry per alias is the latest.
  local live
  live="$(jq -rs '
    group_by(.alias) | map(last) | .[]
    | select(.event == "publish")
    | "\(.ts)  \(.alias)  \(.name)\n    \(.url)"
  ' "$CANVAS_PUBLISHED_LOG")"
  if [ -n "$live" ]; then printf '%s\n' "$live"; else echo "nothing currently published"; fi
}

do_unpublish() {
  local alias
  alias="$(alias_from "$1")"
  [ -z "$alias" ] && { echo "publish-html: could not derive an alias from '$1'" >&2; exit 64; }
  ensure_auth
  ensure_project

  local tmp
  tmp="$(mktemp -d)"
  # Expand now: `tmp` is function-local and gone by the time EXIT fires.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  cat >"$tmp/index.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="robots" content="noindex"><title>Unpublished</title>
<style>html{color-scheme:dark light}body{font-family:system-ui,sans-serif;display:grid;place-items:center;min-height:100vh;margin:0}p{opacity:.7}</style>
</head><body><p>This canvas has been unpublished.</p></body></html>
EOF
  printf 'X-Robots-Tag: noindex\n' >"$tmp/_headers"
  deploy_dir "$tmp" "$alias" "unpublish $alias" >/dev/null
  record "$(jq -cn --arg ts "$(date -u +%FT%TZ)" --arg alias "$alias" '{event: "unpublish", ts: $ts, alias: $alias}')"
  echo "Unpublished: https://$alias.$PROJECT.pages.dev now shows a tombstone page."
  echo "Note: Cloudflare keeps earlier deployments reachable at their own <hash>.$PROJECT.pages.dev URLs; those were never shared by this tool, and can be deleted in the Pages dashboard."
}

do_publish() {
  local file="$1" name="$2"
  case "$file" in
    /*) ;;
    *) file="$(pwd)/$file" ;;
  esac
  if [ ! -s "$file" ]; then
    echo "publish-html: file not found or empty: $file" >&2
    exit 1
  fi
  case "$file" in
    *.html | *.htm) ;;
    *) echo "publish-html: expected an .html file: $file" >&2; exit 1 ;;
  esac
  [ -z "$name" ] && name="$(basename "${file%.*}")"
  local alias
  alias="$(alias_for "$name")"
  if [ -z "$alias" ] || [ "$alias" = "main" ]; then
    echo "publish-html: '$name' does not make a usable alias; pass --name <alias>." >&2
    exit 64
  fi

  ensure_auth
  ensure_project

  local tmp
  tmp="$(mktemp -d)"
  # Expand now: `tmp` is function-local and gone by the time EXIT fires.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  cp "$file" "$tmp/index.html"
  printf 'X-Robots-Tag: noindex\n' >"$tmp/_headers"

  local deployment_url url
  deployment_url="$(deploy_dir "$tmp" "$alias" "publish $name")"
  url="https://$alias.$PROJECT.pages.dev"

  record "$(jq -cn \
    --arg ts "$(date -u +%FT%TZ)" --arg file "$file" --arg name "$name" --arg alias "$alias" \
    --arg url "$url" --arg dep "$deployment_url" --arg project "$PROJECT" \
    '{event: "publish", ts: $ts, file: $file, name: $name, alias: $alias, url: $url, deployment_url: $dep, project: $project}')"

  echo "Published: $url"
  [ -n "$deployment_url" ] && echo "This version (immutable): $deployment_url"
  echo "Anyone with the link can open it (not indexed by search engines; not access controlled). Re-running updates the same link; unpublish with:"
  echo "  $CANVAS_HOME/scripts/canvas unpublish $alias"
}

mode="publish"
file=""
name=""
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    --unpublish) mode="unpublish"; target="${2:-}"; shift 2 ;;
    --list) mode="list"; shift ;;
    --name) name="${2:-}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "publish-html: unknown option $1" >&2; usage >&2; exit 64 ;;
    *) file="$1"; shift ;;
  esac
done

case "$mode" in
  list) do_list ;;
  unpublish)
    [ -z "$target" ] && { usage >&2; exit 64; }
    do_unpublish "$target"
    ;;
  publish)
    [ -z "$file" ] && { usage >&2; exit 64; }
    do_publish "$file" "$name"
    ;;
esac
