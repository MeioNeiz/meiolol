#!/usr/bin/env bash
# Runs on the Mac every 30 min (launchd: deploy/net.jacob.meiolol-watch.plist): the box's
# health check, toasted with `wz notify` when the problems change, and a daily mirror of
# the box's backups (deploy/backup-mirror.sh: acked, so the box can drop its copy).
# Catches what the box cannot report itself: the box down or unreachable.
set -u
HOST=${MEIOLOL_HOST:-meiolol-cloud}
MIRROR=${MEIOLOL_MIRROR:-$HOME/Backups/meiolol}
STATE=$HOME/.cache/meiolol-watch
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$STATE"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

out=$(ssh -o ConnectTimeout=20 -o BatchMode=yes "$HOST" ml/meiolol/bin/health.sh 2>&1)
rc=$?
(( rc == 255 )) && out="$HOST unreachable (down or no network)"
(( rc == 0 )) && out=''

# Whatever the box reports, as long as it answers: problems are when a copy matters most
if (( rc != 255 )) && [[ ! -f "$STATE/mirrored" || -n $(find "$STATE/mirrored" -mmin +1200) ]]; then
    if "$ROOT/deploy/backup-mirror.sh" mac "$MIRROR" "$STATE/bin/meiolol" "$HOST" \
        ml/meiolol/bin/backup-serve.sh >> "$STATE/mirror.log" 2>&1; then
        touch "$STATE/mirrored"
    else
        out="${out:+$out
}backup mirror to the Mac failed (~/.cache/meiolol-watch/mirror.log)"
    fi
fi
if [[ -f "$STATE/mirrored" && -n $(find "$STATE/mirrored" -mmin +4320) ]]; then
    out="${out:+$out
}Mac backup mirror older than 3 days"
fi

last=$(cat "$STATE/last" 2>/dev/null)
if [[ -n "$out" && "$out" != "$last" ]]; then
    wz notify --for 60 "meiolol" "$out"
elif [[ -z "$out" && -n "$last" ]]; then
    wz notify "meiolol" "all well again"
fi
printf '%s' "$out" > "$STATE/last"
echo "$(date -u +%FT%TZ) ${out:-ok}" >> "$STATE/log"
