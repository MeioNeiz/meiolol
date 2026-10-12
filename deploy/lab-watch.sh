#!/usr/bin/env bash
# Runs on the gpu-box (systemd user service meiolol-lab-watch, deploy/lab-run.sh
# watch-install). Jacob's rule: long runs only while League isn't running. Every 5 s it
# asks Windows for the League client or game; while either is up, every live run in
# ~/ml/runs is stopped (SIGSTOP to its process group), and continued once both are gone.
# A run started while League is up is stopped on the next tick. Each pause and resume
# goes to the run's pauses.log, so its timing can be explained.
set -u
cd ~/ml/runs || exit 1
tasklist=/mnt/c/Windows/System32/tasklist.exe

log() { echo "$(date -u +%FT%TZ) $*"; }

# Fails safe: if Windows can't be asked, runs stay paused
league() {
    local out
    out=$("$tasklist" /NH /FO CSV 2>/dev/null) || return 0
    grep -qiE '^"(LeagueClient|League of Legends)\.exe"' <<< "$out"
}

was=''
while true; do
    if league; then now=up; else now=down; fi
    [[ "$now" != "$was" ]] && log "League $now"
    was=$now
    for d in */; do
        d=${d%/}
        [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
        pg=$(cat "$d/job.pgid")
        kill -0 -- "-$pg" 2>/dev/null || continue
        if [[ $now == up && ! -f $d/paused ]]; then
            kill -STOP -- "-$pg" && touch "$d/paused" && log "STOP" >> "$d/pauses.log" \
                && log "paused $d"
        elif [[ $now == down && -f $d/paused ]]; then
            kill -CONT -- "-$pg" && rm "$d/paused" && log "CONT" >> "$d/pauses.log" \
                && log "resumed $d"
        fi
    done
    sleep 5
done
