#!/usr/bin/env bash
# deploy/commit.sh [git commit options] -- PATHS: commit by path (CLAUDE.md), adding the
# untracked files among PATHS first, as `git commit -- PATHS` refuses a path git doesn't
# know ("pathspec did not match"). Only PATHS are staged and committed; others' staged
# or dirty files stay out. On a failed commit the files it added are unstaged again.
# A commit touching src/ or build.zig also gets src/testdata/site-files.txt rewritten
# for its own tree (deploy/site-hashes.sh PATHS) and committed with it, so a page change
# never needs a hand step; skip with SITE_HASHES=0.
set -euo pipefail
opts=()
while [ $# -gt 0 ] && [ "$1" != -- ]; do
    opts+=("$1")
    shift
done
[ $# -gt 1 ] || { echo "usage: deploy/commit.sh -m MSG [opts] -- PATH..." >&2; exit 2; }
shift
new=()
while IFS= read -r f; do
    new+=("$f")
done < <(git ls-files --others --exclude-standard -- "$@")
if [ ${#new[@]} -gt 0 ]; then
    git add -- "${new[@]}"
    echo "added: ${new[*]}"
fi
hashes=src/testdata/site-files.txt
paths=("$@")
if [ "${SITE_HASHES:-1}" != 0 ] \
    && git ls-files --cached --others --exclude-standard -- "$@" \
        | grep -vxF "$hashes" | grep -qE '^(src/|build\.zig)'; then
    # Another session's commit landing during the ~15 s run changes the base: redo
    for _ in 1 2 3; do
        head=$(git rev-parse HEAD)
        deploy/site-hashes.sh "$@" || {
            [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
            echo "site-hashes failed; fix it, or SITE_HASHES=0 to commit anyway" >&2
            exit 1
        }
        [ "$(git rev-parse HEAD)" = "$head" ] && break
    done
    [ -z "$(git status --porcelain -- "$hashes")" ] || paths+=("$hashes")
fi
if ! git commit ${opts[@]+"${opts[@]}"} -- "${paths[@]}"; then
    [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
    exit 1
fi
