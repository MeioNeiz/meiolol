#!/usr/bin/env bash
# Runs on the gpu-box (systemd user service meiolol-lab-watch, deploy/lab-run.sh
# watch-install). Every 3 s (5 s while League is up):
# - League (Jacob's rule: nothing here may make League stutter): while the client or
#   game is up, every live run in ~/ml/runs is stopped (SIGSTOP to its process group),
#   and continued once both are gone; each pause and resume goes to the run's
#   pauses.log. A run started while League is up is stopped on the next tick
# - Agents' heavy work (zig compiles and build runners, headless Chromium and the node
#   driving it, `meiolol dev`): stopped the same way while League is up, the groups in
#   ~/.cache/meiolol-league-stopped, continued when it closes and when the watcher stops
#   or starts, so nothing stays frozen. deploy/slots.sh starts no build while the state
#   in ~/.cache/meiolol-league (up, down or unknown, written each tick) isn't down
# - WSL restarts (a shutdown, a reboot): at start, a run that was live when WSL went down
#   (job.pgid from the last day, older than this boot, no exit) runs again in its dir,
#   twice at most (restarts); runs resume from their own checkpoints, if they keep any
# - Sleep (Jacob: awake while busy): while a run is live, or another job keeps a file in
#   ~/ml/awake.d fresh (touched in the last 15 min, eg the archive pull), Windows is held
#   awake by deploy/windows/meiolol-awake.ps1, which watches a flag file this keeps fresh
# - Builds (deploy/remote-build.sh, jobs in ~/ml/build/jobs): ended while League is up,
#   and keep Windows awake while one runs
# Tests (deploy/lab-watch-test.sh): MEIOLOL_WATCH_TEST=DIR keeps every path under DIR,
# asks DIR/tasklist instead of Windows and stops only processes of its own session
set -u
win=/mnt/c/Windows/System32
test_dir=${MEIOLOL_WATCH_TEST-}
if [[ -n $test_dir ]]; then
    runs=$test_dir/runs jobs=$test_dir/jobs awake_d=$test_dir/awake.d home=$test_dir/win
    cache=$test_dir tasklist=$test_dir/tasklist tick=1 vbs=''
    mkdir -p "$runs" "$jobs" "$home"
else
    runs=~/ml/runs jobs=~/ml/build/jobs awake_d=~/ml/awake.d cache=~/.cache tick=3
    tasklist=$win/tasklist.exe
    home=$(cd /mnt/c && $win/cmd.exe /c 'echo %USERPROFILE%' 2> /dev/null < /dev/null)
    home=$(wslpath "${home%$'\r'}")/.meiolol
    vbs=$(wslpath -w "$home/meiolol-awake.vbs")
fi
cd "$runs" || exit 1
mkdir -p "$awake_d" "$cache"
state=$cache/meiolol-league
stopped=$cache/meiolol-league-stopped
flag=$home/awake
# The holder's own log (taken, state every 10 min, released and why), copied in here
alog=$home/awake.log
alog_at=$(stat -c %s "$alog" 2> /dev/null || echo 0)

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

# Agents' heavy work, one "g PGID ARGS" (stop the group) or "p PID ARGS" (that process
# alone) per line: zig compiles and build runners (test binaries share their group),
# headless Chromium and the node that drives it (Playwright starts the browser in a group
# of its own), `meiolol dev`. A group is stopped whole, so a Bash call's pipeline (tail,
# slots.sh) waits with it, unless it holds something that must keep going (Claude, ssh,
# systemd, a login shell): then only the matching processes. Groups in SKIP (runs, build
# jobs, this watcher) are left to their own rules
heavy() {
    local only=''
    [[ -n $test_dir ]] && only=$(ps -o sid= -p $$)
    ps -u "$(id -u)" -o pid=,pgid=,sid=,ppid=,comm=,args= \
        | awk -v skip=" $1 " -v only="$only" '
        {
            pid = $1; pg[pid] = $2; sid[pid] = $3; pp[pid] = $4; comm[pid] = $5
            a = $0; sub(/^ *[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[^ ]+ +/, "", a); args[pid] = a
        }
        function heavy(p, a0) {
            if (comm[p] ~ /^(zig|maker|chrome|chromium|headless_shell)$/) return 1
            a0 = args[p]; sub(/ .*/, "", a0)
            if (a0 ~ /\/(\.zig-cache|\.cache\/zig)\/o\//) return 1
            if (args[p] ~ /(^|\/)meiolol(-app)? dev( |$)/) return 1
            return comm[p] == "node" && args[p] ~ /playwright/
        }
        function keep(p) {
            # Claude runs as "claude" or as its version; login shells as "-bash"
            return comm[p] ~ /^(claude|ssh|sshd|systemd|init|login|sudo|su)$/ \
                || comm[p] ~ /^(tmux|wezterm)/ || comm[p] ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ \
                || args[p] ~ /^-/
        }
        END {
            for (p in pg) {
                if (keep(p)) held[pg[p]] = 1
                if (only != "" && sid[p] + 0 != only + 0) continue
                if (!heavy(p)) continue
                want[p] = 1
                if (comm[p] ~ /^(chrome|chromium|headless_shell)$/ && comm[pp[p]] == "node")
                    want[pp[p]] = 1
            }
            for (p in want) {
                g = pg[p]
                if (g <= 1 || index(skip, " " g " ")) continue
                if (held[g]) { if (!seen["p" p]++) print "p", p, substr(args[p], 1, 90) }
                else if (!seen["g" g]++)
                    print "g", g, substr(args[g] != "" ? args[g] : args[p], 1, 90)
            }
        }'
}

# Stops what heavy finds that isn't stopped yet; recorded first, so a watcher killed
# mid-tick still continues it
quiet() {
    local kind id what
    while read -r kind id what; do
        grep -qx "$kind $id" "$stopped" 2> /dev/null && continue
        echo "$kind $id" >> "$stopped"
        if [[ $kind == g ]]; then
            kill -STOP -- "-$id" 2> /dev/null && log "quiet: stopped group $id: $what"
        else
            kill -STOP "$id" 2> /dev/null && log "quiet: stopped process $id: $what"
        fi
    done < <(heavy "$1")
}

# Continues every recorded group and process (WHY for the log)
unquiet() {
    local kind id
    [[ -s $stopped ]] || { rm -f "$stopped"; return; }
    while read -r kind id; do
        if [[ $kind == g ]]; then id=-$id; fi
        kill -CONT -- "$id" 2> /dev/null
    done < "$stopped"
    log "quiet: continued $(wc -l < "$stopped") ($1)"
    rm -f "$stopped"
}

# A previous watcher's stops (killed before its trap ran), unless from before this boot
boot=$(awk '$1 == "btime" { print $2 }' /proc/stat)
if [[ -f $stopped ]] && (( $(stat -c %Y "$stopped") < boot )); then rm -f "$stopped"; fi
unquiet "watcher start"
trap 'unquiet "watcher stopping"; rm -f "$state"; exit 0' TERM INT HUP

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
    echo "$league" > "$state.new" && mv "$state.new" "$state"
    now=up
    [[ $league == down ]] && now=down
    busy='' skip=$$
    for d in */; do
        d=${d%/}
        [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
        pg=$(cat "$d/job.pgid")
        kill -0 -- "-$pg" 2>/dev/null || continue
        busy=$d skip+=" $pg"
        if [[ $now == up && ! -f $d/paused ]]; then
            kill -STOP -- "-$pg" && touch "$d/paused" && log "STOP" >> "$d/pauses.log" \
                && log "paused $d"
        elif [[ $now == down && -f $d/paused ]]; then
            kill -CONT -- "-$pg" && rm "$d/paused" && log "CONT" >> "$d/pauses.log" \
                && log "resumed $d"
        fi
    done
    # Builds (deploy/build-job.sh) end instead: the Mac builds them again, while a paused
    # build would hold a session or a push
    for d in "$jobs"/*/; do
        [[ -f $d/job.pgid && ! -f $d/exit ]] || continue
        pg=$(cat "$d/job.pgid")
        kill -0 -- "-$pg" 2> /dev/null || continue
        skip+=" $pg"
        if [[ $now == up ]]; then
            kill -TERM -- "-$pg" && log "ended build ${d%/} (League $league)"
        else
            busy=build
        fi
    done
    # Not "League down": lab-place reads watcher.log's League lines as sessions
    if [[ $now == up ]]; then quiet "$skip"; else unquiet "game closed"; fi
    [[ -n $busy ]] || busy=$(find "$awake_d" -type f -mmin -15 -printf '%f\n' | head -1)
    if [[ -n $busy ]]; then
        touch "$flag"
        # No holder in tests
        if [[ -n $vbs ]] && { [[ -z $holder ]] || ! kill -0 "$holder" 2>/dev/null; }; then
            (cd /mnt/c && exec "$win/wscript.exe" "$vbs" "$(wslpath -w "$flag")") &
            holder=$!
        fi
    else
        rm -f "$flag"
    fi
    [[ "$busy" != "$busy_was" ]] && log "awake: ${busy:-no (Windows may sleep)}"
    busy_was=$busy
    size=$(stat -c %s "$alog" 2> /dev/null || echo 0)
    (( size < alog_at )) && alog_at=0
    if (( size > alog_at )); then
        tail -c +$(( alog_at + 1 )) "$alog" | tr -d '\r' | sed 's/Z awake/Z holder: awake/'
        alog_at=$size
    fi
    # In the background, so a stop's trap runs at once, not after the sleep
    if [[ $now == up ]]; then sleep $(( tick + 2 )) & else sleep "$tick" & fi
    wait $!
done
