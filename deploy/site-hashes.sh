#!/bin/sh
# deploy/site-hashes.sh [PATH...]: rewrites src/testdata/site-files.txt from a clean
# checkout of HEAD plus the working tree's PATHs (edits, new and deleted files there),
# never the whole working tree, whose other sessions' uncommitted page edits would land
# in the hashes and fail the pre-push ci. Then commit PATHs and site-files.txt together.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
rev=$(git -C "$root" rev-parse --verify HEAD) || exit 1
# The ci tree: its zig cache is warm from every pre-push. It is reset at its next use
# shellcheck disable=SC2016 # the inner sh expands them
"$root/deploy/build-tree.sh" ci "$rev" sh -c '
    root=$1 short=$2 tree=$(pwd)
    shift 2
    if [ $# -gt 0 ]; then
        git -C "$root" diff --binary HEAD -- "$@" | git apply --allow-empty || exit 1
        git -C "$root" ls-files -z --others --exclude-standard -- "$@" \
            | (cd "$root" && xargs -0 -I{} rsync -R {} "$tree/") || exit 1
        short="$short + $*"
    fi
    mkdir -p .zig-cache
    rm -f .zig-cache/site-files.txt
    if zig build test -Dtest-filter="fixture games to stats, curves and the website" \
        --cache-dir "$root/.zig-cache" > .zig-cache/site-hashes.log 2>&1; then
        echo "site-files.txt already matches $short"
    elif [ -f .zig-cache/site-files.txt ]; then
        cp .zig-cache/site-files.txt "$root/src/testdata/site-files.txt"
        echo "src/testdata/site-files.txt rewritten for $short"
    else
        tail -n 20 .zig-cache/site-hashes.log
        echo "site-hashes: the test failed before the site check"
        exit 1
    fi' _ "$root" "$(git -C "$root" rev-parse --short "$rev")" "$@"
