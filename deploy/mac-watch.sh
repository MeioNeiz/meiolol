#!/usr/bin/env bash
# Runs on the Mac every 30 min (launchd: deploy/net.jacob.meiolol-watch.plist): the box's
# health check, toasted with `wz notify` when the problems change, and a daily mirror of
# the box's backups (rsync --delete, so rotation and `forget --backups` scrubs follow).
# Catches what the box cannot report itself: the box down or unreachable.
set -u
HOST=${MEIOLOL_HOST:-meiolol-cloud}
REMOTE_BACKUPS=${MEIOLOL_REMOTE_BACKUPS:-ml/meiolol/backups}
MIRROR=${MEIOLOL_MIRROR:-$HOME/Backups/meiolol}
STATE=$HOME/.cache/meiolol-watch
mkdir -p "$STATE" "$MIRROR"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

out=$(ssh -o ConnectTimeout=20 -o BatchMode=yes "$HOST" ml/meiolol/bin/health.sh 2>&1)
rc=$?
(( rc == 255 )) && out="$HOST unreachable (down or no network)"
(( rc == 0 )) && out=''

if (( rc == 0 )) && [[ ! -f "$STATE/mirrored" || -n $(find "$STATE/mirrored" -mmin +1200) ]]; then
    if rsync -a --delete "$HOST:$REMOTE_BACKUPS/" "$MIRROR/"; then
        touch "$STATE/mirrored"
    else
        out="backup mirror to the Mac failed"
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
