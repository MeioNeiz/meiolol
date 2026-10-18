#!/bin/sh
# deploy/build-tree.sh NAME REV CMD [ARG...]: runs CMD in a clean checkout of REV that
# lives at a fixed path (.git/meiolol-build/NAME), never the working tree: other sessions
# keep uncommitted work there. The path is fixed because Zig's cache keys include it: a
# fresh checkout per run rebuilt everything (pre-push ci ~2 min instead of ~30 s).
# One user per tree at a time (a lock beside it, freed if its holder died); ignored
# files (zig-out, zig-pkg) stay between runs.
name=$1 rev=$2
shift 2
# Hooks may export these; they would point checkout --force and clean at the main tree
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX
# Zig through the ~/.local/bin shim (build.zig.zon's pinned version): a plain PATH can
# find Homebrew's older zig first
export PATH="$HOME/.local/bin:$PATH"
# MEIOLOL_ROOT: the repo when this runs from on-push.sh's snapshot of deploy/
repo=${MEIOLOL_ROOT:-$(dirname "$0")}
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir) || exit 1
tree="$common/meiolol-build/$name"
lock="$tree.lock"
mkdir -p "$common/meiolol-build"
while ! mkdir "$lock" 2> /dev/null; do
    pid=$(cat "$lock/pid" 2> /dev/null)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
        rm -rf "$lock"
        continue
    fi
    [ -n "${said:-}" ] || { echo "build-tree: waiting for $name (pid ${pid:-?})"; said=1; }
    sleep 2
done
echo $$ > "$lock/pid"
trap 'rm -rf "$lock"' EXIT
trap 'exit 130' INT TERM
if [ -f "$tree/.git" ] && [ "$(git -C "$tree" rev-parse --show-toplevel)" = "$tree" ]; then
    git -C "$tree" checkout -q --force --detach "$rev" && git -C "$tree" clean -qfd || exit 1
else
    rm -rf "$tree"
    git -C "$repo" worktree prune
    git -C "$repo" worktree add -q --detach "$tree" "$rev" || exit 1
fi
cd "$tree" && "$@"
