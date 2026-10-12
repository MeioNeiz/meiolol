#!/usr/bin/env bash
# Deploys origin/main to the box and signals the web loop, which builds and uploads the
# site at once (deploy/box.sh web start). Run in the background by
# deploy/hooks/reference-transaction; log in .git/meiolol-deploy.log. Pushes during a
# deploy coalesce into one more run.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
state=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/meiolol-deploy
lock=$state.lock
now() { date -u +%FT%TZ; }
touch "$state.pending"

# The lock dir holds the deploying process's pid. A deploy killed before it lets go (a
# reboot, kill -9) would hold it for good and every later push would skip deploying, so
# a lock whose pid is gone or no longer on-push.sh is broken (with no pid yet, once it is
# an hour old: the holder died between mkdir and writing it)
take_lock() {
    local pid
    mkdir "$lock" 2> /dev/null && { echo $$ > "$lock/pid"; return 0; }
    if pid=$(cat "$lock/pid" 2> /dev/null); then
        ps -p "$pid" -o command= 2> /dev/null | grep -q on-push.sh && return 1
    else
        [[ -n $(find "$lock" -maxdepth 0 -mmin +60 2> /dev/null) ]] || return 1
    fi
    echo "$(now) breaking a stale deploy lock (pid ${pid:-none})"
    rm -rf "$lock"
    mkdir "$lock" 2> /dev/null && { echo $$ > "$lock/pid"; return 0; }
    return 1
}
if ! take_lock; then
    echo "$(now) deploy already running (pid $(cat "$lock/pid" 2> /dev/null || echo '?')):" \
        "it deploys this push too"
    exit 0
fi
trap 'rm -rf "$lock"' EXIT
trap 'exit 1' INT TERM HUP
while [[ -e "$state.pending" ]]; do
    rm -f "$state.pending"
    # Docs and research pushes change nothing on the box: skip the build and site round
    deployed=$(ssh "${MEIOLOL_HOST:-meiolol-cloud}" "tail -n 1 ml/meiolol/DEPLOYED" 2> /dev/null \
        | cut -d' ' -f1)
    if [[ -n "$deployed" ]] && git -C "$ROOT" cat-file -e "$deployed^{commit}" 2> /dev/null \
        && git -C "$ROOT" diff --quiet "$deployed" origin/main -- src deploy build.zig build.zig.zon; then
        echo "$(now) origin/main: nothing to deploy since ${deployed:0:7}"
        continue
    fi
    echo "$(now) deploying origin/main"
    REV=origin/main "$ROOT/deploy/box.sh" web start || echo "$(now) failed"
done
rm -rf "$lock"
trap - EXIT
# A push that landed between the last check and rmdir
[[ -e "$state.pending" ]] && exec "$0"
exit 0
