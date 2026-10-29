#!/usr/bin/env bash
# Deploys origin/main to the box and signals the web loop, which builds and uploads the
# site at once (deploy/box.sh web start). Run in the background by
# deploy/hooks/reference-transaction; log in .git/meiolol-deploy.log. Pushes during a
# deploy coalesce into one more run.
set -u
# Zig through the ~/.local/bin shim (build.zig.zon's pinned version): a plain PATH can
# find Homebrew's older zig first
export PATH="$HOME/.local/bin:$PATH"
# Each run is origin/main's own deploy/, from a temp dir, never the working tree's: an
# edit in progress there broke every deploy for an hour (18 Oct). Bash runs this block
# before it reads on, so of the working tree's copy only these lines ever run
if [[ -z ${MEIOLOL_DEPLOY_SNAP:-} ]]; then
    root=${MEIOLOL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
    touch "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)/meiolol-deploy.pending"
    sha=$(git -C "$root" rev-parse origin/main) || exit 1
    snap=$(mktemp -d "${TMPDIR:-/tmp}/meiolol-deploy.XXXXXX")
    git -C "$root" archive "$sha" deploy | tar -x -C "$snap" || { rm -rf "$snap"; exit 1; }
    MEIOLOL_ROOT=$root MEIOLOL_DEPLOY_SNAP=$snap MEIOLOL_DEPLOY_SHA=$sha \
        exec bash "$snap/deploy/on-push.sh"
fi
[[ -n ${MEIOLOL_DEPLOY_OLD:-} ]] && rm -rf "$MEIOLOL_DEPLOY_OLD"
# The repo for box.sh, build-tree.sh and deploy-events.sh, which run from the snapshot
export MEIOLOL_ROOT
ROOT=$MEIOLOL_ROOT
snap=$MEIOLOL_DEPLOY_SNAP
# shellcheck disable=SC2153 # set by the launcher above
deploy_sha=$MEIOLOL_DEPLOY_SHA
trap 'rm -rf "$snap"' EXIT
state=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/meiolol-deploy
lock=$state.lock
now() { date -u +%FT%TZ; }

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
trap 'rm -rf "$lock" "$snap"' EXIT
trap 'exit 1' INT TERM HUP
# A newer origin/main deploys with its own scripts: a fresh snapshot, which drops this one
relaunch() {
    rm -rf "$lock"
    trap - EXIT
    MEIOLOL_DEPLOY_OLD=$snap MEIOLOL_DEPLOY_SNAP='' exec bash "$snap/deploy/on-push.sh"
}
# Steps for the admin page's Deploys tab (deploy-events.sh: queued here, sent to the box
# at each flush). box.sh's output lines mark the build's end and the web loop's signal;
# the box's scripts add the rest (render-swap.sh, web-loop.sh, cache-version.sh)
events=$snap/deploy/deploy-events.sh
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
# The deploy's "Note: N" trailers (deploy/commit.sh --note) mark site notes fixed, the
# commit as the reply, once it is on the box; the site round shows it minutes later
mark_notes() {
    local range=("$2" --max-count=1) h subject ids id
    [[ -n "$1" ]] && git -C "$ROOT" cat-file -e "$1^{commit}" 2> /dev/null && range=("$1..$2")
    git -C "$ROOT" log --reverse --format='%h%x1f%(trailers:key=Note,valueonly,separator=%x20)%x1f%s' \
        "${range[@]}" | while IFS=$'\x1f' read -r h ids subject; do
        for id in $ids; do
            [[ $id =~ ^[0-9]+$ ]] || continue
            if "$snap/deploy/notes.sh" fixed "$id" "$h ${subject:0:400}" > /dev/null 2>&1; then
                echo "$(now) note $id fixed by $h"
            else
                echo "$(now) note $id: marking fixed by $h FAILED"
            fi
        done
    done
}
while [[ -e "$state.pending" ]]; do
    sha=$(git -C "$ROOT" rev-parse origin/main)
    [[ $sha == "$deploy_sha" ]] || relaunch
    rm -f "$state.pending"
    # Docs and research pushes change nothing on the box: skip the build and site round
    # Timeouts as box.sh's: a hung connect would hold the lock (15 Oct: 3 h 25 min)
    deployed=$(ssh -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 \
        "${MEIOLOL_HOST:-essex-vm}" "tail -n 1 ml/meiolol/DEPLOYED" 2> /dev/null | cut -d' ' -f1)
    if [[ -n "$deployed" ]] && git -C "$ROOT" cat-file -e "$deployed^{commit}" 2> /dev/null \
        && git -C "$ROOT" diff --quiet "$deployed" "$sha" -- src deploy build.zig build.zig.zon; then
        echo "$(now) origin/main: nothing to deploy since ${deployed:0:7}"
        if [[ "$sha" != "$deployed" ]]; then
            commits "$deployed" "$sha"
            event "$sha" deploy skipped "nothing to deploy since ${deployed:0:7}: no change in src, deploy or build files"
            flush
            mark_notes "$deployed" "$sha"
        fi
        continue
    fi
    echo "$(now) deploying origin/main"
    commits "$deployed" "$sha"
    event "$sha" deploy start "deploy/box.sh web start on $("$events" where)"
    event "$sha" build start "clean checkout, cross-compile and copy to the box"
    flush
    out=$(mktemp)
    REV=$sha "$snap/deploy/box.sh" web start 2>&1 | while IFS= read -r line; do
        echo "$line"
        echo "$line" >> "$out"
        case $line in
            "deployed "*) event "$sha" build ok "binary and scripts on the box"; flush ;;
            "signalled meiolol-web"* | "restarted meiolol-web"*) event "$sha" web ok "${line% on *}" ;;
            "web held"*) event "$sha" web info "$line" ;;
        esac
    done
    rc=${PIPESTATUS[0]}
    if (( rc == 0 )) && grep -q '^deployed .*unchanged on the box' "$out"; then
        # A change to code meiolol doesn't use or to Mac-side scripts: same build as there
        echo "$(now) unchanged on the box: no site round, meiolol-crawl keeps running"
        event "$sha" deploy skipped "binary, scripts and units unchanged on the box: no site round"
    elif (( rc == 0 )); then
        event "$sha" deploy ok "box.sh done: the box takes it from here"
        # box.sh copies the binary but the crawler keeps the one it started with: a change
        # to its code goes live only on a restart (17 Oct: a crawl fix sat unused)
        crawl_paths=(src/riot src/store)
        if [[ -z "$deployed" ]] || ! git -C "$ROOT" diff --quiet "$deployed" "$sha" -- "${crawl_paths[@]}"; then
            if "$snap/deploy/box.sh" restart > /dev/null 2>&1; then
                echo "$(now) restarted meiolol-crawl (${crawl_paths[*]} changed)"
                event "$sha" crawl ok "crawler restarted: ${crawl_paths[*]} changed"
            else
                echo "$(now) meiolol-crawl restart FAILED"
                event "$sha" crawl failed "crawler restart failed: deploy/box.sh restart"
            fi
        else
            echo "$(now) meiolol-crawl keeps running (no change in ${crawl_paths[*]})"
            event "$sha" crawl skipped "no change in ${crawl_paths[*]}: the crawler keeps running"
        fi
    else
        echo "$(now) failed"
        grep -q '^deployed ' "$out" || event "$sha" build failed "$(grep -v '^ *$' "$out" | tail -n 1)"
        event "$sha" deploy failed "$(grep -v '^ *$' "$out" | tail -n 1)"
    fi
    rm -f "$out"
    flush
    (( rc == 0 )) && mark_notes "$deployed" "$sha"
done
"$snap/deploy/zig-cache-prune.sh"
# A push that landed between the last check and rmdir
[[ -e "$state.pending" ]] && relaunch
exit 0
