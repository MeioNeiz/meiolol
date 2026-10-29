#!/usr/bin/env bash
# Site dev loop on the Mac: `meiolol dev` renders each page on request from data loaded
# once (default data/snap: deploy/box.sh snapshot), CSS and JS straight from
# src/site/static, at http://localhost:8080. `zig build backend --watch` rebuilds on any
# source edit; the server replaces itself with the new binary and open pages reload.
# One server serves every session: the shared tree's pages as they are, a build that
# fails keeping the last good one; started again it says where it runs and exits.
# Extra arguments go to `meiolol dev` (--port, --euw-only, --patch, ...). `--exports` first
# fetches the box's curves, builds, lean and Daily Draft files into $data (~1.2 GB): older
# curves files fail to load, so matchup pages and gold columns stay empty.
set -euo pipefail
cd "$(dirname "$0")/.."
data=${MEIOLOL_DEV_DATA:-data/snap}
[[ -f "$data/meiolol.db" ]] || { echo "no $data/meiolol.db: run deploy/box.sh snapshot"; exit 1; }
if [[ "${1:-}" == --exports ]]; then
    shift
    mkdir -p "$data/export"
    box=${MEIOLOL_HOST:-essex-vm}:ml/meiolol/data
    rsync -az --include='*curves*.bin' --include='*builds*.json' --exclude='*' \
        "$box/export/" "$data/export/"
    rsync -az "$box/daily/" "$data/daily/"
    rsync -az "$box/lean.tsv" "$data/"
fi
want=$(sed -n 's/^pub const version: u32 = \([0-9]*\);/\1/p' src/core/curvesfile.zig)
for f in "$data"/export/*curves*.bin; do
    [[ -f "$f" ]] || continue
    have=$(od -An -tu4 -j8 -N4 "$f" | tr -d ' ')
    [[ "$have" == "$want" ]] || echo "$f is curves v$have, this build reads v$want:" \
        "matchup pages stay empty (deploy/dev.sh --exports fetches the box's)"
done
port=8080
for ((i = 1; i <= $#; i++)); do
    [[ ${!i} == --port ]] && { j=$((i + 1)); port=${!j}; }
done
if pid=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2> /dev/null) && [[ -n $pid ]]; then
    echo "already serving: http://localhost:$port (pid $pid, $(ps -o args= -p "$pid" | cut -c1-60));" \
        "builds: .zig-cache/dev-watch.log"
    exit 0
fi
# Its own prefix, so other sessions' builds don't restart it. Outside the slots, so
# capped as one (slots.sh MEIOLOL_ZIG_JOBS)
prefix=zig-out/dev
deploy/slots.sh 1 zig build backend --prefix "$prefix"
MEIOLOL_ZIG_JOBS=2 zig build backend --watch --prefix "$prefix" > .zig-cache/dev-watch.log 2>&1 &
watch=$!
trap 'kill $watch 2> /dev/null' EXIT
"$prefix/bin/meiolol" dev --data "$data" "$@"
