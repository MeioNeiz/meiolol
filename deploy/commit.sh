#!/usr/bin/env bash
# deploy/commit.sh [git commit options] -- PATHS: commit by path (CLAUDE.md), adding the
# untracked files among PATHS first, as `git commit -- PATHS` refuses a path git doesn't
# know ("pathspec did not match"). Only PATHS are staged and committed; others' staged
# or dirty files stay out. On a failed commit the files it added are unstaged again.
# A commit touching src/ or build.zig also gets src/testdata/site-files.txt rewritten
# for its own tree (deploy/site-hashes.sh PATHS) and committed with it, so a page change
# never needs a hand step; skip with SITE_HASHES=0. That file goes in through a commit
# index of its own, never the working tree's copy, which another session's site-hashes
# run for its uncommitted work may have rewritten (bcf6dc3 carried such hashes).
# The subject (first -m) is one short line; detail goes in a second -m, the body: every
# session's opening context and `git log --oneline` carry subjects. Doc pages in PATHS
# must not get worse than at HEAD (over budget and growing, or new dated-story lines):
# the context-review skill's gate, budgets in .claude/doc-rules.json; skip CONTEXT_GATE=0.
set -euo pipefail
opts=()
subject=""
while [ $# -gt 0 ] && [ "$1" != -- ]; do
    case "$1" in
        -m) [ -n "$subject" ] || subject=${2:-} ;;
        -m*) [ -n "$subject" ] || subject=${1#-m} ;;
        --message=*) [ -n "$subject" ] || subject=${1#--message=} ;;
    esac
    opts+=("$1")
    shift
done
usage="usage: deploy/commit.sh -m SUBJECT [-m BODY] [opts] -- PATH..."
[ $# -gt 1 ] || { echo "$usage" >&2; exit 2; }
shift
subject=${subject%%$'\n'*}
max=$(jq -r '.commits.subjectMax // 90' .claude/doc-rules.json 2>/dev/null) || max=90
if [ ${#subject} -gt "$max" ]; then
    echo "commit subject is ${#subject} chars, max $max: say what changed in one line," >&2
    echo "and put the detail in a second -m (the body)" >&2
    exit 2
fi
gate="$HOME/.claude/skills/context-review/check.mjs"
if [ "${CONTEXT_GATE:-1}" != 0 ] && [ -f "$gate" ]; then
    node "$gate" --gate "$@" || exit 1
fi
new=()
while IFS= read -r f; do
    new+=("$f")
done < <(git ls-files --others --exclude-standard -- "$@")
if [ ${#new[@]} -gt 0 ]; then
    git add -- "${new[@]}"
    echo "added: ${new[*]}"
fi
hashes=src/testdata/site-files.txt
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
made=""
if [ "${SITE_HASHES:-1}" != 0 ] \
    && git ls-files --cached --others --exclude-standard -- "$@" \
        | grep -vxF "$hashes" | grep -qE '^(src/|build\.zig)'; then
    sources=()
    for p in "$@"; do
        [ "$p" = "$hashes" ] || sources+=("$p")
    done
    # Another session's commit landing during the ~15 s run changes the base: redo
    for _ in 1 2 3; do
        head=$(git rev-parse HEAD)
        SITE_HASHES_OUT="$tmp/site-files.txt" deploy/site-hashes.sh "${sources[@]}" || {
            [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
            echo "site-hashes failed; fix it, or SITE_HASHES=0 to commit anyway" >&2
            exit 1
        }
        [ "$(git rev-parse HEAD)" = "$head" ] && break
    done
    git show "HEAD:$hashes" | cmp -s - "$tmp/site-files.txt" || made="$tmp/site-files.txt"
fi
if [ -z "$made" ]; then
    if ! git commit ${opts[@]+"${opts[@]}"} -- "$@"; then
        [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
        exit 1
    fi
    exit 0
fi
clean=0
git diff --quiet HEAD -- "$hashes" && clean=1
# HEAD, PATHS as in the working tree, and the made hashes. git commit's own ref update
# fails if HEAD moves meanwhile, and the hooks read this index (":path")
export GIT_INDEX_FILE="$tmp/index"
git read-tree HEAD
git add -A -- "${sources[@]}"
git update-index --add --cacheinfo "100644,$(git hash-object -w "$made"),$hashes"
if ! git commit ${opts[@]+"${opts[@]}"}; then
    unset GIT_INDEX_FILE
    [ ${#new[@]} -eq 0 ] || git reset -q -- "${new[@]}"
    exit 1
fi
unset GIT_INDEX_FILE
# The shared index follows the new HEAD for these paths. The working tree's
# site-files.txt follows too if it was clean, else keeps what another session wrote
git reset -q -- "${sources[@]}" "$hashes"
[ "$clean" = 0 ] || cp "$made" "$hashes"
