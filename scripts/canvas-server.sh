#!/usr/bin/env bash
# Manage the local canvas dev server (Vite, bound to 127.0.0.1 only).
#
# Usage: canvas-server.sh start|stop|status|url
set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

cmd="${1:-status}"

start_server() {
  if server_is_running; then
    echo "canvas server already running at $CANVAS_URL"
    return 0
  fi
  ensure_node || {
    echo "agent-canvas: node is not available; cannot start the server." >&2
    return 1
  }
  ensure_runtime_installed || return 1

  # Clear a stale pidfile; the port is free, so whatever it pointed at is gone.
  rm -f "$CANVAS_PIDFILE"

  # The server must outlive the shell that started it. Agent tool shells kill
  # their whole process group on completion, which nohup alone does not
  # survive, so detach into a new session with setsid where available.
  local launcher=(nohup)
  if command -v setsid >/dev/null 2>&1; then
    launcher=(setsid nohup)
  fi
  (
    cd "$CANVAS_RUNTIME_DIR" || exit 1
    CANVAS_PORT="$CANVAS_PORT" exec "${launcher[@]}" ./node_modules/.bin/vite >"$CANVAS_LOGFILE" 2>&1 </dev/null
  ) &
  local spawned=$!

  local attempt
  for attempt in $(seq 1 60); do
    if server_is_running; then
      { listening_pid || echo "$spawned"; } >"$CANVAS_PIDFILE"
      echo "canvas server started at $CANVAS_URL (pid $(cat "$CANVAS_PIDFILE"), attempt $attempt)"
      return 0
    fi
    sleep 0.25
  done
  echo "agent-canvas: server did not become ready. Last log lines:" >&2
  tail -n 20 "$CANVAS_LOGFILE" >&2
  return 1
}

stop_server() {
  local pid=""
  if [ -f "$CANVAS_PIDFILE" ]; then
    pid="$(cat "$CANVAS_PIDFILE")"
  fi
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    sleep 0.3
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    echo "canvas server stopped (pid $pid)"
  elif server_is_running; then
    echo "agent-canvas: something is listening on $CANVAS_URL but it was not started by this script; not stopping it." >&2
    return 1
  else
    echo "canvas server is not running"
  fi
  rm -f "$CANVAS_PIDFILE"
}

case "$cmd" in
  start) start_server ;;
  stop) stop_server ;;
  status)
    if server_is_running; then
      echo "running at $CANVAS_URL${CANVAS_PIDFILE:+ (pid $(cat "$CANVAS_PIDFILE" 2>/dev/null || echo '?'))}"
    else
      echo "not running"
      exit 1
    fi
    ;;
  url) echo "$CANVAS_URL" ;;
  *)
    echo "usage: canvas-server.sh start|stop|status|url" >&2
    exit 64
    ;;
esac
