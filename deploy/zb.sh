#!/bin/bash
# zig build for sessions sharing this checkout: each run holds build slots
# (deploy/slots.sh: ci 3, anything else 1), so several run at once,
# and a check (test, test-ui, ci) that a run started after this request already covered
# is answered from that run instead of building again: that run saw this session's saved
# files, so its result is this one's too. Anything else just builds.
# Usage: deploy/zb.sh test [-Dtest-filter=NAME]... | test-ui [...] | ci | <zig build args>
set -o pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dir=$HOME/.cache/meiolol-zb
mkdir -p "$dir"
# shellcheck source=deploy/slots.sh
. "$root/deploy/slots.sh"

key() { printf '%s\n' "$root" "$@" | shasum | cut -c1-16; }

# Which runs answer this request: the same check, the unfiltered one, and wider steps
covers=()
step=${1-}
plain=1
for a in "${@:2}"; do
    case $a in -Dtest-filter=*) ;; *) plain=0 ;; esac
done
if [ $plain = 1 ]; then
    case $step in
        test-ui) covers=("$(key "$@")" "$(key test-ui)" "$(key test)" "$(key ci)") ;;
        test) covers=("$(key "$@")" "$(key test)" "$(key ci)") ;;
        ci) [ $# = 1 ] && covers=("$(key ci)") ;;
    esac
fi
weight=1
[ "$step" != ci ] || weight=3

answer() {
    local k n code started
    for k in "${covers[@]}"; do
        [ -f "$dir/$k.meta" ] || continue
        read -r n code started < "$dir/$k.meta"
        if [ "$n" -gt "$asked" ]; then
            slots_release
            echo "zb: answered by run #$n ($(cat "$dir/$k.args")), started $(($(date +%s) - started)) s ago, after this request" >&2
            cat "$dir/$k.log"
            exit "$code"
        fi
    done
}

# A covering run that started after this request and is still going: wait for it
covered_soon() {
    local k n pid
    for k in "${covers[@]}"; do
        [ -f "$dir/$k.running" ] || continue
        read -r n pid < "$dir/$k.running"
        [ "$n" -gt "$asked" ] && kill -0 "$pid" 2> /dev/null && return 0
    done
    return 1
}

# A run that answers this request ends the wait, even while others' builds hold the
# slots; while one that will is running, this request gives up its place in the queue
asked=$(cat "$dir/seq" 2> /dev/null || echo 0)
trap slots_release EXIT
trap 'exit 130' INT TERM HUP
said=""
while :; do
    answer
    if covered_soon; then
        slots_release
        slots_mine=""
    else
        [ -n "$slots_mine" ] || slots_enqueue $weight
        if slots_take; then
            # A covering run may have started between the check and the take
            covered_soon || break
            slots_release
            slots_mine=""
        fi
    fi
    # shellcheck disable=SC2154 # slots_n: deploy/slots.sh
    [ -n "$said" ] || { echo "zb: waiting for $weight of $slots_n build slots (deploy/slots.sh status)" >&2; said=1; }
    sleep 1
done

# seq: the gate keeps two runs from taking the same number
_slots_gate
n=$(($(cat "$dir/seq" 2> /dev/null || echo 0) + 1))
echo "$n" > "$dir/seq"
_slots_ungate
started=$(date +%s)
self=$(key "$@")
[ ${#covers[@]} = 0 ] || echo "$n $$" > "$dir/$self.running"
log=$(mktemp "$dir/run.XXXXXX")
(cd "$root" && zig build "$@") 2>&1 | tee "$log"
code=$?
if [ ${#covers[@]} -gt 0 ]; then
    mv "$log" "$dir/$self.log"
    echo "$*" > "$dir/$self.args"
    echo "$n $code $started" > "$dir/$self.meta"
    rm -f "$dir/$self.running"
else
    rm -f "$log"
fi
exit $code
