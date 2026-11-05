#!/bin/bash
# Pushes tested commits to main (every push deploys), in one of two modes for all
# sessions (~/.cache/meiolol-push/mode):
# - fast: push REV now, grouped with the other queued pushes: the pre-push ci (~2-3 min)
#   runs once, on the newest queued commit that contains REV, and a push that lands REV
#   ends the wait. If the group's ci fails, the newest passing one down to REV alone is
#   found by halving, and the first failing commit is left out of later groups
# - bulk: REV is queued and this returns at once; the timer (or --flush) pushes every
#   queued commit together: one ci, one deploy, one live check. A commit whose ci fails is
#   left out with those after it, and the older ones go (found by halving the batch)
# Only commits a session asked to push go out. Pushes take their own lock and ci's 2 of
# the 3 build slots (deploy/slots.sh), so builds and tests carry on beside them.
#   deploy/push.sh [REV]                  push REV (default HEAD), or queue it in bulk mode
#   deploy/push.sh --flush                push everything queued now
#   deploy/push.sh --mode fast|bulk [MIN] set the mode; bulk pushes every MIN minutes
#                                         (default 30); fast flushes the queue first
#   deploy/push.sh --status               mode, timer, queue, failed commits
set -o pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
q=${MEIOLOL_PUSH_QUEUE:-$HOME/.cache/meiolol-push}
lock=${MEIOLOL_PUSH_LOCK:-$HOME/.cache/meiolol-push.lock}
# with_lock [-n] CMD...: CMD under $lock; -n gives up at once with 75 when it's held.
# lockf is macOS's, flock Linux's (the gpu-box)
with_lock() {
    if command -v lockf > /dev/null; then
        if [ "$1" = -n ]; then shift; lockf -s -t 0 "$lock" "$@"; else lockf "$lock" "$@"; fi
    elif [ "$1" = -n ]; then
        shift
        flock -n -E 75 "$lock" "$@"
    else
        flock "$lock" "$@"
    fi
}
mkdir -p "$q/failed" "$q/bulk"
cd "$root" || exit 1

pushed() { git merge-base --is-ancestor "$1" refs/remotes/origin/main 2> /dev/null; }
short() { git rev-parse --short "$1"; }
mode() { cut -d' ' -f1 "$q/mode" 2> /dev/null | grep -x bulk || echo fast; }
timer_pid() {
    local pid
    pid=$(cat "$q/timer.pid" 2> /dev/null) && kill -0 "$pid" 2> /dev/null && echo "$pid"
}

# Every queued commit (fast waiters' q/<pid>, bulk q/bulk/<sha>) not on main yet and
# whose ci did not fail; bulk entries already on main are dropped
queued() {
    local f s
    for f in "$q"/[0-9]* "$q"/bulk/*; do
        [ -f "$f" ] || continue
        s=$(cat "$f")
        if pushed "$s"; then
            case $f in */bulk/*) rm -f "$f" ;; esac
            continue
        fi
        [ -f "$q/failed/$s" ] || echo "$s"
    done | sort -u
}

# Candidates for one push, best first: queued commits containing $1 (any, if empty),
# the one containing the most other queued commits first
tops() {
    local s o n all
    all=$(queued)
    for s in $all; do
        [ -z "$1" ] || git merge-base --is-ancestor "$1" "$s" 2> /dev/null || continue
        n=0
        for o in $all; do
            git merge-base --is-ancestor "$o" "$s" 2> /dev/null && n=$((n + 1))
        done
        echo "$n $s"
    done | sort -rn | cut -d' ' -f2
}

# One ci: 0 once $1 is on main, else 1 with $1 marked failed
try_push() {
    if git push origin "$1:main"; then
        echo "$(date -u +%FT%TZ) pushed $(short "$1")" >> "$q/log"
        return 0
    fi
    touch "$q/failed/$1"
    failed_now=1
    echo "$(date -u +%FT%TZ) ci failed $(short "$1") $(git log -1 --format=%s "$1" | cut -c1-80)" >> "$q/log"
    echo "push: $(short "$1") refused (its ci failed, or main moved): left out"
    return 1
}

# Under the lock: push the best candidate containing $1 (any if empty); 0 once one went.
# When the newest fails and the candidates are one line of history (main is linear),
# the newest passing one is found by halving: a culprit at the bottom of n costs about
# log2 n + 1 cis, not n. The first failing one and every newer one are left out
push_best() {
    local c=() s i bad good n
    for s in $(tops "$1"); do c+=("$s"); done
    n=${#c[@]}
    [ "$n" -gt 0 ] || return 1
    [ -z "$1" ] || [ "${c[0]}" = "$1" ] || echo "push: grouped: $(short "$1") goes with $(short "${c[0]}")"
    try_push "${c[0]}" && return 0
    for ((i = 1; i < n; i++)); do
        git merge-base --is-ancestor "${c[i]}" "${c[i - 1]}" 2> /dev/null || break
    done
    if [ "$i" -lt "$n" ]; then
        for s in "${c[@]:1}"; do try_push "$s" && return 0; done
        return 1
    fi
    # c[0] newest, each containing the next: c[bad] fails, c[good] passes (n: none tried)
    bad=0 good=$n
    while [ $((good - bad)) -gt 1 ]; do
        i=$(((bad + good) / 2))
        if try_push "${c[i]}"; then good=$i; else bad=$i; fi
    done
    for ((i = 0; i < bad; i++)); do touch "$q/failed/${c[i]}"; done
    echo "$(date -u +%FT%TZ) first failing $(short "${c[bad]}"), $bad newer left out" >> "$q/log"
    echo "push: $(short "${c[bad]}") is the first queued commit whose ci fails; $bad newer left out"
    [ "$good" -lt "$n" ]
}

failed_now=0
flush() {
    local before after
    before=$(queued | wc -l | tr -d ' ')
    [ "$before" -gt 0 ] || { echo "push: nothing queued"; return 0; }
    git fetch -q origin main 2> /dev/null
    while [ -n "$(tops "")" ]; do
        push_best "" || break
    done
    after=$(queued | wc -l | tr -d ' ')
    echo "push: flushed $((before - after)) of $before queued"
    if [ $failed_now = 1 ]; then
        [ "${MEIOLOL_NOTIFY:-1}" = 0 ] \
            || wz notify --for 600 meiolol "push: a batch commit failed ci, left out: deploy/push.sh --status" 2> /dev/null || true
        return 1
    fi
}

status() {
    local f s pid
    echo "mode: $(cat "$q/mode" 2> /dev/null || echo fast)"
    if pid=$(timer_pid); then
        echo "timer: pid $pid"
    elif [ "$(mode)" = bulk ]; then
        echo "timer: not running (deploy/push.sh --mode bulk to restart)"
    fi
    echo "main: $(git log -1 --format='%h %s' origin/main | cut -c1-90)"
    for f in "$q"/[0-9]* "$q"/bulk/*; do
        [ -f "$f" ] || continue
        s=$(cat "$f")
        pushed "$s" && continue
        echo "queued: $(git log -1 --format='%h %s' "$s" | cut -c1-80)$([ -f "$q/failed/$s" ] && echo ' (ci failed)')"
    done
    [ -f "$q/log" ] && tail -n 5 "$q/log"
}

case ${1-} in
    --locked)
        shift
        case $1 in
            flush) flush ;;
            *) pushed "$1" && { echo "push: $(short "$1") is on main"; exit 0; }
               push_best "$1" ;;
        esac
        exit $?
        ;;
    --flush)
        with_lock "$root/deploy/push.sh" --locked flush
        exit $?
        ;;
    --status) status; exit 0 ;;
    --mode)
        case ${2-} in
            fast)
                echo fast > "$q/mode"
                pid=$(timer_pid) && kill "$pid"
                with_lock "$root/deploy/push.sh" --locked flush
                exit $?
                ;;
            bulk)
                min=${3:-30}
                [[ $min =~ ^[0-9]+$ ]] && [ "$min" -gt 0 ] || { echo "push: minutes, a whole number" >&2; exit 2; }
                echo "bulk $min" > "$q/mode"
                pid=$(timer_pid) && kill "$pid"
                # The loop calls the working tree's push.sh afresh each time, so an edit
                # to it applies from the next push
                # shellcheck disable=SC2016 # the inner bash expands them
                nohup bash -c 'q=$1 sh=$2
                    while [ "$(cut -d" " -f1 "$q/mode" 2> /dev/null)" = bulk ]; do
                        m=$(cut -d" " -f2 "$q/mode")
                        end=$((SECONDS + m * 60))
                        while [ $SECONDS -lt $end ] && [ "$(cut -d" " -f1 "$q/mode")" = bulk ]; do sleep 15; done
                        [ "$(cut -d" " -f1 "$q/mode")" = bulk ] || break
                        "$sh" --flush
                    done' _ "$q" "$root/deploy/push.sh" >> "$q/timer.log" 2>&1 < /dev/null &
                echo $! > "$q/timer.pid"
                echo "push: bulk, every $min min (timer pid $!); deploy/push.sh --flush pushes now"
                exit 0
                ;;
            *) echo "usage: deploy/push.sh --mode fast|bulk [MIN]" >&2; exit 2 ;;
        esac
        ;;
esac

rev=$(git rev-parse --verify "${1:-HEAD}^{commit}") || exit 2
if pushed "$rev"; then
    echo "push: $(short "$rev") is on main"
    exit 0
fi
# A REV from a worktree off origin, beside local main's unpushed commits, splits the two:
# someone then has to replay main by hand. A REV on main (an older tested sha) is fine:
# main's later commits fast-forward onto it
if [ -z "${MEIOLOL_PUSH_BESIDE:-}" ] \
    && [ -n "$(git rev-list -1 refs/remotes/origin/main..refs/heads/main)" ] \
    && ! git merge-base --is-ancestor refs/heads/main "$rev" \
    && ! git merge-base --is-ancestor "$rev" refs/heads/main; then
    echo "push: $(short "$rev") leaves out local main's unpushed commits (git log origin/main..main):" \
        "rebase it onto main, or MEIOLOL_PUSH_BESIDE=1 if main's are not to go" >&2
    exit 1
fi
if [ "$(mode)" = bulk ]; then
    echo "$rev" > "$q/bulk/$rev"
    rm -f "$q/failed/$rev"
    timer_pid > /dev/null || echo "push: bulk timer not running: deploy/push.sh --mode bulk [MIN]"
    echo "push: $(short "$rev") queued for the next batch push (deploy/push.sh --status); no wait-deployed"
    exit 0
fi
rm -f "$q/failed/$rev"
req=$q/$$
echo "$rev" > "$req"
trap 'rm -f "$req"' EXIT
while :; do
    if pushed "$rev"; then
        echo "push: $(short "$rev") is on main"
        exit 0
    fi
    [ -f "$q/failed/$rev" ] && { echo "push: ci failed on $(short "$rev")"; exit 1; }
    with_lock -n "$root/deploy/push.sh" --locked "$rev"
    code=$?
    [ $code = 75 ] || exit $code
    sleep 1
done
