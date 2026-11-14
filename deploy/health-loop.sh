#!/usr/bin/env bash
# Runs on the box (deploy/box.sh health start): deploy/health.sh every 15 min, pushing to
# the private ntfy.sh topic in .env (NTFY_TOPIC) when the problems change, again every 12h
# while they last, and once when all is well again. Without NTFY_TOPIC it only logs.
# First each round: deploy/crawl-revive.sh (restarts a crawler dead for hours, guarded).
# A deploy replaces this file without restarting the unit: the loop re-execs itself
set -u
cd "$(dirname "$0")/.." || exit 1
topic=$(sed -n 's/^NTFY_TOPIC=//p' .env 2>/dev/null | tr -d "\"' ")
last=${HEALTH_LAST:-} last_sent=${HEALTH_LAST_SENT:-0}
self=$(stat -c %Y bin/health-loop.sh)
push() {
    echo "$(date -u +%FT%TZ) $1: $2"
    [[ -n "$topic" ]] || return 0
    curl -fsS -m 20 -H "Title: $1" -H "Tags: ${3:-warning}" -d "$2" \
        "https://ntfy.sh/$topic" > /dev/null || echo "ntfy push failed"
}
while true; do
    if [[ "$(stat -c %Y bin/health-loop.sh)" != "$self" ]]; then
        HEALTH_LAST=$last HEALTH_LAST_SENT=$last_sent exec bin/health-loop.sh
    fi
    bin/crawl-revive.sh
    out=$(bin/health.sh)
    now=$(date +%s)
    if [[ -n "$out" ]]; then
        if [[ "$out" != "$last" ]] || (( now - last_sent >= 12 * 3600 )); then
            push "meiolol: problem" "$out"
            last_sent=$now
        fi
    elif [[ -n "$last" ]]; then
        push "meiolol: all well again" "resolved: $last" white_check_mark
    fi
    last=$out
    sleep 900
done
