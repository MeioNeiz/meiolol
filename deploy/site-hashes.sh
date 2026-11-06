#!/bin/sh
# deploy/site-hashes.sh [PATH...]: rewrites src/testdata/site-files.txt from a clean
# checkout of HEAD plus the working tree's PATHs (edits, new and deleted files there),
# never the whole working tree, whose other sessions' uncommitted page edits would land
# in the hashes and fail the pre-push ci. Then commit PATHs and site-files.txt together.
# SITE_HASHES_OUT=FILE: the result goes there instead, matching or not (commit.sh), and
# the working tree's site-files.txt stays as is. GEN_OUT=DIR: also `zig build uilint --
# --write` in that tree, its register and debt file copied to DIR (commit.sh); a file over
# its debt fails it, UILINT_GROW=1 (Jacob's ok) raises the debt instead (--grow)
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
rev=$(git -C "$root" rev-parse --verify HEAD) || exit 1
# A tree of its own, not pre-push's "ci": a commit never waits for a push's ci. A
# build slot, as zb.sh's test. It is reset at its next use
# shellcheck disable=SC2016 # the inner sh expands them
"$root/deploy/slots.sh" 1 "$root/deploy/build-tree.sh" hashes "$rev" sh -c '
    root=$1 short=$2 out=$3 gen=$4 grow=$5 tree=$(pwd)
    shift 5
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
        [ -z "$out" ] || cp src/testdata/site-files.txt "$out"
    elif [ -f .zig-cache/site-files.txt ]; then
        cp .zig-cache/site-files.txt "${out:-$root/src/testdata/site-files.txt}"
        echo "src/testdata/site-files.txt rewritten for $short"
    else
        tail -n 20 .zig-cache/site-hashes.log
        echo "site-hashes: the test failed before the site check"
        exit 1
    fi
    if [ -n "$gen" ]; then
        # Over the debt, --write keeps the old count: copied, it would commit a debt the
        # tree breaks
        if ! zig build uilint --cache-dir "$root/.zig-cache" -- --write $grow > .zig-cache/uilint.log 2>&1; then
            tail -n 20 .zig-cache/uilint.log
            echo "site-hashes: uilint failed; fix it, or UILINT_GROW=1 with Jacob'\''s ok to raise the debt"
            exit 1
        fi
        cp docs/plan/ui/components.md src/site/ui/uilint-debt.txt "$gen/" || exit 1
    fi' _ "$root" "$(git -C "$root" rev-parse --short "$rev")" "${SITE_HASHES_OUT:-}" "${GEN_OUT:-}" "${UILINT_GROW:+--grow}" "$@"
