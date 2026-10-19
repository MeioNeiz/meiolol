#!/usr/bin/env bash
# deploy/mock-cs.sh [SCENARIO] [--window] [--role R] [mock options]: a scripted champ
# select (and game) without League. Starts the mock client (src/lcu/mock.zig) on a
# scenario from testdata/lcu/scenarios (default full-game; `list` lists them) and points
# `meiolol-app watch` at it, or with --window the desktop window (SDL3 dev build:
# `brew install sdl3` on the Mac). Mock options pass through: --speed X, --manual (Enter
# plays each step), --loop, --hold SECS. Stats: data/desktop/stats-all.bin, else the
# newest in data/export; curves the all-region recent ones of the version this reads.
# In-game probes while it plays: curl -s 127.0.0.1:2999/liveclientdata/allgamedata;
# MEIOLOL_LOCKFILE=zig-out/mock-cs/lockfile zig-out/bin/meiolol-app get PATH
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD
dir=testdata/lcu/scenarios
scenario=full-game
window=0
role=()
mock_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        list)
            for f in "$dir"/*.json; do
                n=$(basename "$f" .json)
                [ "$n" = champions ] && continue
                printf '%s: %s\n' "$n" "$(sed -n 's/.*"_comment": "\(.*\)",*$/\1/p' "$f" | head -1)"
            done
            exit 0
            ;;
        --window) window=1 ;;
        --role) role=(--role "$2"); shift ;;
        --manual | --loop) mock_args+=("$1") ;;
        --speed | --hold) mock_args+=("$1" "$2"); shift ;;
        -*) echo "unknown option $1 (see the top of $0)" >&2; exit 2 ;;
        *) scenario=$1 ;;
    esac
    shift
done
case "$scenario" in
    */* | *.json) path=$scenario ;;
    *) path=$dir/$scenario.json ;;
esac
[ -f "$path" ] || { echo "no scenario $path (deploy/mock-cs.sh list)" >&2; exit 1; }

# The window finds its data in data/export under its working directory
run=zig-out/mock-cs
mkdir -p "$run/data/export"
rm -f "$run"/data/export/*.bin
if [ -f data/desktop/stats-all.bin ]; then
    ln -s "$root/data/desktop/stats-all.bin" "$run/data/export/stats-all.bin"
else
    f=$(ls -t data/export/stats-*.bin 2>/dev/null | head -1)
    [ -n "$f" ] && ln -s "$root/$f" "$run/data/export/$(basename "$f")"
fi
# All-region curves this build reads (an older version fails to load: no lane gold);
# deploy/dev.sh --exports refreshes data/snap's
want=$(sed -n 's/^pub const version: u32 = \([0-9]*\);/\1/p' src/core/curvesfile.zig)
for f in data/snap/export/all-recent-curves.bin data/desktop/all-recent-curves.bin \
    data/desktop/recent-curves.bin data/export/recent-curves.bin; do
    [ -f "$f" ] && [ "$(od -An -tu4 -j8 -N4 "$f" | tr -d ' ')" = "$want" ] || continue
    ln -s "$root/$f" "$run/data/export/recent-curves.bin"
    break
done
stats=$(ls "$run"/data/export/stats-*.bin 2>/dev/null | head -1)
[ -n "$stats" ] || { echo "no stats file in data/desktop or data/export" >&2; exit 1; }

steps=(mock-lcu-install)
if [ $window = 1 ]; then
    steps+=(desktop-dev-install -Ddev-window -fsys=sdl3)
    [ -d /opt/homebrew ] && steps+=(--search-prefix /opt/homebrew)
else
    steps+=(app)
fi
zig build "${steps[@]}"

lock=$root/$run/lockfile
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT INT TERM
if [ $window = 1 ]; then
    (cd "$run" && MEIOLOL_LOCKFILE=$lock exec "$root/zig-out/bin/meiolol-desktop-dev") &
else
    MEIOLOL_LOCKFILE=$lock zig-out/bin/meiolol-app watch --stats "$stats" ${role[@]+"${role[@]}"} &
fi
pids+=($!)
# Foreground: --manual reads Enter here, and the step lines show what the app should show
zig-out/bin/meiolol-mock-lcu "$path" --lockfile "$lock" ${mock_args[@]+"${mock_args[@]}"}
