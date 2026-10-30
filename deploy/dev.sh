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
# Page checks and screenshots (team lanes): `--small` serves $data-small, 1 in 20 of
# $data's games (deploy/snap-small.sh, built on first use and when $data is newer), loaded
# in ~100 s where data/snap takes ~22 min. `--no-watch`: one build, then serve, so edits
# meanwhile don't restart the load
set -euo pipefail
cd "$(dirname "$0")/.."
data=${MEIOLOL_DEV_DATA:-data/snap}
[[ -f "$data/meiolol.db" ]] || { echo "no $data/meiolol.db: run deploy/box.sh snapshot"; exit 1; }
exports=false small=false watch=true
args=()
for a in "$@"; do
    case $a in
        --exports) exports=true ;;
        --small) small=true ;;
        --no-watch) watch=false ;;
        *) args+=("$a") ;;
    esac
done
if $exports; then
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
for ((i = 0; i + 1 < ${#args[@]}; i++)); do
    [[ ${args[i]} == --port ]] && port=${args[i + 1]}
done
if pid=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2> /dev/null) && [[ -n $pid ]]; then
    echo "already serving: http://localhost:$port (pid $pid, $(ps -o args= -p "$pid" | cut -c1-60));" \
        "builds: .zig-cache/dev-watch.log"
    exit 0
fi
# Worktree lanes each start one. A server on data/snap holds 3+ GB, plus ~8 GB of cache
# while it loads: five at once with their watch builds and tests hung the gpu-box's WSL
# (29 Oct, docs/compute.md "WSL memory"). Small ones count apart: ~1.3 GB private each,
# their 1.2 GB database and the curves shared in the page cache
if $small; then
    max=${MEIOLOL_DEV_MAX_SMALL:-3} kind=small
else
    max=${MEIOLOL_DEV_MAX:-2} kind=full
fi
same=()
# Anchored on the binary: a shell whose command line names it isn't one
for pid in $(pgrep -u "$USER" -f '^[^ ]*/meiolol dev( |$)' || true); do
    a=$(ps -o args= -p "$pid" || true)
    if [[ $a =~ --data\ [^\ ]*-small( |$) ]]; then k=small; else k=full; fi
    [[ $k == "$kind" ]] && same+=("$pid $(cut -c1-110 <<< "$a")")
done
if ((${#same[@]} >= max)); then
    echo "dev.sh: $max $kind dev servers already run here: use one of them," \
        "or stop yours when done (kill PID):"
    printf '  %s\n' "${same[@]}"
    exit 1
fi
if $small; then
    small_dir=${data%/}-small
    deploy/snap-small.sh "$data" "$small_dir"
    data=$small_dir
fi
# Its own prefix, so other sessions' builds don't restart it. Outside the slots, so
# capped as one (slots.sh MEIOLOL_ZIG_JOBS)
prefix=zig-out/dev
deploy/slots.sh 1 zig build backend --prefix "$prefix"
if $watch; then
    MEIOLOL_ZIG_JOBS=2 zig build backend --watch --prefix "$prefix" > .zig-cache/dev-watch.log 2>&1 &
    watch_pid=$!
    trap 'kill $watch_pid 2> /dev/null' EXIT
fi
"$prefix/bin/meiolol" dev --data "$data" ${args[@]+"${args[@]}"}
