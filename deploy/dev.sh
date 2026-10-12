#!/usr/bin/env bash
# Site dev loop on the Mac: `meiolol dev` renders each page on request from data loaded
# once (default data/snap: deploy/box.sh snapshot), CSS and JS straight from
# src/site/static, at http://localhost:8080. `zig build --watch` rebuilds on any source
# edit; the server replaces itself with the new binary and open pages reload. Extra
# arguments go to `meiolol dev` (--port, --euw-only, --patch, ...).
set -euo pipefail
cd "$(dirname "$0")/.."
data=${MEIOLOL_DEV_DATA:-data/snap}
[[ -f "$data/meiolol.db" ]] || { echo "no $data/meiolol.db: run deploy/box.sh snapshot"; exit 1; }
# Its own prefix, so other sessions' builds don't restart it
prefix=zig-out/dev
zig build --prefix "$prefix"
zig build --watch --prefix "$prefix" > .zig-cache/dev-watch.log 2>&1 &
watch=$!
trap 'kill $watch 2> /dev/null' EXIT
"$prefix/bin/meiolol" dev --data "$data" "$@"
