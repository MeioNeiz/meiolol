#!/usr/bin/env bash
# Tests deploy/slots.sh and deploy/push.sh's modes in a scratch dir: slots run in
# parallel up to the limit, first come first served with small runs beside a waiting big
# one; push groups, bulk queues, flush leaves out a commit whose ci fails. A throwaway
# repo with a bare origin; its pre-push hook fails a commit whose tree has a line "bad".
# Run after changing either: deploy/flow-test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d)
trap 'pkill -f "$t/" 2> /dev/null; rm -rf "$t"' EXIT
fails=0
ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fails=1; }

export MEIOLOL_SLOTS_DIR=$t/slots MEIOLOL_SLOTS=2
s=$here/slots.sh
# Two weight-1 runs at once, a third waits; each logs its start and end second
# shellcheck disable=SC2016 # the inner bash expands them
run() { "$s" "$1" bash -c 'echo start $1 $(($(date +%s) - $2)) >> $3; sleep $4' _ "$2" "$t0" "$t/log" "$3"; }
t0=$(date +%s)
run 1 a 2 & sleep 0.3
run 1 b 2 & sleep 0.3
run 1 c 1 2> /dev/null &
wait
a=$(awk '$2 == "a" {print $3}' "$t/log")
b=$(awk '$2 == "b" {print $3}' "$t/log")
c=$(awk '$2 == "c" {print $3}' "$t/log")
[ "${b:-9}" -le $((a + 1)) ] && ok "two runs share the slots" || bad "b started at $b, a at $a"
[ "${c:-0}" -ge $((a + 2)) ] && ok "a third waits for a free slot" || bad "c started at ${c:-?}"
# A waiting weight-2 run is not overtaken by a weight-1 run that would delay it
: > "$t/log"
t0=$(date +%s)
run 1 a 2 & sleep 0.3
run 2 big 1 2> /dev/null & sleep 0.3
run 1 small 1 2> /dev/null &
wait
big=$(awk '$2 == "big" {print $3}' "$t/log")
small=$(awk '$2 == "small" {print $3}' "$t/log")
[ "${small:-0}" -ge "${big:-9}" ] && ok "first come first served for a bigger run" \
    || bad "small started at $small, before big at $big"
# A dead holder's slot is freed
mkdir -p "$t/slots/held"
: > "$t/slots/held/999999-2-000000001"
timeout 5 "$s" 2 true 2> /dev/null && ok "a dead holder's slots are freed" || bad "dead holder kept its slots"

# push.sh in a throwaway repo
# No toast: a real one says a batch commit failed
export MEIOLOL_PUSH_QUEUE=$t/q MEIOLOL_PUSH_LOCK=$t/push.lock MEIOLOL_NOTIFY=0
git init -q --bare "$t/origin.git"
git init -q -b main "$t/repo"
cd "$t/repo" || exit 1
mkdir -p deploy hooks
cp "$here/push.sh" "$here/slots.sh" deploy/
cat > hooks/pre-push << 'EOF'
#!/bin/sh
while read -r _ sha _ _; do
    git show "$sha:f" | grep -qx bad && exit 1
done
exit 0
EOF
chmod +x hooks/pre-push
git config core.hooksPath hooks
git config user.email t@t
git config user.name t
c() { echo "$1" >> f; git add f; git commit -qm "$1"; git rev-parse HEAD; }
c base > /dev/null
git remote add origin "$t/origin.git"
git push -q origin main 2> /dev/null
git fetch -q origin
p=deploy/push.sh
on_main() { git merge-base --is-ancestor "$1" origin/main; }

c1=$(c one)
$p "$c1" > /dev/null && on_main "$c1" && ok "fast: pushed" || bad "fast push"
$p --mode bulk 60 > /dev/null
c2=$(c two)
c3=$(c three)
$p "$c2" | grep -q queued && ! on_main "$c2" && ok "bulk: queued, not pushed" || bad "bulk did not queue"
$p "$c3" > /dev/null
c4=$(c bad)
$p "$c4" > /dev/null
c5=$(c five)
$p "$c5" > /dev/null
$p --status | grep -q 'queued: .* five' && ok "status lists the queue" || bad "status"
$p --flush > "$t/flush.log" 2>&1
on_main "$c3" && ! on_main "$c4" && ok "flush: up to the failing commit, without it" \
    || bad "flush: $(git log --oneline origin/main | head -1)"
$p --status | grep -q 'bad (ci failed)' && ok "the failed commit shows" || bad "failed not shown"
sed -i '' '/^bad$/d' f
c6=$(c fixed)
$p "$c6" > /dev/null
$p --mode fast > /dev/null 2>&1
on_main "$c6" && ok "fast: the queue goes out with the fix" || bad "fast flush"
[ -z "$($p --status | grep queued)" ] && ok "queue empty" || bad "queue left: $($p --status)"
pid=$(cat "$t/q/timer.pid" 2> /dev/null)
sleep 16
! kill -0 "$pid" 2> /dev/null && ok "timer stops in fast mode" || bad "timer still running"
# Fast mode: two waiting pushes go as one
git config core.hooksPath hooks
cat > hooks/pre-push << 'EOF'
#!/bin/sh
sleep 2
exit 0
EOF
c7=$(c seven)
$p "$c7" > "$t/p7" &
sleep 0.5
c8=$(c eight)
c9=$(c nine)
$p "$c8" > "$t/p8" &
$p "$c9" > "$t/p9" &
wait
# c7 alone, then c8 and c9 as one push
after=$(sed "1,/pushed $(git rev-parse --short "$c7")/d" "$t/q/log")
on_main "$c9" && [ "$(echo "$after" | grep -c pushed)" = 1 ] \
    && echo "$after" | grep -q "pushed $(git rev-parse --short "$c9")" \
    && ok "fast: queued pushes grouped" || bad "grouping: $(tail -n 3 "$t/q/log")"
[ $fails = 0 ] && echo "all pass"
exit $fails
