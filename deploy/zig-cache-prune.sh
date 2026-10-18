#!/usr/bin/env bash
# deploy/zig-cache-prune.sh [MAX_GB]: empties the repo's .zig-cache (shared by the
# working tree and the ci and box build trees; ~17 GB a day) once it holds more than
# MAX_GB (default 40) and no zig build runs. on-push.sh runs it after each deploy.
# All or nothing: o/ entries can't go by age, as a manifest in h/ rewritten since may
# name an old one, and the build then fails (18 Oct: "unable to load options.zig:
# FileNotFound"). Logs beside them stay. The next builds start cold (ci ~2 min more)
set -u
ROOT=${MEIOLOL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
cache=$ROOT/.zig-cache
max=${1:-40}
[[ -d $cache/o ]] || exit 0
kb=$(du -sk "$cache" | cut -f1)
(( kb > max * 1024 * 1024 )) || exit 0
# The compiler, and the build runners it compiles into a cache's o/
if pgrep -x zig > /dev/null || pgrep -f '\.zig-cache/o/[0-9a-f]+/build ' > /dev/null; then
    echo "zig-cache-prune: $((kb / 1048576)) GB, but a zig build is running: left for next time"
    exit 0
fi
old=$(mktemp -d "$cache/prune.XXXXXX")
for d in o h z tmp; do [[ -e $cache/$d ]] && mv "$cache/$d" "$old/"; done
rm -rf "$old"
echo "zig-cache-prune: freed $((kb / 1048576)) GB"
