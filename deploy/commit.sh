#!/usr/bin/env bash
# deploy/commit.sh [git commit options] -- PATHS: commit by path (CLAUDE.md), adding the
# untracked files among PATHS first, as `git commit -- PATHS` refuses a path git doesn't
# know ("pathspec did not match"). Only PATHS are staged and committed; others' staged
# or dirty files stay out. On a failed commit the files it added are unstaged again.
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
if ! git commit ${opts[@]+"${opts[@]}"} -- "$@"; then
    [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
    exit 1
fi
