#!/usr/bin/env bash
# Deploys origin/main to the box and signals the web loop, which builds and uploads the
# site at once (deploy/box.sh web start). Run in the background by
# deploy/hooks/reference-transaction; log in .git/meiolol-deploy.log. Pushes during a
# deploy coalesce into one more run.
set -u
# Zig through the ~/.local/bin shim (build.zig.zon's pinned version): a plain PATH can
# find Homebrew's older zig first
export PATH="$HOME/.local/bin:$PATH"
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
# Steps for the admin page's Deploys tab (deploy-events.sh: queued here, sent to the box
# at each flush). box.sh's output lines mark the build's end and the web loop's signal;
# the box's scripts add the rest (render-swap.sh, web-loop.sh, cache-version.sh)
events=$ROOT/deploy/deploy-events.sh
event() { "$events" add "$@"; }
flush() { "$events" flush || echo "$(now) deploy events not sent: box unreachable, kept for the next deploy"; }
# The deploy's commits after the one deployed before, newest first, at most 30; subjects
# run to 1,300 characters, so the cap only guards live.json against a runaway one
commits() {
    local range=("$2" --max-count=1)
    [[ -n "$1" ]] && git -C "$ROOT" cat-file -e "$1^{commit}" 2> /dev/null && range=("$1..$2" --max-count=30)
    git -C "$ROOT" log --format='%h %s' "${range[@]}" | cut -c1-2000 \
        | while IFS= read -r c; do event "$2" commit info "$c"; done
}
while [[ -e "$state.pending" ]]; do
    rm -f "$state.pending"
    sha=$(git -C "$ROOT" rev-parse origin/main)
    # Docs and research pushes change nothing on the box: skip the build and site round
    deployed=$(ssh "${MEIOLOL_HOST:-meiolol-cloud}" "tail -n 1 ml/meiolol/DEPLOYED" 2> /dev/null \
        | cut -d' ' -f1)
    if [[ -n "$deployed" ]] && git -C "$ROOT" cat-file -e "$deployed^{commit}" 2> /dev/null \
        && git -C "$ROOT" diff --quiet "$deployed" "$sha" -- src deploy build.zig build.zig.zon; then
        echo "$(now) origin/main: nothing to deploy since ${deployed:0:7}"
        if [[ "$sha" != "$deployed" ]]; then
            commits "$deployed" "$sha"
            event "$sha" deploy skipped "nothing to deploy since ${deployed:0:7}: no change in src, deploy or build files"
            flush
        fi
        continue
    fi
    echo "$(now) deploying origin/main"
    commits "$deployed" "$sha"
    event "$sha" deploy start "deploy/box.sh web start on the Mac"
    event "$sha" build start "clean checkout, cross-compile and copy to the box"
    flush
    out=$(mktemp)
    REV=$sha "$ROOT/deploy/box.sh" web start 2>&1 | while IFS= read -r line; do
        echo "$line"
        echo "$line" >> "$out"
        case $line in
            "deployed "*) event "$sha" build ok "binary and scripts on the box"; flush ;;
            "signalled meiolol-web"* | "restarted meiolol-web"*) event "$sha" web ok "${line% on *}" ;;
        esac
    done
    rc=${PIPESTATUS[0]}
    if (( rc == 0 )); then
        event "$sha" deploy ok "box.sh done: the box takes it from here"
    else
        echo "$(now) failed"
        grep -q '^deployed ' "$out" || event "$sha" build failed "$(grep -v '^ *$' "$out" | tail -n 1)"
        event "$sha" deploy failed "$(grep -v '^ *$' "$out" | tail -n 1)"
    fi
    rm -f "$out"
    flush
done
rm -rf "$lock"
trap - EXIT
# A push that landed between the last check and rmdir
[[ -e "$state.pending" ]] && exec "$0"
exit 0
