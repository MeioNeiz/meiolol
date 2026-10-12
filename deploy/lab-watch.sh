#!/usr/bin/env bash
# Runs on the gpu-box (systemd user service meiolol-lab-watch, deploy/lab-run.sh
# watch-install). Every 5 s:
# - League (Jacob's rule: long runs only while League isn't running): while the client
#   or game is up, every live run in ~/ml/runs is stopped (SIGSTOP to its process
#   group), and continued once both are gone; each pause and resume goes to the run's
#   pauses.log. A run started while League is up is stopped on the next tick
# - WSL restarts (a shutdown, a reboot): at start, a run that was live when WSL went down
#   (job.pgid from the last day, older than this boot, no exit) runs again in its dir,
#   twice at most (restarts); runs resume from their own checkpoints, if they keep any
# - Sleep (Jacob: awake while busy): while a run is live, or another job keeps a file in
#   ~/ml/awake.d fresh (touched in the last 15 min, eg the archive pull), Windows is held
#   awake by deploy/windows/meiolol-awake.ps1, which watches a flag file this keeps fresh
set -u
cd ~/ml/runs || exit 1
mkdir -p ~/ml/awake.d
win=/mnt/c/Windows/System32
tasklist=$win/tasklist.exe
home=$(cd /mnt/c && $win/cmd.exe /c 'echo %USERPROFILE%' 2> /dev/null < /dev/null)
home=$(wslpath "${home%$'\r'}")/.meiolol
flag=$home/awake
vbs=$(wslpath -w "$home/meiolol-awake.vbs")

log() { echo "$(date -u +%FT%TZ) $*"; }

# Prints up, down or unknown (Windows can't be asked: interop down, tasklist failing).
# Unknown pauses like up (Jacob's rule fails safe) but is logged as itself, so a watcher
# that can't see Windows shows in watcher.log and `lab-run.sh status`, not as League.
# deploy/archive-pull.sh has its own check, which carries on when it can't ask
league() {
    local out
    out=$("$tasklist" /NH /FO CSV 2>/dev/null) || { echo unknown; return; }
    if grep -qiE '^"(LeagueClient|League of Legends)\.exe"' <<< "$out"; then echo up
    else echo down; fi
}

boot=$(awk '$1 == "btime" { print $2 }' /proc/stat)
for d in */; do
    d=${d%/}
    [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
    since=$(stat -c %Y "$d/job.pgid")
    (( since < boot && since > boot - 86400 )) || continue
    [[ $(wc -l < "$d/restarts" 2> /dev/null || echo 0) -lt 2 ]] || continue
    rm -f "$d/paused" "$d/queued"
    log "restart" >> "$d/restarts"
    # As deploy/lab-run.sh restart: own process group, detached
    (cd "$d" && nohup perl -e 'setpgrp(0,0); exec @ARGV' ./job.sh >> log 2>&1 < /dev/null &)
    log "restarted $d (WSL restart)"
done

was='' holder='' busy_was=''
while true; do
    league=$(league)
    if [[ "$league" != "$was" ]]; then
        if [[ $league == unknown ]]; then log "League unknown (tasklist failed): runs stay paused"
        else log "League $league"; fi
    fi
    was=$league
    now=up
    [[ $league == down ]] && now=down
    busy=''
    for d in */; do
        d=${d%/}
        [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
        pg=$(cat "$d/job.pgid")
        kill -0 -- "-$pg" 2>/dev/null || continue
        busy=$d
        if [[ $now == up && ! -f $d/paused ]]; then
            kill -STOP -- "-$pg" && touch "$d/paused" && log "STOP" >> "$d/pauses.log" \
                && log "paused $d"
        elif [[ $now == down && -f $d/paused ]]; then
            kill -CONT -- "-$pg" && rm "$d/paused" && log "CONT" >> "$d/pauses.log" \
                && log "resumed $d"
        fi
    done
    [[ -n $busy ]] || busy=$(find ~/ml/awake.d -type f -mmin -15 -printf '%f\n' | head -1)
    if [[ -n $busy ]]; then
        touch "$flag"
        if [[ -z $holder ]] || ! kill -0 "$holder" 2>/dev/null; then
            (cd /mnt/c && exec "$win/wscript.exe" "$vbs" "$(wslpath -w "$flag")") &
            holder=$!
        fi
    else
        rm -f "$flag"
    fi
    [[ "$busy" != "$busy_was" ]] && log "awake: ${busy:-no (Windows may sleep)}"
    busy_was=$busy
    sleep 5
done
