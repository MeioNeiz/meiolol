#!/usr/bin/env bash
# Runs on the gpu-box (systemd user service meiolol-lab-watch, deploy/lab-run.sh
# watch-install). Every 3 s (5 s while League is up):
# - League (Jacob's rule: nothing here may make League stutter): while the client or
#   game is up, every live run in ~/ml/runs is stopped (SIGSTOP to its process group),
#   and continued once both are gone; each pause and resume goes to the run's
#   pauses.log. A run started while League is up is stopped on the next tick
# - Agents' heavy work (zig compiles and build runners, headless Chromium and the node
#   driving it, meiolol binaries not in ~/ml/bin: `meiolol dev|eval`, `meiolol-lab
#   bench`): stopped the same way while the game (League of Legends.exe) runs, not for
#   the client alone (Jacob), the groups in ~/.cache/meiolol-league-stopped, continued
#   when the game closes and when the watcher stops or starts (and by the unit's
#   ExecStopPost, `lab-watch.sh resume`, after any exit), so nothing stays frozen; a
#   watcher stuck (a /mnt/c read or tasklist.exe that won't end) leaves the game state
#   unwritten: past STALE s (slots.sh's rule) the timer's `resume-stale` continues
#   them. State each tick (up, down, unknown, blind): client or game in
#   ~/.cache/meiolol-league, the game alone in ~/.cache/meiolol-league-game, where
#   deploy/slots.sh waits on up or unknown
# - Windows unanswered (tasklist failed, hung or said nothing, twice in a tick): nothing
#   changes until 3 ticks in a row; then unknown, which pauses like the game. After
#   GRACE (3 min) of it, agents' work goes on (game state blind, a WARNING line every
#   10 min) and runs stay paused
# - WSL restarts (a shutdown, a reboot): a run that was live when WSL went down runs
#   again, once ~/ml/runs is there (runs_back)
# - Sleep (Jacob: awake while busy): while a run is live, or another job keeps a file in
#   ~/ml/awake.d fresh (touched in the last 15 min, eg the archive pull), Windows is held
#   awake by deploy/windows/meiolol-awake.ps1, which watches a flag file this keeps fresh
# - Builds (deploy/remote-build.sh, jobs in ~/ml/build/jobs): ended while League is up,
#   and keep Windows awake while one runs
# Log: ~/ml/runs/watcher.log, or ~/.cache/meiolol-lab-watch.log when ~/ml/runs is missing
# or read-only (the lab disk not mounted yet, or a reset); runs are left alone until it is
# back, and the log moves back with them.
# Tests (deploy/lab-watch-test.sh): MEIOLOL_WATCH_TEST=DIR keeps every path under DIR,
# asks DIR/tasklist instead of Windows and stops only processes of its own session
#   lab-watch.sh           the watcher
#   lab-watch.sh resume    continues what a watcher stopped, removes its state, exits
#   lab-watch.sh resume-stale  the same, only if the game state is over STALE s old
#                          (meiolol-lab-watch-stale.timer, each minute)
set -u
win=/mnt/c/Windows/System32
test_dir=${MEIOLOL_WATCH_TEST-}
if [[ -n $test_dir ]]; then
    runs=$test_dir/runs jobs=$test_dir/jobs awake_d=$test_dir/awake.d cache=$test_dir
    mlbin=$test_dir/mlbin tasklist=$test_dir/tasklist tick=1 ask_s=2 retry_s=0.2 grace=12
    stale=5
else
    runs=~/ml/runs jobs=~/ml/build/jobs awake_d=~/ml/awake.d cache=~/.cache mlbin=~/ml/bin
    tasklist=$win/tasklist.exe tick=3 ask_s=10 retry_s=1 grace=180 stale=60
fi
mkdir -p "$cache"
state=$cache/meiolol-league
gstate=$cache/meiolol-league-game
stopped=$cache/meiolol-league-stopped
logf=$runs/watcher.log
{ : >> "$logf"; } 2> /dev/null || logf=$cache/meiolol-lab-watch.log
exec >> "$logf" 2>&1

log() { echo "$(date -u +%FT%TZ) $*"; }

boot=$(< /proc/sys/kernel/random/boot_id)

# PID's start time (/proc/PID/stat field 22), - when gone
started() {
    local s f
    { s=$(< "/proc/$1/stat"); } 2> /dev/null || { echo -; return; }
    read -ra f <<< "${s##*) }"
    echo "${f[19]}"
}

# The stopped list: "boot BOOT_ID", then "g PGID START" (a group, START its leader's, -
# if gone) or "p PID START". Continues each entry from this boot whose pid still is the
# process recorded (a reused pid is left alone), last first; WHY for the log. A list from another
# boot names nothing alive. Before boot ids (721b1b48): entries alone, all continued
unquiet() {
    local kind id at s n=0 first
    [[ -f $stopped ]] || return 0
    first=$(head -1 "$stopped")
    if [[ $first == "boot $boot" || $first != boot* ]]; then
        while read -r kind id at; do
            # 1 or less would continue every process (kill -CONT -- -1)
            [[ $kind == [gp] && $id =~ ^[0-9]+$ ]] && (( id > 1 )) || continue
            s=$(started "$id")
            [[ -z $at || $at == - || $s == - || $s == "$at" ]] || continue
            [[ $kind == g ]] && id=-$id
            kill -CONT -- "$id" 2> /dev/null
            n=$((n + 1))
        done < <(tac "$stopped")
        log "quiet: continued $n ($1)"
    else
        log "quiet: dropped a stopped list from another boot ($1)"
    fi
    rm -f "$stopped"
}

# First, before anything that can hang (Windows) or fail (~/ml/runs): a previous
# watcher's stops, if it died before its trap ran
if [[ ${1-} == resume ]]; then
    unquiet "watcher exited"
    rm -f "$state" "$gstate"
    exit 0
fi
if [[ ${1-} == resume-stale ]]; then
    [[ -f $stopped ]] || exit 0
    age=$(( $(date +%s) - $(stat -c %Y "$gstate" 2> /dev/null || echo 0) ))
    (( age > stale )) || exit 0
    log "WARNING: watcher stuck (game state ${age}s old): continuing what it stopped"
    unquiet "watcher stuck"
    exit 0
fi
unquiet "watcher start"
trap 'unquiet "watcher stopping"; rm -f "$state" "$gstate"; exit 0' TERM INT HUP
[[ $logf == "$runs"/* ]] || log "$runs not writable: logging here, runs left alone until it is"

# One answer from Windows: game (League of Legends.exe, client or not), client (the
# client alone), down, or unknown (tasklist failed, hung past ASK_S or listed nothing)
ask() {
    local out
    out=$(timeout -k 2 "$ask_s" "$tasklist" /NH /FO CSV 2> /dev/null < /dev/null) \
        || { echo unknown; return; }
    if grep -qi '^"League of Legends\.exe"' <<< "$out"; then echo game
    elif grep -qi '^"LeagueClient\.exe"' <<< "$out"; then echo client
    elif grep -q '^"' <<< "$out"; then echo down
    else echo unknown; fi
}
# A second try in the same tick: single failures happen (29 Oct)
# deploy/archive-pull.sh has its own check, which carries on when it can't ask
league() {
    local a
    a=$(ask)
    if [[ $a == unknown ]]; then sleep "$retry_s"; a=$(ask); fi
    echo "$a"
}

# Reads and writes on /mnt/c (9p) can hang under Windows load: bounded
win_io() { timeout -k 2 5 "$@"; }

# The Windows side of the awake holder: %USERPROFILE%\.meiolol; asked again each minute
# until Windows answers. No holder in tests
home='' vbs='' flag='' alog='' alog_at=0 home_at=0
win_home() {
    local h
    if [[ -n $test_dir ]]; then home=$test_dir/win
    else
        h=$(timeout -k 2 "$ask_s" sh -c 'cd /mnt/c && exec "$1" /c "$2"' _ "$win/cmd.exe" \
            'echo %USERPROFILE%' 2> /dev/null < /dev/null) || return 1
        h=${h%$'\r'}
        [[ -n $h ]] || return 1
        home=$(wslpath "$h")/.meiolol
        vbs=$(wslpath -w "$home/meiolol-awake.vbs")
    fi
    win_io mkdir -p "$home"
    flag=$home/awake
    # The holder's own log (taken, state every 10 min, released and why), copied in here
    alog=$home/awake.log
    alog_at=$(win_io stat -c %s "$alog" 2> /dev/null || echo 0)
}

# Agents' heavy work, one "g PGID ARGS" (stop the group) or "p PID ARGS" (that process
# alone) per line, by program name (comm), never by what's in the args: zig compiles and
# build runners (test binaries share their group), headless Chromium and the node that
# drives it (Playwright starts the browser in a group of its own; node with playwright
# as its script), meiolol binaries other than ~/ml/bin's (comm is cut to 15 chars). A
# group is stopped whole, so a Bash call's pipeline (tail, slots.sh) waits with it,
# unless it holds a keeper (Claude, ssh, systemd, a login shell, this watcher): then only
# the matching processes, never a keeper. Groups in SKIP (runs, build jobs, this watcher)
# are left to their own rules. In tests the test script (its session's leader) is no job
# shell
heavy() {
    local only='' keep_bin=' ' p snap exe
    [[ -n $test_dir ]] && only=$(ps -o sid= -p $$)
    snap=$(ps -u "$(id -u)" -o pid=,pgid=,sid=,ppid=,comm=,args=)
    # From the same snapshot: one started after it isn't in it. One gone since is kept
    for p in $(awk '$5 ~ /^meiolol/ { print $1 }' <<< "$snap"); do
        exe=$(readlink "/proc/$p/exe" 2> /dev/null)
        [[ -z $exe || $exe == "$mlbin"/* ]] && keep_bin+="$p "
    done
    awk -v skip=" $1 " -v only="$only" -v keep_bin="$keep_bin" '
        {
            pid = $1; pg[pid] = $2; sid[pid] = $3; pp[pid] = $4; comm[pid] = $5
            a = $0; sub(/^ *[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[^ ]+ +/, "", a); args[pid] = a
            n = split(a, w, " "); a0[pid] = w[1]; a1[pid] = (n > 1 ? w[2] : "")
        }
        function heavy(p) {
            if (comm[p] ~ /^(zig|maker|chrome|chromium|headless_shell)$/) return 1
            if (a0[p] ~ /\/(\.zig-cache|\.cache\/zig)\/o\//) return 1
            if (comm[p] ~ /^meiolol/ && !index(keep_bin, " " p " ")) return 1
            return comm[p] == "node" && a1[p] ~ /playwright/
        }
        function keep(p) {
            # Claude runs as "claude", its version or node; login shells as "-bash"
            return comm[p] ~ /^(claude|ssh|sshd|systemd|init|login|sudo|su)$/ \
                || comm[p] ~ /^(tmux|wezterm)/ || comm[p] ~ /^[0-9]+\.[0-9]+\.[0-9]+$/ \
                || (comm[p] == "node" && a1[p] ~ /claude/) || args[p] ~ /^-/ \
                || a0[p] ~ /lab-watch\.sh$/ || a1[p] ~ /lab-watch\.sh$/
        }
        END {
            for (p in pg) {
                if (keep(p)) { held[pg[p]] = 1; continue }
                if (only != "" && sid[p] + 0 != only + 0) continue
                if (!heavy(p)) continue
                want[p] = 1
                q = pp[p]
                if (comm[p] ~ /^(chrome|chromium|headless_shell)$/ && comm[q] == "node" \
                    && !keep(q))
                    want[q] = 1
            }
            for (p in want) {
                g = pg[p]
                if (g <= 1 || index(skip, " " g " ")) continue
                # A job-control shell waiting on a group (Claude runs each Bash call
                # under set -m, its pipeline a group of its own; timeout, setsid or a
                # nested set -m make more below) sees it stop, ends with 147 and, exiting,
                # hangs up the stopped group. So each shell above that started a group of
                # its own, up to the session leader (a Claude Bash call shell), is
                # stopped too, outermost first (continued last). Below a kept one (a login
                # shell in a terminal), whose job would stop, only processes: never one
                # a shell started
                n = 0; blocked = 0; c = g; j = pp[g]
                for (k = 0; k < 16; k++) {
                    s = pp[c]
                    if (!(c in pg) || !(s in pg) || pg[s] == c \
                        || comm[s] !~ /^(ba|da|z)?sh$/ || s + 0 == only + 0)
                        break
                    c = pg[s]
                    if (held[c] || c <= 1 || index(skip, " " c " ")) { blocked = 1; break }
                    up[++n] = c
                }
                s = sid[g]
                if (!blocked && (s in pg) && s != g && s != up[n] \
                    && comm[s] ~ /^(ba|da|z)?sh$/ && s + 0 != only + 0 && !held[s] && s > 1 \
                    && !index(skip, " " s " "))
                    up[++n] = s
                if (blocked) {
                    if (pp[p] != j && !seen["p" p]++) print "p", p, substr(args[p], 1, 90)
                    continue
                }
                for (k = n; k >= 1; k--)
                    if (!seen["g" up[k]]++)
                        print "g", up[k], "job shell of " g ": " substr(args[up[k]], 1, 70)
                if (held[g]) { if (!seen["p" p]++) print "p", p, substr(args[p], 1, 90) }
                else if (!seen["g" g]++)
                    print "g", g, substr(args[g] != "" ? args[g] : args[p], 1, 90)
            }
        }' <<< "$snap"
}

# Stops what heavy finds; recorded first (a watcher killed mid-tick still continues it)
# and never stopped unless the record is there. One recorded is stopped again, quietly:
# something else may have continued it (the kernel, for a group whose shell exited)
declare -A unrecorded
quiet() {
    local kind id what rec
    while read -r kind id what; do
        # No "League " in it: lab-place reads those lines as client-or-game sessions
        what=${what//League/league}
        rec="$kind $id $(started "$id")"
        if grep -qx "$rec" "$stopped" 2> /dev/null; then
            [[ $kind == g ]] && id=-$id
            kill -STOP -- "$id" 2> /dev/null
            continue
        fi
        { [[ -s $stopped ]] || echo "boot $boot" > "$stopped"; } 2> /dev/null
        if ! { echo "$rec" >> "$stopped" && grep -qx "$rec" "$stopped"; } 2> /dev/null; then
            [[ -n ${unrecorded[$kind$id]-} ]] \
                || log "quiet: can't write $stopped: left running $kind $id: $what"
            unrecorded[$kind$id]=1
            continue
        fi
        if [[ $kind == g ]]; then
            kill -STOP -- "-$id" 2> /dev/null && log "quiet: stopped group $id: $what"
        else
            kill -STOP "$id" 2> /dev/null && log "quiet: stopped process $id: $what"
        fi
    done < <(heavy "$1")
}

# Once ~/ml/runs is writable (at start, or later: wsl-mount.ps1 mounts the lab disk some
# seconds after WSL starts), the log moves there and runs that were live when WSL went
# down (job.pgid from the last day, older than this boot, no exit) run again in their
# dir, twice at most (restarts); runs resume from their own checkpoints, if they keep any
runs_ok=''
runs_back() {
    local d since btime
    { : >> "$runs/watcher.log"; } 2> /dev/null || return 0
    runs_ok=1
    if [[ $logf != "$runs"/* ]]; then
        logf=$runs/watcher.log
        exec >> "$logf" 2>&1
        log "$runs back: logging here (meanwhile $cache/meiolol-lab-watch.log)"
    fi
    cd "$runs" || return 0
    btime=$(awk '$1 == "btime" { print $2 }' /proc/stat)
    for d in */; do
        d=${d%/}
        [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
        since=$(stat -c %Y "$d/job.pgid")
        (( since < btime && since > btime - 86400 )) || continue
        [[ $(wc -l < "$d/restarts" 2> /dev/null || echo 0) -lt 2 ]] || continue
        rm -f "$d/paused" "$d/queued"
        log "restart" >> "$d/restarts"
        # As deploy/lab-run.sh restart: own process group, detached
        (cd "$d" && nohup perl -e 'setpgrp(0,0); exec @ARGV' ./job.sh >> log 2>&1 < /dev/null &)
        log "restarted $d (WSL restart)"
    done
}
runs_back

was='' game_was='' holder='' busy_was='' known='' fails=0 first_fail=0 warned=0
while true; do
    seen=$(league)
    if [[ $seen != unknown ]]; then
        fails=0 known=$seen
    else
        (( fails++ == 0 )) && first_fail=$SECONDS
        # Under 3 in a row: as last known; none yet (just started): nothing changes
        if (( fails < 3 )); then
            if [[ -z $known ]]; then sleep "$tick"; continue; fi
            seen=$known
        fi
    fi
    case $seen in client | game) league=up ;; *) league=$seen ;; esac
    case $seen in client) game=down ;; game) game=up ;; *) game=$seen ;; esac
    if [[ $game == unknown ]] && (( SECONDS - first_fail >= grace )); then
        game=blind
        if (( SECONDS >= warned )); then
            log "WARNING: Windows unanswered for $(( SECONDS - first_fail ))s (tasklist;" \
                "WSL interop?): agents' builds, browsers, dev servers and slots go on," \
                "runs stay paused (docs/compute.md)"
            warned=$((SECONDS + 600))
        fi
    else
        warned=0
    fi
    if [[ "$league" != "$was" ]]; then
        if [[ $league == unknown ]]; then
            log "League unknown (tasklist failed $fails times in a row): runs paused," \
                "agents' work for up to ${grace}s"
        else log "League $league"; fi
    fi
    # No "League " in it: lab-place reads those lines as client-or-game sessions
    [[ $game != "$game_was" && $game != unknown && $game != blind ]] && log "game $game"
    was=$league game_was=$game
    echo "$league" > "$state.new" && mv "$state.new" "$state"
    echo "$game" > "$gstate.new" && mv "$gstate.new" "$gstate"
    now=up
    [[ $league == down ]] && now=down
    busy='' skip=$$
    [[ -n $runs_ok ]] || runs_back
    if cd "$runs" 2> /dev/null; then
        for d in */; do
            d=${d%/}
            [[ -f $d/job.pgid && ! -f $d/exit && ! -f $d/stopped ]] || continue
            pg=$(cat "$d/job.pgid")
            # 1 or less would signal every process (kill -STOP -- -1)
            [[ $pg =~ ^[0-9]+$ ]] && (( pg > 1 )) && kill -0 -- "-$pg" 2>/dev/null || continue
            busy=$d skip+=" $pg"
            if [[ $now == up && ! -f $d/paused ]]; then
                kill -STOP -- "-$pg" && touch "$d/paused" && log "STOP" >> "$d/pauses.log" \
                    && log "paused $d"
            elif [[ $now == down && -f $d/paused ]]; then
                kill -CONT -- "-$pg" && rm "$d/paused" && log "CONT" >> "$d/pauses.log" \
                    && log "resumed $d"
            fi
        done
    fi
    # Builds (deploy/build-job.sh) end instead: the Mac builds them again, while a paused
    # build would hold a session or a push
    for d in "$jobs"/*/; do
        [[ -f $d/job.pgid && ! -f $d/exit ]] || continue
        pg=$(cat "$d/job.pgid")
        [[ $pg =~ ^[0-9]+$ ]] && (( pg > 1 )) && kill -0 -- "-$pg" 2> /dev/null || continue
        skip+=" $pg"
        if [[ $now == up ]]; then
            kill -TERM -- "-$pg" && log "ended build ${d%/} (League $league)"
        else
            busy=build
        fi
    done
    case $game in
        up | unknown) quiet "$skip" ;;
        blind) unquiet "Windows unanswered for ${grace}s" ;;
        # Not "League down": lab-place reads watcher.log's League lines as sessions
        *) unquiet "game closed" ;;
    esac
    [[ -n $busy ]] || busy=$(find "$awake_d" -type f -mmin -15 -printf '%f\n' 2> /dev/null | head -1)
    if [[ -z $home ]] && (( SECONDS >= home_at )); then
        win_home || home_at=$((SECONDS + 60))
    fi
    if [[ -z $home ]]; then
        :
    elif [[ -n $busy ]]; then
        win_io touch "$flag"
        if [[ -n $vbs ]] && { [[ -z $holder ]] || ! kill -0 "$holder" 2>/dev/null; }; then
            (cd /mnt/c && exec "$win/wscript.exe" "$vbs" "$(wslpath -w "$flag")") &
            holder=$!
        fi
    else
        win_io rm -f "$flag"
    fi
    [[ "$busy" != "$busy_was" ]] && log "awake: ${busy:-no (Windows may sleep)}"
    busy_was=$busy
    if [[ -n $alog ]]; then
        size=$(win_io stat -c %s "$alog" 2> /dev/null || echo 0)
        (( size < alog_at )) && alog_at=0
        if (( size > alog_at )); then
            win_io tail -c +$(( alog_at + 1 )) "$alog" | tr -d '\r' \
                | sed 's/Z awake/Z holder: awake/'
            alog_at=$size
        fi
    fi
    # In the background, so a stop's trap runs at once, not after the sleep
    if [[ $now == up ]]; then sleep $(( tick + 2 )) & else sleep "$tick" & fi
    wait $!
done
