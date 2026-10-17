#!/bin/sh
# deploy/site-hashes.sh [REV]: rewrites src/testdata/site-files.txt from a clean checkout
# of REV (default HEAD), never the working tree, whose other sessions' uncommitted page
# edits would land in the hashes and fail the pre-push ci. Commit the page change, run
# this, commit site-files.txt.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
rev=$(git -C "$root" rev-parse --verify "${1:-HEAD}^{commit}") || exit 1
# The ci tree: its zig cache is warm from every pre-push
"$root/deploy/build-tree.sh" ci "$rev" sh -c '
    rm -f .zig-cache/site-files.txt
    if zig build test -Dtest-filter="fixture games to stats, curves and the website" \
        --cache-dir "$1/.zig-cache" > .zig-cache/site-hashes.log 2>&1; then
        echo "site-files.txt already matches $2"
    elif [ -f .zig-cache/site-files.txt ]; then
        cp .zig-cache/site-files.txt "$1/src/testdata/site-files.txt"
        echo "src/testdata/site-files.txt rewritten for $2"
    else
        tail -n 20 .zig-cache/site-hashes.log
        echo "site-hashes: the test failed before the site check"
        exit 1
    fi' _ "$root" "$(git -C "$root" rev-parse --short "$rev")"
