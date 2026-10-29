#!/usr/bin/env bash
# Tests deploy/lab-watch.sh's League rules and deploy/slots.sh's League wait with a fake
# tasklist, in a scratch dir, on stand-in processes in a session of its own (the watcher
# under test stops nothing outside it): a zig build tree, a Chromium, a `meiolol dev`, a
# zig beside an ssh (only the zig stops), a lab run (paused by the run rule, not
# recorded), a plain loop (left alone). Checks: the client alone pauses the lab run but
# not builds or slots; the game stops everything and slots wait; the game closing while
# the client stays continues builds and lets slots go, the run waits for the client;
# nice 19; a watcher stopped (TERM) or killed (KILL, then a new one) leaves nothing
# stopped. On the gpu-box: deploy/lab-watch-test.sh
set -u
[ "$(ps -o sid= -p $$ | tr -d ' ')" = $$ ] || exec setsid "$0" "$@"
set -m
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
pids=()
cleanup() {
    for p in "${pids[@]}"; do kill -CONT -- "-$p" 2> /dev/null; kill -KILL -- "-$p" 2> /dev/null; done
    rm -rf "$t"
}
trap cleanup EXIT
fails=0
ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fails=1; }

mkdir -p "$t/bin" "$t/runs/r1"
cat > "$t/tasklist" << END
#!/bin/sh
[ -f $t/client ] && echo '"LeagueClient.exe","1","Console","1","1 K"'
[ -f $t/game ] && echo '"League of Legends.exe","3","Console","1","1 K"'
echo '"explorer.exe","2","Console","1","1 K"'
END
for n in zig chrome meiolol ssh loop; do printf '#!/bin/sh\nwhile :; do sleep 0.2; done\n' > "$t/bin/$n"; done
chmod +x "$t/tasklist" "$t"/bin/*
# Each & under set -m: a process group of its own, as a Bash call's pipeline
bash -c '"$1" build & "$1" build-exe & wait' _ "$t/bin/zig" & build=$!
"$t/bin/chrome" --headless & chrome=$!
"$t/bin/meiolol" dev --port 1 & dev=$!
bash -c '"$1" -N host & "$2" build & wait' _ "$t/bin/ssh" "$t/bin/zig" & mixed=$!
"$t/bin/loop" & plain=$!
"$t/bin/zig" run & run=$!
pids+=("$build" "$chrome" "$dev" "$mixed" "$plain" "$run")
echo "$run" > "$t/runs/r1/job.pgid"

watch() { MEIOLOL_WATCH_TEST=$t bash "$here/lab-watch.sh" >> "$t/watch.log" 2>&1 & watcher=$!; }
# ps of group G's processes (ps -g selects a session)
members() { pgrep -g "$1" | xargs -r ps -o "$2" -p; }
# Every process of group G is (s)topped or (r)unning. Zombies don't count: a sleep that
# ended as its stopped parent stopped stays one until the parent continues
group() {
    local st
    st=$(members "$1" stat= | cut -c1 | grep -v Z | sort -u | tr -d '\n')
    if [ "$2" = s ]; then [ "$st" = T ]; else [ -n "$st" ] && [[ $st != *T* ]]; fi
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

watch
until_ok 10 states down down && ok "state files say down" || bad "state files: $(said)"
for g in $build $chrome $dev $mixed $plain $run; do group "$g" r || bad "group $g not running at start"; done
slot_goes 5 && ok "slots go while League is down" || bad "slots waited while down"
if grep -qi microsoft /proc/version 2> /dev/null; then
    [ "$(slots 1 sh -c 'ps -o ni= -p $$' | tr -d ' ')" = 19 ] && ok "a slot's run is at nice 19" \
        || bad "a slot's run isn't at nice 19"
fi

touch "$t/client"
until_ok 10 states up down && ok "client alone: state files say up, game down" \
    || bad "client: $(said)"
until_ok 4 test -f "$t/runs/r1/paused" && group "$run" s && ok "client alone: the lab run paused" \
    || bad "client alone: lab run not paused"
sleep 3
for g in $build $chrome $dev $mixed; do group "$g" r || bad "client alone: group $g stopped"; done
[ -f "$t/meiolol-league-stopped" ] && bad "client alone: stopped list made" \
    || ok "client alone: builds, chromium and dev run on"
slot_goes 5 && ok "client alone: slots go" \
    || bad "client alone: slots waited: $(cat "$t/slots.err")"

touch "$t/game"
if until_ok 10 group "$build" s; then ok "game up: the zig build's group stopped whole"
else bad "zig build group: $(members "$build" pid=,stat=,args=)"; fi
until_ok 4 group "$chrome" s && ok "chromium stopped" || bad "chromium not stopped"
until_ok 4 group "$dev" s && ok "meiolol dev stopped" || bad "meiolol dev not stopped"
z=$(child "$mixed" zig) s=$(child "$mixed" ssh)
if until_ok 4 proc "$z" && ! proc "$s"; then ok "beside ssh: the zig alone stopped"
else bad "beside ssh: zig $(ps -o stat= -p "$z"), ssh $(ps -o stat= -p "$s")"; fi
group "$plain" r && ok "a plain loop runs on" || bad "a plain loop was stopped"
group "$run" s && ok "the lab run stays paused" || bad "lab run not paused"
grep -q " $run\$" "$t/meiolol-league-stopped" && bad "the lab run is in the stopped list" \
    || ok "the lab run is not in the stopped list"
states up up && ok "state files say up, game up" || bad "game: $(said)"
if slot_goes 3; then
    bad "slots went while the game is up"
else
    grep -q "League game up" "$t/slots.err" && ok "slots wait while the game is up, and say why" \
        || bad "slots: $(cat "$t/slots.err")"
fi
slots 1 touch "$t/ran" 2> /dev/null & waiter=$!
pids+=("$waiter")

rm "$t/game"
if until_ok 10 group "$build" r; then ok "game closed, client up: the zig build continues"
else bad "zig build after the game: $(members "$build" pid=,stat=)"; fi
for g in $chrome $dev $mixed; do
    until_ok 4 group "$g" r || bad "group $g still stopped after the game"
done
until_ok 10 test -f "$t/ran" && ok "the waiting slot went once the game closed" \
    || bad "the waiting slot never went"
[ -f "$t/meiolol-league-stopped" ] && bad "stopped list left after the game" \
    || ok "stopped list emptied"
states up down && group "$run" s && ok "client still up: the lab run stays paused" \
    || bad "client still up: $(said), run $(members "$run" stat=)"

rm "$t/client"
until_ok 10 group "$run" r && ok "client closed: the lab run continues" || bad "lab run still paused"

touch "$t/game"
until_ok 10 group "$build" s || bad "not stopped again"
kill -TERM "$watcher"
wait "$watcher" 2> /dev/null
group "$build" r && group "$chrome" r && group "$dev" r && ok "watcher stopped: everything continued" \
    || bad "watcher stopped: something stays stopped"
if [ -f "$t/meiolol-league" ] || [ -f "$t/meiolol-league-game" ]; then
    bad "state file left by a stopped watcher"
else
    ok "state files removed on stop"
fi
watch
until_ok 10 group "$build" s && ok "a new watcher stops it again" || bad "the new watcher didn't stop it"
kill -KILL "$watcher"
wait "$watcher" 2> /dev/null
rm "$t/game"
group "$build" s || bad "killed watcher: expected the group still stopped"
watch
if until_ok 10 group "$build" r && group "$chrome" r && group "$dev" r; then
    ok "watcher killed, then a new one with League down: everything continued"
else
    bad "after a killed watcher: something stays stopped"
fi
kill -TERM "$watcher"
wait "$watcher" 2> /dev/null

echo "--- watcher log"
cat "$t/watch.log"
[ $fails = 0 ] && echo "all ok" || echo "FAILED"
exit $fails
