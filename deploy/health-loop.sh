#!/usr/bin/env bash
# Runs on the box (deploy/box.sh health start): deploy/health.sh every 15 min, pushing to
# the private ntfy.sh topic in .env (NTFY_TOPIC) when the problems change, again every 12h
# while they last, and once when all is well again. Without NTFY_TOPIC it only logs.
set -u
cd "$(dirname "$0")/.." || exit 1
topic=$(sed -n 's/^NTFY_TOPIC=//p' .env 2>/dev/null | tr -d "\"' ")
last='' last_sent=0
push() {
    echo "$(date -u +%FT%TZ) $1: $2"
    [[ -n "$topic" ]] || return 0
    curl -fsS -m 20 -H "Title: $1" -H "Tags: ${3:-warning}" -d "$2" \
        "https://ntfy.sh/$topic" > /dev/null || echo "ntfy push failed"
}
while true; do
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
