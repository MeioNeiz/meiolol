#!/usr/bin/env bash
# The UI sweep (deploy/qa.mjs): overflow, small text, tap targets, console errors and
# failed requests on each page type at 320-1280, and the gallery's components in 320 and
# 390 px containers. Warnings only. Without a URL it builds the backend with -Dwasm-dev
# (ui.wasm safety checks, zjb handle leaks as console errors), serves data/snap on a
# spare port and stops it after.
#   deploy/qa.sh [URL] [--webkit] [--shots DIR] [--only /a.html,/b.html]
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" =~ ^https?:// ]]; then
  exec node deploy/qa.mjs "$@"
fi

port=8097
deploy/slots.sh 1 zig build backend -Dwasm-dev --prefix zig-out/qa
log=$(mktemp)
zig-out/qa/bin/meiolol dev --data data/snap --port "$port" >"$log" 2>&1 &
pid=$!
trap 'kill $pid 2>/dev/null || true; rm -f "$log"' EXIT
for _ in $(seq 1 120); do
  curl -sf -o /dev/null "http://localhost:$port/" && break
  kill -0 $pid 2>/dev/null || { cat "$log"; exit 1; }
  sleep 1
done
node deploy/qa.mjs "http://localhost:$port" "$@"
