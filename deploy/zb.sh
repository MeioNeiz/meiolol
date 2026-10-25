#!/bin/bash
# zig build for sessions sharing this checkout: one build at a time (the team lock), and a
# check (test, test-ui, ci) that a run started after this request already covered is
# answered from that run instead of building again: that run saw this session's saved
# files, so its result is this one's too. Anything else just builds under the lock.
# Usage: deploy/zb.sh test [-Dtest-filter=NAME]... | test-ui [...] | ci | <zig build args>
set -o pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dir=$HOME/.cache/meiolol-zb
mkdir -p "$dir"

locked=0
if [ "${1-}" = --locked ]; then
    locked=1
    asked=$2
    shift 2
fi

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

answer() {
    local k n code started
    for k in "${covers[@]}"; do
        [ -f "$dir/$k.meta" ] || continue
        read -r n code started < "$dir/$k.meta"
        if [ "$n" -gt "$asked" ]; then
            echo "zb: answered by run #$n ($(cat "$dir/$k.args")), started $(($(date +%s) - started)) s ago, after this request" >&2
            cat "$dir/$k.log"
            exit "$code"
        fi
    done
}

# Waiting polls rather than blocks, so a run that answers this request ends the wait
# even while someone else's unrelated build holds the lock. lockf -s -t 0: 75 when held
if [ $locked = 0 ]; then
    asked=$(cat "$dir/seq" 2> /dev/null || echo 0)
    while :; do
        answer
        lockf -s -t 0 "$HOME/.cache/meiolol-zig.lock" "$0" --locked "$asked" "$@"
        code=$?
        [ $code = 75 ] || exit $code
        sleep 1
    done
fi
answer

n=$(($(cat "$dir/seq" 2> /dev/null || echo 0) + 1))
echo "$n" > "$dir/seq"
started=$(date +%s)
log=$(mktemp "$dir/run.XXXXXX")
(cd "$root" && zig build "$@") 2>&1 | tee "$log"
code=$?
if [ ${#covers[@]} -gt 0 ]; then
    k=$(key "$@")
    mv "$log" "$dir/$k.log"
    echo "$*" > "$dir/$k.args"
    echo "$n $code $started" > "$dir/$k.meta"
else
    rm -f "$log"
fi
exit $code
