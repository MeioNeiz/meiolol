#!/usr/bin/env bash
# Runs on the box each deploy/health-loop.sh round: restarts a crawler that is up but has
# stored no match and had no Riot answer for REVIVE_H hours (10-13 Nov: 74 h of failed TLS
# handshakes inside one process; a restart fixed it). Guarded: not 04-07 UTC, not beside a
# curves pass, at most one per REVIVE_GAP_H, and never again on a crawler our last restart
# started that has had no answer since: that one needs a person. Outcomes in
# data/crawl-revive.log (health.sh shows them); why-stopped.sh names the caller in crawl.log.
# Tests: NOW, UNIT_START (unix; skips systemctl), REVIVE_DRY=1 (no restart), CRAWL_LOG,
# REVIVE_LOG
set -u
cd "$(dirname "$0")/.." || exit 1
REVIVE_H=${REVIVE_H:-3}
REVIVE_GAP_H=${REVIVE_GAP_H:-24}
LOG=${REVIVE_LOG:-data/crawl-revive.log}
CRAWL_LOG=${CRAWL_LOG:-data/crawl.log}
unit=meiolol-crawl
now=${NOW:-$(date +%s)}
stamp() { date -u -d "@$1" "+${2:-%F %T}"; }
say() {
    local line
    line="$(stamp "$now" '%FT%TZ') $1"
    echo "$line" >> "$LOG"
    echo "crawl-revive: $line"
}

if [[ -n "${UNIT_START:-}" ]]; then
    started=$UNIT_START
else
    systemctl --user -q is-active "$unit" 2> /dev/null || exit 0
    started=$(date -d "$(systemctl --user show --value -p ActiveEnterTimestamp "$unit")" +%s \
        2> /dev/null) || exit 0
fi
(( now - started >= REVIVE_H * 3600 )) || exit 0

# Report lines (every minute) carry per-process counters: stored matches (<n>m), answered
# requests by region (<n>req), platform req and ladder pages. Baseline: the last report at
# or before the window's start, from this process; none since it means silent
since=$(stamp $(( now - REVIVE_H * 3600 )))
read -r base_t base last_t last moved <<< "$(grep 'matches/day' "$CRAWL_LOG" | awk \
    -v since="$since" -v until="$(stamp "$now")" -v from="$(stamp "$started")" '
    function progress(  i, n) {
        for (i = 3; i <= NF; i++) {
            if ($i ~ /^[0-9]+(m|req)$/) n += $i + 0
            else if (($i == "req" || $i == "pages") && $(i + 1) ~ /^[0-9]+$/) n += $(i + 1)
        }
        return n + 0
    }
    { t = $1 "T" $2 }
    $1 " " $2 > until { exit }
    $1 " " $2 >= from {
        c = progress()
        if (c != l || mt == "") mt = t
        if ($1 " " $2 <= since) { bt = t; b = c }
        lt = t; l = c
    }
    END { if (bt != "") print bt, b, lt, l, mt }')"
[[ -n "${base_t:-}" ]] || exit 0
held=data/crawl-revive.held
[[ -n "${REVIVE_LOG:-}" ]] && held=$LOG.held
if (( last != base )); then
    rm -f "$held"
    exit 0
fi
if [[ "$last_t" == "$base_t" ]]; then
    why="silent: no report line since $base_t"
else
    why="no match stored and no Riot answer since $moved"
fi
# The commonest warning of the last lines, as a cause (TlsInitializationFailed, 10 Nov)
cause=$(tail -n 300 "$CRAWL_LOG" | grep -E ' (warning|error)\(' \
    | sed -E 's/^[0-9-]+ [0-9:]+ //; s/ on \/.*//; s/ page [0-9]+:/:/' \
    | sort | uniq -c | sort -rn | head -n 1 | sed -E 's/^ *[0-9]+ //' | cut -c1-120)
why+=", up since $(stamp "$started" '%FT%TZ')${cause:+; commonest warning: $cause}"

# A held reason is logged once while it lasts
hold() {
    [[ "$(cat "$held" 2> /dev/null)" == "$1" ]] && exit 0
    echo "$1" > "$held"
    say "held: $2 ($why)"
    exit 0
}
hour=$(stamp "$now" %H)
(( 10#$hour >= 4 && 10#$hour < 7 )) && hold quiet "04-07 UTC, crawler restarts wait"
pgrep -f '^bin/meiolol curves' > /dev/null && hold curves "a curves pass is running"
prev=$(sed -n 's/^\([^ ]*\) restarted: .*/\1/p' "$LOG" 2> /dev/null | tail -n 1)
if [[ -n "$prev" ]]; then
    p=$(date -d "$prev" +%s)
    if (( started - p >= 0 && started - p < 900 && last == 0 )); then
        hold failed "the auto restart at $prev didn't help: this crawler has had no answer since; needs a look"
    fi
    (( now - p < REVIVE_GAP_H * 3600 )) && hold gap "last auto restart at $prev, at most one per ${REVIVE_GAP_H}h"
fi

rm -f "$held"
say "restarted: $why"
[[ -n "${REVIVE_DRY:-}" ]] && exit 0
echo "$(stamp "$now") info(revive): restarting $unit, $why (deploy/crawl-revive.sh)" >> "$CRAWL_LOG"
systemctl --user restart "$unit"
