#!/usr/bin/env bash
# deploy/commit.sh [git commit options] -- PATHS: commit by path (CLAUDE.md), adding the
# untracked files among PATHS first, as `git commit -- PATHS` refuses a path git doesn't
# know ("pathspec did not match"). Only PATHS are staged and committed; others' staged
# or dirty files stay out. On a failed commit the files it added are unstaged again.
# A commit touching src/ or build.zig also gets src/testdata/site-files.txt rewritten
# for its own tree (deploy/site-hashes.sh PATHS) and committed with it, so a page change
# never needs a hand step; skip with SITE_HASHES=0.
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
