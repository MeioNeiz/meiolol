#!/usr/bin/env bash
# deploy/zig-cache-prune.sh [MAX_GB [TREE_MAX_GB]]: empties the repo's .zig-cache (the
# working tree's and most build trees'; ~40 GB a day) once it holds more than MAX_GB
# (default 40) and no zig build runs; and each build tree's own cache
# (.git/meiolol-build/NAME.cache: ci, box) past TREE_MAX_GB (default 20), under that
# tree's lock (deploy/build-tree.sh), so never under its build. on-push.sh runs it after
# each deploy.
# All or nothing: o/ entries can't go by age, as a manifest in h/ rewritten since may
# name an old one, and the build then fails (18 Oct: "unable to load options.zig:
# FileNotFound"). Logs beside them stay. The next builds start cold (ci ~2 min more)
set -u
ROOT=${MEIOLOL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
max=${1:-40}
tree_max=${2:-20}

over() {
    local kb
    kb=$(du -sk "$1" | cut -f1)
    (( kb > $2 * 1024 * 1024 )) && echo $((kb / 1048576))
}

# Moves the cache's contents aside (fast, so a lock is held only for that), then removes
empty() {
    local d
    old=$(mktemp -d "$1/prune.XXXXXX")
    for d in o h z tmp; do [[ -e $1/$d ]] && mv "$1/$d" "$old/"; done
}
remove() { rm -rf "$old" || { echo "zig-cache-prune: $old not fully removed"; return 1; }; }

code=0
cache=$ROOT/.zig-cache
if [[ -d $cache/o ]]; then
    # Left by a prune killed mid-rm; no build reads them
    rm -rf "$cache"/prune.*
    if gb=$(over "$cache" "$max"); then
        # zig, its build runner (maker) and test binaries name this cache in their
        # arguments; builds with another cache don't count
        if pgrep -f "$cache" > /dev/null; then
            echo "zig-cache-prune: $gb GB, but a zig build is running: left for next time"
        else
            empty "$cache"
            remove && echo "zig-cache-prune: freed $gb GB" || code=1
        fi
    fi
fi

common=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir) || exit 1
lock=""
trap '[ -z "$lock" ] || rm -rf "$lock"' EXIT
for cache in "$common"/meiolol-build/*.cache; do
    [[ -d $cache/o ]] || continue
    rm -rf "$cache"/prune.*
    gb=$(over "$cache" "$tree_max") || continue
    name=${cache##*/}
    # build-tree.sh's lock: a holder, live or dead, leaves it for next time
    if ! mkdir "${cache%.cache}.lock" 2> /dev/null; then
        echo "zig-cache-prune: ${name%.cache} tree $gb GB, but in use: left for next time"
        continue
    fi
    lock=${cache%.cache}.lock
    echo $$ > "$lock/pid"
    empty "$cache"
    rm -rf "$lock"
    lock=""
    remove && echo "zig-cache-prune: freed $gb GB of the ${name%.cache} tree's cache" || code=1
done
exit $code
