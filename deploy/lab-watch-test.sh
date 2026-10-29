#!/usr/bin/env bash
# Tests deploy/lab-watch.sh's League rules and deploy/slots.sh's League wait with a fake
# tasklist, in a scratch dir, on stand-in processes in a session of its own (the watcher
# under test stops nothing outside it): a zig build tree, a Chromium, a `meiolol dev`, a
# `meiolol-lab bench`, a zig beside an ssh (only the zig stops), a lab run of meiolol-lab
# (paused by the run rule, not recorded), a meiolol from ~/ml/bin, a Claude whose args
# say `meiolol dev`, a plain loop (the last three left alone), a zig run by a job-control
# shell (a Claude Bash call: both stop, the shell never sees 147), a terminal's login shell
# (it and its own job run on, a zig below that job stops). Checks: the client alone
# pauses the lab run but not builds or slots; the game stops everything and slots wait;
# the game closing while the client stays continues builds and lets slots go, the run
# waits for the client; slots don't renice; Windows failing once or twice changes
# nothing, an empty answer isn't down, 3 failures in a row pause, and after the grace
# agents' work goes on while the run stays paused; an unwritable list stops nothing; a
# watcher stopped (TERM, even mid-hang in tasklist), killed (KILL, then a new one, even
# with tasklist hanging or ~/ml/runs gone, or `resume` as the unit's ExecStopPost) leaves
# nothing stopped; a list from another boot or a reused pid continues nothing.
# On the gpu-box: deploy/lab-watch-test.sh (about 2 min)
set -u
[ "$(ps -o sid= -p $$ | tr -d ' ')" = $$ ] || exec setsid -w "$0" "$@"
set -m
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
pids=() watcher=''
cleanup() {
    [ -n "$watcher" ] && kill -KILL "$watcher" 2> /dev/null
    for p in "${pids[@]}"; do kill -CONT -- "-$p" 2> /dev/null; kill -KILL -- "-$p" 2> /dev/null; done
    rm -rf "$t"
}
trap cleanup EXIT
fails=0
ok() { echo "$(date -u +%T) ok: $1"; }
bad() { echo "$(date -u +%T) FAIL: $1"; fails=1; }

mkdir -p "$t/bin" "$t/mlbin" "$t/runs/r1"
cat > "$t/tasklist" << END
#!/bin/sh
[ -f $t/hang ] && exec sleep 100
n=\$(cat $t/failn 2> /dev/null || echo 0)
if [ "\$n" -gt 0 ]; then echo \$((n - 1)) > $t/failn; exit 1; fi
[ -f $t/fail ] && exit 1
[ -f $t/empty ] && exit 0
[ -f $t/client ] && echo '"LeagueClient.exe","1","Console","1","1 K"'
[ -f $t/game ] && echo '"League of Legends.exe","3","Console","1","1 K"'
echo '"explorer.exe","2","Console","1","1 K"'
END
printf 'while :; do sleep 0.2; done\n' > "$t/spin"
for n in zig chrome ssh loop claude; do printf '#!/bin/sh\n. %s\n' "$t/spin" > "$t/bin/$n"; done
mkdir "$t/jc"
printf '#!/bin/sh\nwhile [ ! -f %s/done ]; do sleep 0.2; done\n' "$t" > "$t/jc/zig"
cat > "$t/termjob" << 'END'
set -m
bash -c '"$1" build & wait' _ "$1" &
"$1" build
END
chmod +x "$t/tasklist" "$t"/bin/* "$t/jc/zig"
# Binaries (comm and /proc/PID/exe as a real build's) running the spin script
for f in bin/meiolol bin/meiolol-lab mlbin/meiolol; do cp "$(command -v bash)" "$t/$f"; done
# Each & under set -m: a process group of its own, as a Bash call's pipeline
bash -c '"$1" build & "$1" build-exe & wait' _ "$t/bin/zig" & build=$!
"$t/bin/chrome" --headless & chrome=$!
"$t/bin/meiolol" "$t/spin" dev --port 1 & dev=$!
"$t/bin/meiolol-lab" "$t/spin" bench & bench=$!
bash -c '"$1" -N host & "$2" build & wait' _ "$t/bin/ssh" "$t/bin/zig" & mixed=$!
"$t/bin/loop" & plain=$!
"$t/mlbin/meiolol" "$t/spin" backup --mirror & mlbin=$!
"$t/bin/claude" "run zig-out/bin/meiolol dev --port 8099 and check playwright" & claude=$!
"$t/bin/meiolol-lab" "$t/spin" run & run=$!
# A Claude Bash call: bash -c under set -m, its command a group of its own
bash -c 'set -m; "$1" build; echo "rc=$?" > "$2"' _ "$t/jc/zig" "$t/rc" & jcsh=$!
(exec -a -bash bash "$t/termjob" "$t/bin/zig") & term=$!
pids+=("$build" "$chrome" "$dev" "$bench" "$mixed" "$plain" "$mlbin" "$claude" "$run")
pids+=("$jcsh" "$term")
echo "$run" > "$t/runs/r1/job.pgid"
heavy=("$build" "$chrome" "$dev" "$bench")
spared=("$plain" "$mlbin" "$claude")

watch() {
    MEIOLOL_WATCH_TEST=$t bash "$here/lab-watch.sh" >> "$t/watch.err" 2>&1 &
    watcher=$!
}
stop_watcher() { kill "-$1" "$watcher"; wait "$watcher" 2> /dev/null; watcher=''; }
logs() { cat "$t/watch.err" "$t/runs/watcher.log" "$t/meiolol-lab-watch.log" 2> /dev/null; }
# ps of group G's processes (ps -g selects a session)
members() { pgrep -g "$1" | xargs -r ps -o "$2" -p; }
# Every process of group G is (s)topped or (r)unning. Zombies don't count: a sleep that
# ended as its stopped parent stopped stays one until the parent continues
group() {
    local st
    st=$(members "$1" stat= | cut -c1 | grep -v Z | sort -u | tr -d '\n')
    if [ "$2" = s ]; then [ "$st" = T ]; else [ -n "$st" ] && [[ $st != *T* ]]; fi
}
# Every group given is (s)topped or (r)unning: all S G...
all() {
    local s=$1 g
    shift
    for g in "$@"; do group "$g" "$s" || return 1; done
}
proc() { [[ $(ps -o stat= -p "$1") == T* ]]; }
child() { pgrep -g "$1" -x "$2"; }
# Up to N half seconds for CMD to pass
until_ok() {
    local n=$1
    shift
    while ((n-- > 0)); do "$@" && return 0; sleep 0.5; done
    return 1
}
slots() {
    MEIOLOL_LEAGUE_FILE=$t/meiolol-league-game MEIOLOL_SLOTS_DIR=$t/slots "$here/slots.sh" "$@"
}
# Slots grant one within N s
slot_goes() {
    timeout "$1" bash -c 'MEIOLOL_LEAGUE_FILE=$1 MEIOLOL_SLOTS_DIR=$2 "$3" 1 true' _ \
        "$t/meiolol-league-game" "$t/slots" "$here/slots.sh" 2> "$t/slots.err"
}
# The two state files say LEAGUE and GAME
states() {
    [ "$(cat "$t/meiolol-league" 2> /dev/null)" = "$1" ] \
        && [ "$(cat "$t/meiolol-league-game" 2> /dev/null)" = "$2" ]
}
said() {
    echo "$(cat "$t/meiolol-league" 2> /dev/null)/$(cat "$t/meiolol-league-game" 2> /dev/null)"
}
spared_run() {
    all r "${spared[@]}" && ok "$1: plain loop, ~/ml/bin's meiolol, Claude run on" \
        || bad "$1: a spared group was stopped: $(ps -o pid=,stat=,args= -p "$plain,$mlbin,$claude")"
}

jcjob='' tzig='' tsh='' tin=''
# shellcheck disable=SC2016 # eval expands them
until_ok 10 eval 'jcjob=$(pgrep -P "$jcsh" -x zig) && tzig=$(pgrep -P "$term" -x zig) \
    && tsh=$(pgrep -P "$term" -x bash) && tin=$(pgrep -P "$tsh" -x zig)' \
    || bad "job-control stand-ins didn't start"
pids+=("$jcjob" "$tzig" "$tsh")

watch
until_ok 10 states down down && ok "state files say down" || bad "state files: $(said)"
all r "${heavy[@]}" "$mixed" "$run" "${spared[@]}" || bad "a group not running at start"
slot_goes 5 && ok "slots go while League is down" || bad "slots waited while down"
[ "$(slots 1 sh -c 'ps -o ni= -p $$' | tr -d ' ')" = "$(ps -o ni= -p $$ | tr -d ' ')" ] \
    && ok "a slot's run keeps its nice" || bad "a slot's run was reniced"

echo 4 > "$t/failn"
until_ok 10 eval '[ "$(cat "$t/failn")" = 0 ]' || bad "tasklist not asked 4 times"
sleep 2
if logs | grep -q "League unknown" || ! all r "${heavy[@]}" || ! states down down; then
    bad "2 ticks of failures changed something: $(said)"
else
    ok "tasklist failing twice in two ticks changes nothing"
fi

touch "$t/client"
until_ok 10 states up down && ok "client alone: state files say up, game down" \
    || bad "client: $(said)"
until_ok 4 test -f "$t/runs/r1/paused" && group "$run" s && ok "client alone: the lab run paused" \
    || bad "client alone: lab run not paused"
sleep 3
all r "${heavy[@]}" "$mixed" || bad "client alone: a group stopped"
[ -f "$t/meiolol-league-stopped" ] && bad "client alone: stopped list made" \
    || ok "client alone: builds, chromium and dev run on"
slot_goes 5 && ok "client alone: slots go" \
    || bad "client alone: slots waited: $(cat "$t/slots.err")"

touch "$t/game"
if until_ok 10 group "$build" s; then ok "game up: the zig build's group stopped whole"
else bad "zig build group: $(members "$build" pid=,stat=,args=)"; fi
until_ok 4 group "$chrome" s && ok "chromium stopped" || bad "chromium not stopped"
until_ok 4 group "$dev" s && ok "meiolol dev stopped" || bad "meiolol dev not stopped"
until_ok 4 group "$bench" s && ok "meiolol-lab bench stopped" || bad "meiolol-lab bench not stopped"
z=$(child "$mixed" zig) s=$(child "$mixed" ssh)
if until_ok 4 proc "$z" && ! proc "$s"; then ok "beside ssh: the zig alone stopped"
else bad "beside ssh: zig $(ps -o stat= -p "$z"), ssh $(ps -o stat= -p "$s")"; fi
spared_run "game up"
group "$run" s && ok "the lab run stays paused" || bad "lab run not paused"
grep -q " $run " "$t/meiolol-league-stopped" && bad "the lab run is in the stopped list" \
    || ok "the lab run is not in the stopped list"
head -1 "$t/meiolol-league-stopped" | grep -qx "boot $(cat /proc/sys/kernel/random/boot_id)" \
    && ok "the stopped list names this boot" || bad "stopped list: $(head -1 "$t/meiolol-league-stopped")"
states up up && ok "state files say up, game up" || bad "game: $(said)"
if all s "$jcsh" "$jcjob" && [ ! -e "$t/rc" ]; then
    ok "a job-control shell's job: both stopped, the shell saw nothing"
else
    bad "job-control shell: $(ps -o pid=,stat= -p "$jcsh,$jcjob"), $(cat "$t/rc" 2> /dev/null)"
fi
if proc "$tin" && ! proc "$term" && ! proc "$tzig" && ! proc "$tsh"; then
    ok "a terminal: only the zig below its job stopped"
else
    bad "terminal: $(ps -o pid=,stat=,args= -p "$term,$tzig,$tsh,$tin")"
fi
if slot_goes 3; then
    bad "slots went while the game is up"
else
    grep -q "League game up" "$t/slots.err" && ok "slots wait while the game is up, and say why" \
        || bad "slots: $(cat "$t/slots.err")"
fi
slots 1 touch "$t/ran" 2> /dev/null & waiter=$!
pids+=("$waiter")

touch "$t/empty"
sleep 4
if ! all s "${heavy[@]}" || [ "$(cat "$t/meiolol-league-game")" = down ]; then
    bad "an empty answer read as down: $(said)"
fi
until_ok 20 eval 'logs | grep -q "League unknown"' && ok "empty answers: unknown, not down" \
    || bad "empty answers: no unknown after 3 ticks: $(said)"
all s "${heavy[@]}" || bad "empty answers: something continued"
rm "$t/empty"

rm "$t/game"
if until_ok 10 group "$build" r; then ok "game closed, client up: the zig build continues"
else bad "zig build after the game: $(members "$build" pid=,stat=)"; fi
until_ok 4 all r "${heavy[@]}" "$mixed" || bad "a group still stopped after the game"
touch "$t/done"
until_ok 10 grep -qx rc=0 "$t/rc" && ok "the job-control shell's job ended well after the game" \
    || bad "job-control shell after the game: $(cat "$t/rc" 2> /dev/null)"
! proc "$tin" && ok "the terminal's zig continues" || bad "the terminal's zig stays stopped"
until_ok 10 test -f "$t/ran" && ok "the waiting slot went once the game closed" \
    || bad "the waiting slot never went"
[ -f "$t/meiolol-league-stopped" ] && bad "stopped list left after the game" \
    || ok "stopped list emptied"
states up down && group "$run" s && ok "client still up: the lab run stays paused" \
    || bad "client still up: $(said), run $(members "$run" stat=)"

rm "$t/client"
until_ok 10 group "$run" r && ok "client closed: the lab run continues" || bad "lab run still paused"

# Windows unanswered for good, the game down
touch "$t/fail"
if until_ok 20 states unknown unknown && until_ok 6 all s "${heavy[@]}"; then
    ok "3 failures in a row: unknown, agents' work stopped"
else
    bad "persistent failure: $(said), $(ps -o pid=,stat= -p "$build,$dev")"
fi
until_ok 6 group "$run" s && ok "unknown: the lab run paused" || bad "unknown: lab run running"
slot_goes 2 && bad "slots went while unknown" || ok "slots wait while unknown"
if until_ok 30 states unknown blind && until_ok 6 all r "${heavy[@]}" "$mixed"; then
    ok "unknown past the grace: agents' work continues, game state blind"
else
    bad "after the grace: $(said), $(ps -o pid=,stat= -p "$build,$dev")"
fi
logs | grep -q "WARNING: Windows unanswered" && ok "and a WARNING line" || bad "no WARNING line"
group "$run" s && ok "unknown past the grace: the lab run stays paused" \
    || bad "unknown past the grace: lab run running"
slot_goes 5 && ok "slots go once blind" || bad "slots waited while blind"
rm "$t/fail"
until_ok 10 states down down && until_ok 6 group "$run" r \
    && ok "Windows answers again: down, the run continues" || bad "after unknown: $(said)"

# The list can't be written: nothing stopped
mkdir "$t/meiolol-league-stopped"
touch "$t/game"
until_ok 10 states up up || bad "game: $(said)"
sleep 3
all r "${heavy[@]}" && logs | grep -q "can't write" \
    && ok "list unwritable: nothing stopped, logged" || bad "list unwritable: something stopped"
rmdir "$t/meiolol-league-stopped"
until_ok 10 all s "${heavy[@]}" || bad "list writable again: not stopped"

# Stopped while tasklist hangs
touch "$t/hang"
sleep 1
kill -TERM "$watcher"
until_ok 20 eval '! kill -0 "$watcher" 2> /dev/null' && ok "watcher stopped mid-hang: it exits" \
    || bad "watcher stopped mid-hang: still running"
wait "$watcher" 2> /dev/null
all r "${heavy[@]}" && ok "watcher stopped: everything continued" \
    || bad "watcher stopped: something stays stopped"
if [ -f "$t/meiolol-league" ] || [ -f "$t/meiolol-league-game" ]; then
    bad "state file left by a stopped watcher"
else
    ok "state files removed on stop"
fi
rm "$t/hang"
watch
until_ok 10 all s "${heavy[@]}" && ok "a new watcher stops it again" || bad "the new watcher didn't stop it"

# Killed; the new one finds tasklist hanging: it continues everything first
touch "$t/hang"
stop_watcher KILL
group "$build" s || bad "killed watcher: expected the group still stopped"
watch
until_ok 4 all r "${heavy[@]}" "$mixed" && ok "killed, new watcher with tasklist hanging: continued at once" \
    || bad "killed, new watcher, tasklist hanging: something stays stopped"
rm "$t/hang"
until_ok 20 all s "${heavy[@]}" || bad "tasklist answers again: not stopped"

# Killed; the unit's ExecStopPost
stop_watcher KILL
MEIOLOL_WATCH_TEST=$t bash "$here/lab-watch.sh" resume >> "$t/watch.err" 2>&1
all r "${heavy[@]}" "$mixed" && ok "killed, then resume: everything continued" \
    || bad "killed, then resume: something stays stopped"
[ -e "$t/meiolol-league-stopped" ] || [ -e "$t/meiolol-league-game" ] \
    && bad "resume left the list or a state file" || ok "resume removed the list and state files"

# Killed while ~/ml/runs is gone
watch
until_ok 10 all s "${heavy[@]}" || bad "not stopped again"
stop_watcher KILL
mv "$t/runs" "$t/runs.away"
watch
# The game is up: it stops them again at once, so the log says it continued them
until_ok 4 grep -q "continued 6 (watcher start)" "$t/meiolol-lab-watch.log" \
    && ok "runs dir gone: a new watcher continues everything, logs in the cache" \
    || bad "runs dir gone: $(cat "$t/meiolol-lab-watch.log" "$t/watch.err")"
until_ok 10 all s "${heavy[@]}" && ok "runs dir gone: the watcher runs on" \
    || bad "runs dir gone: the watcher doesn't work"
stop_watcher TERM
mv "$t/runs.away" "$t/runs"

# Killed, the game closed meanwhile
watch
until_ok 10 all s "${heavy[@]}" || bad "not stopped again"
stop_watcher KILL
rm "$t/game"
group "$build" s || bad "killed watcher: expected the group still stopped"
watch
if until_ok 10 all r "${heavy[@]}"; then
    ok "watcher killed, then a new one with League down: everything continued"
else
    bad "after a killed watcher: something stays stopped"
fi
until_ok 10 states down down || bad "states: $(said)"
stop_watcher TERM

# A list from another boot; an entry whose pid is another process now
kill -STOP -- "-$build"
kill -STOP -- "-$plain"
printf 'boot not-this-one\ng %s -\n' "$build" > "$t/meiolol-league-stopped"
watch
until_ok 10 states down down || bad "states: $(said)"
group "$build" s && ok "a list from another boot continues nothing" \
    || bad "a list from another boot continued its group"
stop_watcher TERM
printf 'boot %s\ng %s 1\n' "$(cat /proc/sys/kernel/random/boot_id)" "$plain" > "$t/meiolol-league-stopped"
watch
until_ok 10 states down down || bad "states: $(said)"
group "$plain" s && ok "a reused pid is not continued" || bad "a reused pid was continued"
stop_watcher TERM
kill -CONT -- "-$build"
kill -CONT -- "-$plain"

echo "--- watcher log"
logs
[ $fails = 0 ] && echo "all ok" || echo "FAILED"
exit $fails
