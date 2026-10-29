#!/usr/bin/env bash
# Build slots on the Mac, shared by every session: a zig compile runs on one core, so
# several builds run at once instead of one behind a single lock. A run takes WEIGHT
# slots, about the cores it keeps busy (zb.sh: ci 3, the rest 1; measured 26 Oct: test
# 152 s on 1.1 cores, 1.7 GB; ci after it 97 s on 3.8), MEIOLOL_SLOTS in all (default 6
# of the 10 cores, the rest for sessions and browsers). First come first served, but a
# smaller run starts beside a waiting bigger one when it leaves that one's slots free.
# A held run gets MEIOLOL_ZIG_JOBS=2*WEIGHT, which the ~/.local/bin/zig shim passes to
# `zig build` as -j: else each build runs a compile per core (load 106 on 29 Oct)
#   deploy/slots.sh WEIGHT CMD [ARG...]   run CMD holding WEIGHT slots
#   deploy/slots.sh status                holders and waiters
# Sourced (zb.sh): slots_enqueue W, slots_take (0 once held, 1 not yet), slots_release.
# State: ~/.cache/meiolol-slots (MEIOLOL_SLOTS_DIR), entries named by pid: a dead
# holder's or waiter's entry is dropped by the next caller.
# On the gpu-box (WSL on Jacob's PC) no slot is granted while League is up: the watcher
# (deploy/lab-watch.sh) writes up, down or unknown to ~/.cache/meiolol-league each few s
# (MEIOLOL_LEAGUE_FILE; a file a minute old means no watcher: builds go). A held run goes
# to nice 19 and idle I/O there, so the watcher's lag before it stops one costs little
slots_dir=${MEIOLOL_SLOTS_DIR:-$HOME/.cache/meiolol-slots}
slots_n=${MEIOLOL_SLOTS:-6}
slots_mine=""
MEIOLOL_LEAGUE_FILE=${MEIOLOL_LEAGUE_FILE-}
slots_league_file=${MEIOLOL_LEAGUE_FILE:-$HOME/.cache/meiolol-league}
slots_wsl=""
[ -r /proc/version ] && grep -qi microsoft /proc/version && slots_wsl=1
slots_league_said=""

# The gate: a mkdir lock held for a few milliseconds around each decision
_slots_gate() {
    local pid
    mkdir -p "$slots_dir/wait" "$slots_dir/held"
    while ! mkdir "$slots_dir/gate" 2> /dev/null; do
        pid=$(cat "$slots_dir/gate/pid" 2> /dev/null)
        if [ -n "$pid" ] && ! kill -0 "$pid" 2> /dev/null; then
            rm -rf "$slots_dir/gate"
        elif [ -z "$pid" ] && [ -n "$(find "$slots_dir/gate" -maxdepth 0 -mmin +1 2> /dev/null)" ]; then
            rm -rf "$slots_dir/gate"
        fi
        sleep 0.05
    done
    echo $$ > "$slots_dir/gate/pid"
}
_slots_ungate() { rm -rf "$slots_dir/gate"; }

# Entries: wait/<ticket>-<pid>-<weight>, held/<pid>-<weight>-<ticket>
_slots_prune() {
    local f b pid
    for f in "$slots_dir"/wait/* "$slots_dir"/held/*; do
        [ -e "$f" ] || continue
        b=${f##*/}
        case $f in */wait/*) pid=${b#*-}; pid=${pid%-*} ;; *) pid=${b%%-*} ;; esac
        kill -0 "$pid" 2> /dev/null || rm -f "$f"
    done
}

slots_enqueue() {
    local w=$1 t
    [ "$w" -le "$slots_n" ] || w=$slots_n
    _slots_gate
    t=$(($(cat "$slots_dir/ticket" 2> /dev/null || echo 0) + 1))
    echo "$t" > "$slots_dir/ticket"
    slots_mine=$(printf '%09d-%s-%s' "$t" $$ "$w")
    : > "$slots_dir/wait/$slots_mine"
    _slots_ungate
}

# 0 while League (or a watcher that can't ask Windows) keeps builds here waiting
_slots_league() {
    local st
    [ -n "$slots_wsl$MEIOLOL_LEAGUE_FILE" ] || return 1
    st=$(cat "$slots_league_file" 2> /dev/null) || return 1
    [ "$st" != down ] && [ -n "$(find "$slots_league_file" -mmin -1 2> /dev/null)" ] || return 1
    [ -n "$slots_league_said" ] \
        || echo "slots: League $st on this PC: no build starts until it closes (docs/compute.md)" >&2
    slots_league_said=1
}

slots_take() {
    local used=0 f b head="" hw=0 w=${slots_mine##*-} code=1
    ! _slots_league || return 1
    _slots_gate
    _slots_prune
    for f in "$slots_dir"/held/*; do
        [ -e "$f" ] || continue
        b=${f##*/}
        b=${b#*-}
        used=$((used + ${b%%-*}))
    done
    for f in "$slots_dir"/wait/*; do
        [ -e "$f" ] || continue
        head=${f##*/}
        hw=${head##*-}
        break
    done
    local free=$((slots_n - used))
    if [ "$w" -le "$free" ] && { [ "$head" = "$slots_mine" ] || [ $((free - w)) -ge "$hw" ]; }; then
        rm -f "$slots_dir/wait/$slots_mine"
        : > "$slots_dir/held/$$-$w-${slots_mine%%-*}"
        slots_mine=held
        export MEIOLOL_ZIG_JOBS=$((2 * w))
        if [ -n "$slots_wsl" ]; then
            renice -n 19 -p $$ > /dev/null
            ionice -c 3 -p $$
        fi
        code=0
    fi
    _slots_ungate
    return $code
}

slots_release() {
    rm -f "$slots_dir"/held/"$$"-*
    [ -z "$slots_mine" ] || rm -f "$slots_dir/wait/$slots_mine"
}

slots_status() {
    local f b
    _slots_gate
    _slots_prune
    _slots_ungate
    echo "slots: $slots_n"
    for f in "$slots_dir"/held/* "$slots_dir"/wait/*; do
        [ -e "$f" ] || continue
        b=${f##*/}
        case $f in
            */held/*) set -- "${b%%-*}" "$(echo "$b" | cut -d- -f2)" held ;;
            *) set -- "$(echo "$b" | cut -d- -f2)" "${b##*-}" waits ;;
        esac
        echo "$3 $2: pid $1 $(ps -o etime= -p "$1" | tr -d ' ') $(ps -o args= -p "$1" | cut -c1-100)"
    done
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
set -u
case ${1-} in
    status) slots_status ;;
    [1-9]*)
        [ $# -ge 2 ] || { echo "usage: deploy/slots.sh WEIGHT CMD [ARG...] | status" >&2; exit 2; }
        w=$1
        shift
        slots_enqueue "$w"
        trap slots_release EXIT
        trap 'exit 130' INT TERM HUP
        said=""
        until slots_take; do
            [ -n "$said" ] || { echo "slots: waiting for $w of $slots_n (deploy/slots.sh status)" >&2; said=1; }
            sleep 1
        done
        "$@"
        ;;
    *) echo "usage: deploy/slots.sh WEIGHT CMD [ARG...] | status" >&2; exit 2 ;;
esac
