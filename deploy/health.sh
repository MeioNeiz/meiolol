#!/usr/bin/env bash
# Runs on the box: prints one line per problem, exit 1 when there are any. Used by
# deploy/health-loop.sh (box, ntfy) and deploy/mac-watch.sh (Mac, wz notify). Thresholds
# in docs/data-safety.md. Keeps the crawler's last progress in data/health.state.
set -u
cd "$(dirname "$0")/.." || exit 1
BACKUPS=${MEIOLOL_BACKUPS:-/mnt/d/meiolol-backups}
STALL_H=${STALL_H:-2}
now=$(date +%s)
problems=()

if ! tmux has-session -t meiolol-crawl 2>/dev/null; then
    if tail -n 5 data/crawl.log 2>/dev/null | grep -q 'KEY REJECTED'; then
        problems+=("crawler stopped: Riot rejected the key (exit 3)")
    else
        problems+=("crawler not running (tmux meiolol-crawl gone)")
    fi
else
    # Report line every minute; its per-region "<n>m" counters are cumulative per process
    report=$(grep 'matches/day' data/crawl.log | tail -n 1)
    stamp=$(cut -c1-19 <<< "$report")
    age=$(( now - $(date -u -d "$stamp" +%s 2>/dev/null || echo 0) ))
    if (( age > 900 )); then
        problems+=("crawler silent: last report $(( age / 60 )) min ago")
    fi
    total=$(grep -oE ' [0-9]+m ' <<< "$report" | awk '{ s += $1 } END { print s + 0 }')
    state=${HEALTH_STATE:-data/health.state}
    read -r last_total last_progress < "$state" 2>/dev/null || last_progress=$now
    if [[ "${total:-0}" != "${last_total:-}" ]]; then last_progress=$now; fi
    echo "${total:-0} $last_progress" > "$state"
    if (( now - last_progress > STALL_H * 3600 )); then
        problems+=("no new matches for $(( (now - last_progress) / 3600 ))h")
    fi
fi

if ! tmux has-session -t meiolol-web 2>/dev/null; then
    problems+=("site loop not running (tmux meiolol-web gone)")
fi
uploaded=$(grep -oE '^[0-9TZ:-]+ uploaded' data/web.log 2>/dev/null | tail -n 1 | cut -d' ' -f1)
if [[ -z "$uploaded" ]] || (( now - $(date -d "$uploaded" +%s) > 26 * 3600 )); then
    problems+=("site upload stale: last ${uploaded:-never}")
fi

# /mnt/c holds the WSL disk image, so it, not /, is the real limit. D: (backups) was
# already 86% full with other things when backups started, hence 90
for limit in /mnt/c:80 /mnt/d:90 /:80; do
    mount=${limit%:*}
    use=$(df --output=pcent "$mount" 2>/dev/null | tail -n 1 | tr -dc '0-9')
    if (( ${use:-0} >= ${limit#*:} )); then problems+=("disk $mount at ${use}%"); fi
done

if ! tmux has-session -t meiolol-backup 2>/dev/null; then
    problems+=("backup loop not running (tmux meiolol-backup gone)")
fi
newest=$(ls -t "$BACKUPS"/state/state-*.db 2>/dev/null | head -n 1)
if [[ -z "$newest" ]] || (( now - $(stat -c %Y "$newest") > 26 * 3600 )); then
    problems+=("backup missing: newest ${newest:+$(basename "$newest")}${newest:-none}")
fi

(( ${#problems[@]} == 0 )) && exit 0
printf '%s\n' "${problems[@]}"
exit 1
