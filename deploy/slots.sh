#!/usr/bin/env bash
# Build slots on the Mac, shared by every session: a zig compile runs on one core, so
# several builds run at once instead of one behind a single lock. A run takes WEIGHT
# slots, about the cores it keeps busy (measured 26 Oct: test 152 s on 1.1 cores, 1.7 GB;
# ci after it 97 s on 3.8), MEIOLOL_SLOTS in all (default 3 of the 10 cores, the rest for
# sessions and browsers). ci takes 2 (WEIGHT ci), the rest 1: with all 3 a 30 s check
# waited 4-10 min behind it (5 Nov: 7 queued behind one ci). First come first served,
# but a smaller run starts beside a waiting bigger one when it leaves that one's slots
# free.
# A held run gets MEIOLOL_ZIG_JOBS=2*WEIGHT, which the ~/.local/bin/zig shim passes to
# `zig build` as -j: else each build runs a compile per core (load 106 on 29 Oct)
#   deploy/slots.sh WEIGHT|ci CMD [ARG...] run CMD holding WEIGHT slots, or ci's
#   deploy/slots.sh status                holders and waiters
#   deploy/slots.sh history [HOURS]       waits, run times and use by hour (default 24)
# Sourced (zb.sh): slots_enqueue W, slots_take (0 once held, 1 not yet), slots_release;
# slots_done CODE at exit logs the request (slots_kind, slots_cmd) and releases.
# State: ~/.cache/meiolol-slots (MEIOLOL_SLOTS_DIR), entries named by pid: a dead
# holder's or waiter's entry is dropped by the next caller. history.tsv there: a line per
# request, host pid kind weight enqueued started ended code cmd (epoch s; started - for
# one that never ran: answered by another run, or given up)
# On the gpu-box (WSL on Jacob's PC) no slot is granted while League's game runs (the
# client alone doesn't hold builds): the watcher (deploy/lab-watch.sh) writes up, down,
# unknown or blind (Windows unanswered for minutes: builds go) to
# ~/.cache/meiolol-league-game each few s (MEIOLOL_LEAGUE_FILE; a file a minute old means
# no watcher: builds go); slots wait on up and unknown
slots_dir=${MEIOLOL_SLOTS_DIR:-$HOME/.cache/meiolol-slots}
slots_n=${MEIOLOL_SLOTS:-3}
slots_ci=2
slots_mine=""
slots_enq="" slots_start="" slots_w="" slots_kind="" slots_cmd=""
MEIOLOL_LEAGUE_FILE=${MEIOLOL_LEAGUE_FILE-}
slots_league_file=${MEIOLOL_LEAGUE_FILE:-$HOME/.cache/meiolol-league-game}
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
    slots_w=$w
    # A request that gives up its place and queues again (zb.sh) keeps its first time
    [ -n "$slots_enq" ] || slots_enq=$(date +%s)
    _slots_gate
    t=$(($(cat "$slots_dir/ticket" 2> /dev/null || echo 0) + 1))
    echo "$t" > "$slots_dir/ticket"
    slots_mine=$(printf '%09d-%s-%s' "$t" $$ "$w")
    : > "$slots_dir/wait/$slots_mine"
    _slots_ungate
}

# 0 while League's game (or a watcher that can't ask Windows) keeps builds here waiting
_slots_league() {
    local st
    [ -n "$slots_wsl$MEIOLOL_LEAGUE_FILE" ] || return 1
    st=$(cat "$slots_league_file" 2> /dev/null) || return 1
    case $st in up | unknown) ;; *) return 1 ;; esac
    [ -n "$(find "$slots_league_file" -mmin -1 2> /dev/null)" ] || return 1
    [ -n "$slots_league_said" ] \
        || echo "slots: League game $st on this PC: no build starts until it closes (docs/compute.md)" >&2
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
        slots_start=$(date +%s)
        export MEIOLOL_ZIG_JOBS=$((2 * w))
        code=0
    fi
    _slots_ungate
    return $code
}

slots_release() {
    rm -f "$slots_dir"/held/"$$"-*
    [ -z "$slots_mine" ] || rm -f "$slots_dir/wait/$slots_mine"
    slots_start=""
}

slots_done() {
    if [ -n "$slots_enq" ]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(hostname -s)" $$ "${slots_kind:-?}" \
            "$slots_w" "$slots_enq" "${slots_start:--}" "$(date +%s)" "${1:-?}" \
            "$(printf '%s' "$slots_cmd" | tr '\t\n' '  ' | cut -c1-100)" \
            >> "$slots_dir/history.tsv" 2> /dev/null
        slots_enq=""
    fi
    slots_release
}

# A command's kind for the history: its zig build step (~f when test-filtered), else its
# name
_slots_kind() {
    local a st=0 step="" f=""
    for a in "$@"; do
        case $a in -Dtest-filter=*) f="~f" ;; esac
        case $st in
            0) case $a in
                   zig | */zig) st=1 ;;
                   "zig build "*)
                       step=$(printf '%s\n' "$a" | awk '{for (i = 3; i <= NF; i++) if ($i !~ /^-/) {print $i; exit}}')
                       st=3
                       ;;
               esac ;;
            1) if [ "$a" = build ]; then st=2; else st=0; fi ;;
            2) case $a in -*) ;; *) step=$a st=3 ;; esac ;;
        esac
    done
    if [ $st -ge 2 ]; then echo "${step:-install}$f"; else basename "${1:-?}"; fi
}

_slots_date() { date -r "$1" "$2" 2> /dev/null || date -d "@$1" "$2"; }

# Per kind: requests, those that never ran, wait and run p50/p90/max, failed runs; then
# slot use per hour (held slot-seconds over all slots' seconds)
slots_history() {
    local hours=${1:-24} h=$slots_dir/history.tsv since rows
    [[ $hours =~ ^[0-9]+$ ]] || { echo "usage: deploy/slots.sh history [HOURS]" >&2; return 2; }
    since=$(($(date +%s) - hours * 3600))
    [ -f "$h" ] && rows=$(awk -F'\t' -v s="$since" '$7 >= s' "$h")
    [ -n "${rows:-}" ] || { echo "slots: no requests in the last $hours h ($h)"; return 0; }
    echo "slot requests, last $hours h, $slots_n slots ($h)"
    printf '%-12s %5s %6s  %-17s %-17s %6s\n' kind reqs no-run "wait p50/p90/max" \
        "run p50/p90/max" failed
    # One line per kind and measure (w wait, r run), values sorted, then percentiles
    printf '%s\n' "$rows" | awk -F'\t' '{
            ran = $6 != "-"
            print $3 "\tw\t" ((ran ? $6 : $7) - $5)
            if (ran) print $3 "\tr\t" ($7 - $6)
            print $3 "\tn\t" (ran ? 0 : 1)
            if (ran) print $3 "\tf\t" ($8 != 0)
        }' | sort -t"$(printf '\t')" -k1,1 -k2,2 -k3,3n | awk -F'\t' '
        function flush_m() {
            if (m == "") return
            if (m == "w" || m == "r") {
                out[k, m] = sprintf("%d/%d/%d", v[int((c - 1) * 0.5) + 1], v[int((c - 1) * 0.9) + 1], v[c])
                if (m == "w") reqs[k] = c
            } else out[k, m] = sum
        }
        $1 != k || $2 != m { flush_m(); if ($1 != k) kinds[++nk] = $1; k = $1; m = $2; c = 0; sum = 0 }
        { v[++c] = $3; sum += $3 }
        END {
            flush_m()
            for (i = 1; i <= nk; i++) {
                k = kinds[i]
                printf "%-12s %5d %6d  %-17s %-17s %6d\n", k, reqs[k], out[k, "n"], out[k, "w"],
                    (out[k, "r"] == "" ? "-" : out[k, "r"]), out[k, "f"]
            }
        }'
    echo "use by hour"
    printf '%s\n' "$rows" | awk -F'\t' -v n="$slots_n" '$6 != "-" {
            for (t = $6; t < $7; t = e) {
                hr = int(t / 3600)
                e = (hr + 1) * 3600
                if (e > $7) e = $7
                use[hr] += $4 * (e - t)
            }
        }
        END { for (hr in use) printf "%d %d\n", hr * 3600, 100 * use[hr] / (n * 3600) }' \
        | sort -n | while read -r t pct; do
            echo "$(_slots_date "$t" '+%d %b %H:00')  $pct%"
        done
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
    history) slots_history "${2-}" ;;
    [1-9]* | ci)
        [ $# -ge 2 ] || { echo "usage: deploy/slots.sh WEIGHT|ci CMD [ARG...] | status | history [HOURS]" >&2; exit 2; }
        w=$1
        [ "$w" != ci ] || w=$slots_ci
        shift
        slots_kind=$(_slots_kind "$@")
        slots_cmd="$*"
        slots_enqueue "$w"
        trap 'slots_done $?' EXIT
        trap 'exit 130' INT TERM HUP
        said=""
        until slots_take; do
            [ -n "$said" ] || { echo "slots: waiting for $w of $slots_n (deploy/slots.sh status)" >&2; said=1; }
            sleep 1
        done
        "$@"
        ;;
    *) echo "usage: deploy/slots.sh WEIGHT|ci CMD [ARG...] | status | history [HOURS]" >&2; exit 2 ;;
esac
