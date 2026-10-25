#!/bin/bash
# deploy/push.sh [REV]: push REV (default HEAD) to main under the team build lock, grouped
# with the other queued pushes: the pre-push ci (~1-2 min) runs once, on the newest queued
# commit that contains REV, and a push that lands REV ends the wait. Only commits a session
# asked to push go out with it; if the group's ci fails, the next newest is tried, down
# to REV alone, and the failed commit is left out of later groups.
set -o pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
q=${MEIOLOL_PUSH_QUEUE:-$HOME/.cache/meiolol-push}
lock=${MEIOLOL_LOCK:-$HOME/.cache/meiolol-zig.lock}
mkdir -p "$q"
cd "$root" || exit 1

pushed() { git merge-base --is-ancestor "$1" refs/remotes/origin/main 2> /dev/null; }

if [ "${1-}" != --locked ]; then
    rev=$(git rev-parse --verify "${1:-HEAD}^{commit}") || exit 2
    req=$q/$$
    echo "$rev" > "$req"
    trap 'rm -f "$req"' EXIT
    while :; do
        if pushed "$rev"; then
            echo "push: $(git rev-parse --short "$rev") is on main"
            exit 0
        fi
        lockf -s -t 0 "$lock" "$0" --locked "$rev"
        code=$?
        [ $code = 75 ] || exit $code
        sleep 1
    done
fi
rev=$2
pushed "$rev" && { echo "push: $(git rev-parse --short "$rev") is on main"; exit 0; }

# The newest queued commit containing rev and every other queued one that contains it,
# leaving out commits whose ci failed; on a failure, the next newest
newest() {
    local f s top=$rev
    for f in "$q"/*; do
        [ -f "$f" ] || continue
        s=$(cat "$f")
        [ -f "$q/failed/$s" ] && continue
        git merge-base --is-ancestor "$rev" "$s" 2> /dev/null || continue
        git merge-base --is-ancestor "$top" "$s" 2> /dev/null && top=$s
    done
    echo "$top"
}
mkdir -p "$q/failed"
while top=$(newest) && [ "$top" != "$rev" ]; do
    echo "push: grouped: $(git rev-parse --short "$rev") goes with $(git rev-parse --short "$top")"
    git push origin "$top:main" && exit 0
    touch "$q/failed/$top"
    echo "push: the group failed without $(git rev-parse --short "$top")"
done
git push origin "$rev:main"
