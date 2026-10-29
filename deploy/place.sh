#!/usr/bin/env bash
# Where a build runs: the gpu-box or this Mac. test and ci go to the gpu-box when it
# qualifies (~3x faster there than even a quiet Mac, and off the sessions' cores):
# builds not turned off, it answers ssh in 3 s, League is down and a build slot is free
# or only one build waits. test-ui only while the Mac's load is over its cores (5 s
# here when quiet). Everything else stays here: the deploy build (ReleaseSafe through
# LLVM, faster on the M5), the dev server's (a Mac binary), size steps.
#   deploy/place.sh KIND        "gpu-box: why" or "mac: why" for a build of KIND
#                               (test, test-ui, ci, other); MEIOLOL_WHERE=mac|gpu-box wins
#   deploy/place.sh probe       the gpu-box's state, one "key value..." line each
#   deploy/place.sh off|on      gpu-box builds off or back on, for every session
# Sourced (remote-build.sh, compute.sh): gpu CMD (ssh with a shared connection), probe,
# place KIND [PROBE]
GPU_HOST=${GPU_HOST:-gpu-box}
PLACE_OFF=${MEIOLOL_PLACE_OFF:-$HOME/.cache/meiolol-place/off}

# One master connection kept 10 min: later calls skip the handshake (~0.3 s each)
gpu() {
    local opts=()
    while [[ ${1-} == -o ]]; do opts+=("$1" "$2"); shift 2; done
    mkdir -p ~/.ssh/cm
    ssh -o ConnectTimeout=3 -o BatchMode=yes -o ControlMaster=auto \
        -o "ControlPath=$HOME/.ssh/cm/%r@%h:%p" -o ControlPersist=10m \
        ${opts[@]+"${opts[@]}"} "$GPU_HOST" "$@"
}

# shellcheck disable=SC2016 # expands on the gpu-box
probe_cmd='
out=$(/mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null)
if [[ -z $out ]]; then echo league unknown
elif grep -qiE "^\"(LeagueClient|League of Legends)\.exe\"" <<< "$out"; then echo league up
else echo league down; fi
read -r l1 _ < /proc/loadavg
echo load "$l1" "$(nproc)"
echo mem "$(awk "/MemAvailable/ { printf \"%.1f\", \$2 / 1048576 }" /proc/meminfo)"
echo watcher "$(systemctl --user is-active meiolol-lab-watch 2> /dev/null)"
# A lock file nobody holds; a holder that takes it meanwhile retries
held() { local f n=0; for f in "$@"; do [[ -e $f ]] && ! flock -n "$f" true && n=$((n + 1)); done; echo $n; }
mkdir -p ~/ml/locks
n=$(cat ~/ml/locks/build.slots 2> /dev/null || echo 2)
locks=(); for ((i = 0; i < n; i++)); do locks+=(~/ml/locks/build.$i); done
w=0
for d in ~/ml/build/jobs/*/; do
    [[ -f $d/exit || ! -f $d/job.pid ]] && continue
    kill -0 "$(cat "$d/job.pid")" 2> /dev/null || continue
    a=$(tr "\0" " " < "$d/args")
    if [[ -f $d/slot ]]; then echo job "$(basename "$d")" "$(cat "$d/slot")" "$(( $(date +%s) - $(stat -c %Y "$d/slot") ))" "$a"
    else w=$((w + 1)); fi
done
echo build "$(held "${locks[@]}")" "$n" "$w"
for r in cpu gpu; do
    echo lab "$r" "$(held ~/ml/locks/$r.[0-9]*)" "$(cat ~/ml/locks/$r.slots 2> /dev/null || echo 4)" \
        "$(find ~/ml/locks/$r.q -type f 2> /dev/null | wc -l)"
done
'

probe() { gpu "bash -c $(printf '%q' "$probe_cmd")" 2> /dev/null; }

mac_busy() {
    local l1
    l1=$(sysctl -n vm.loadavg | awk '{ print int($2) }')
    (( l1 > $(sysctl -n hw.ncpu) ))
}

# place KIND [PROBE]: PROBE is probe's output (or "unreachable") when the caller has it
place() {
    local kind=$1 st=${2-} league free n w
    case ${MEIOLOL_WHERE-} in mac | gpu-box) echo "$MEIOLOL_WHERE: MEIOLOL_WHERE"; return ;; esac
    case $kind in
        test | ci) ;;
        test-ui) mac_busy || { echo "mac: test-ui is quick here"; return; } ;;
        *) echo "mac: $kind builds here"; return ;;
    esac
    [[ -f $PLACE_OFF ]] && { echo "mac: gpu-box builds off since $(date -r "$PLACE_OFF" '+%d %b %H:%M')"; return; }
    [[ -n $st ]] || st=$(probe) || st=unreachable
    [[ $st != unreachable ]] || { echo "mac: $GPU_HOST unreachable (asleep, off or WSL down)"; return; }
    league=$(awk '$1 == "league" { print $2 }' <<< "$st")
    [[ $league == down ]] || { echo "mac: League $league on $GPU_HOST"; return; }
    read -r _ free n w <<< "$(grep '^build ' <<< "$st")"
    free=$((n - free))
    (( free > 0 || w < 1 )) || { echo "mac: $GPU_HOST build slots busy, $w waiting"; return; }
    echo "gpu-box: up, League down, $free of $n build slots free"
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
set -uo pipefail
. "$(dirname "$0")/lib.sh"
case ${1-} in
    probe) probe || { echo "unreachable"; exit 1; } ;;
    off) mkdir -p "$(dirname "$PLACE_OFF")" && touch "$PLACE_OFF" && echo "gpu-box builds off" ;;
    on) rm -f "$PLACE_OFF" && echo "gpu-box builds on" ;;
    [a-z]*) place "$1" ;;
    *) usage_of "$0" >&2; exit 2 ;;
esac
