#!/usr/bin/env bash
# Tests deploy/slots.sh and deploy/push.sh's modes in a scratch dir: slots run in
# parallel up to the limit, first come first served with small runs beside a waiting big
# one; push groups, bulk queues, flush leaves out a commit whose ci fails. A throwaway
# repo with a bare origin; its pre-push hook fails a commit whose tree has a line "bad".
# And snap-small.sh on a toy database. Run after changing one: deploy/flow-test.sh
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
# Of 3 slots, ci takes 2 and leaves one for a short run beside it
: > "$t/log"
t0=$(date +%s)
MEIOLOL_SLOTS=3 run ci ci 2 & sleep 0.3
MEIOLOL_SLOTS=3 run 1 short 1 2> /dev/null &
wait
ci=$(awk '$2 == "ci" {print $3}' "$t/log")
short=$(awk '$2 == "short" {print $3}' "$t/log")
[ -n "$ci" ] && [ "${short:-9}" -le $((ci + 1)) ] && ok "ci leaves a slot free" \
    || bad "short started at ${short:-?}, ci at ${ci:-?}"
# A dead holder's slot is freed
mkdir -p "$t/slots/held"
: > "$t/slots/held/999999-2-000000001"
timeout 5 "$s" 2 true 2> /dev/null && ok "a dead holder's slots are freed" || bad "dead holder kept its slots"
# Every request leaves a line: 9 runs above, then a failing one; history sums by kind
h=$t/slots/history.tsv
"$s" 1 bash -c 'exit 3'
[ "$(awk -F'\t' 'NF == 9 && $6 != "-" && $6 >= $5 && $7 >= $6 {n++} END {print n}' "$h")" = 10 ] \
    && [ "$(tail -n 1 "$h" | cut -f3,4,8)" = "$(printf 'bash\t1\t3')" ] \
    && ok "history: a line per request" || bad "history: $(cat "$h")"
awk -F'\t' '$9 ~ / c / && $6 - $5 >= 1' "$h" | grep -q . && ok "history: the wait" \
    || bad "history: no wait for c"
"$s" history 1 | grep -Eq '^bash +9 +0 .* 1$' && ok "history: summed by kind" \
    || bad "history summary: $("$s" history 1)"
# zb.sh logs its zig build step as the kind
mkdir -p "$t/zb/deploy" "$t/zb/bin"
cp "$here/zb.sh" "$here/slots.sh" "$t/zb/deploy/"
printf '#!/bin/sh\nexit 0\n' > "$t/zb/bin/zig"
chmod +x "$t/zb/bin/zig"
HOME=$t/zb PATH=$t/zb/bin:$PATH "$t/zb/deploy/zb.sh" test -Dtest-filter=x > /dev/null 2>&1
[ "$(tail -n 1 "$h" | cut -f3,8,9)" = "$(printf 'test~f\t0\tzb.sh test -Dtest-filter=x')" ] \
    && ok "history: zb.sh's step" || bad "history zb: $(tail -n 1 "$h")"

# zig-cache-prune.sh: the shared cache, and each tree's own unless its tree is locked
pr=$t/pr
git init -q "$pr"
for c in "$pr/.zig-cache" "$pr/.git/meiolol-build/ci.cache" "$pr/.git/meiolol-build/box.cache"; do
    mkdir -p "$c/o/1" "$c/h"
    echo x > "$c/o/1/f"
    echo log > "$c/keep.log"
done
mkdir "$pr/.git/meiolol-build/box.lock"
echo $$ > "$pr/.git/meiolol-build/box.lock/pid"
MEIOLOL_ROOT=$pr "$here/zig-cache-prune.sh" 0 0 > "$t/prune.log"
! [ -e "$pr/.zig-cache/o" ] && ! [ -e "$pr/.git/meiolol-build/ci.cache/o" ] \
    && [ -f "$pr/.git/meiolol-build/ci.cache/keep.log" ] && ! [ -e "$pr/.git/meiolol-build/ci.lock" ] \
    && ok "prune: the shared cache and a free tree's" || bad "prune: $(cat "$t/prune.log")"
[ -f "$pr/.git/meiolol-build/box.cache/o/1/f" ] && [ -d "$pr/.git/meiolol-build/box.lock" ] \
    && grep -q 'box tree .* in use' "$t/prune.log" && ok "prune: a locked tree's kept" \
    || bad "prune took a locked tree's cache: $(cat "$t/prune.log")"

# snap-small.sh: 1 in 2 games with their rows, the small tables whole, side files copied
# but export linked; not built again while newer than the source
big=$t/snap small=$t/snap-small
mkdir -p "$big/export" "$big/daily"
echo d > "$big/daily/1.json"
sqlite3 "$big/meiolol.db" << 'EOF'
CREATE TABLE matches (match_id TEXT PRIMARY KEY, patch TEXT);
CREATE INDEX matches_patch ON matches (patch);
CREATE TABLE participants (match_id TEXT, slot INTEGER, puuid TEXT,
    PRIMARY KEY (match_id, slot)) WITHOUT ROWID;
CREATE TABLE bans (match_id TEXT, team_id INTEGER,
    PRIMARY KEY (match_id, team_id)) WITHOUT ROWID;
CREATE TABLE mastery (puuid TEXT PRIMARY KEY, data BLOB);
CREATE TABLE drafts (id INTEGER PRIMARY KEY);
CREATE TABLE champions (id INTEGER PRIMARY KEY);
CREATE TABLE players (puuid TEXT PRIMARY KEY);
CREATE TABLE ladder_pages (page INTEGER PRIMARY KEY);
CREATE TABLE forgotten (puuid TEXT PRIMARY KEY);
CREATE TABLE ranks (key INTEGER PRIMARY KEY);
CREATE TABLE rank_history (key INTEGER, day INTEGER, PRIMARY KEY (key, day));
CREATE TABLE match_queue (match_id TEXT PRIMARY KEY);
INSERT INTO matches VALUES ('m1', '16.21'), ('m2', '16.21'), ('m3', '16.21'), ('m4', '16.20');
INSERT INTO participants
    SELECT match_id, s.value, match_id || 'p' || s.value FROM matches, json_each('[0,1]') s;
INSERT INTO bans SELECT match_id, 100 FROM matches;
INSERT INTO mastery SELECT puuid, x'00' FROM participants;
INSERT INTO mastery VALUES ('nobody', x'00');
INSERT INTO drafts VALUES (1), (2), (3), (4);
INSERT INTO champions VALUES (1), (2);
INSERT INTO players VALUES ('m1p0'), ('nobody');
INSERT INTO match_queue VALUES ('q1');
PRAGMA user_version = 7;
EOF
for db in raw timeline; do sqlite3 "$big/$db.db" 'CREATE TABLE d (x)'; done
"$here/snap-small.sh" "$big" "$small" 2 2> /dev/null
q() { sqlite3 "$small/meiolol.db" "$1"; }
[ "$(q 'SELECT group_concat(match_id) FROM matches')" = m2,m4 ] \
    && [ "$(q 'SELECT count(*) FROM participants')" = 4 ] \
    && [ "$(q 'SELECT group_concat(puuid) FROM (SELECT puuid FROM mastery ORDER BY puuid)')" \
        = m2p0,m2p1,m4p0,m4p1 ] \
    && [ "$(q 'SELECT count(*) FROM bans') $(q 'SELECT count(*) FROM drafts')" = "2 2" ] \
    && [ "$(q 'SELECT count(*) FROM players') $(q 'SELECT count(*) FROM champions')" = "2 2" ] \
    && [ "$(q 'SELECT count(*) FROM match_queue') $(q 'PRAGMA user_version')" = "0 7" ] \
    && [ "$(q "SELECT count(*) FROM sqlite_master WHERE name = 'matches_patch'")" = 1 ] \
    && ok "snap-small: sampled games and their rows" || bad "snap-small rows"
[ -L "$small/export" ] && [ -f "$small/daily/1.json" ] && ! [ -L "$small/daily" ] \
    && [ -f "$small/raw.db" ] && ok "snap-small: side files" || bad "snap-small side files"
touch "$small/daily/mark" "$small/dev-meionotes.db"
"$here/snap-small.sh" "$big" "$small" 2 2> /dev/null
[ -f "$small/daily/mark" ] && ok "snap-small: kept while built from this source" \
    || bad "snap-small rebuilt"
# A new snapshot carrying an older mtime (rsync keeps the box's)
cp -p "$big/meiolol.db" "$t/new.db"
touch -t 200001010000 "$t/new.db"
mv "$t/new.db" "$big/meiolol.db"
"$here/snap-small.sh" "$big" "$small" 2 2> /dev/null
! [ -f "$small/daily/mark" ] && [ -f "$small/dev-meionotes.db" ] && [ -f "$small/.source" ] \
    && ! [ -e "$small.tmp" ] && ! [ -e "$small.old" ] \
    && ok "snap-small: rebuilt for a new source, meionotes kept" || bad "snap-small stale"
sqlite3 "$big/meiolol.db" 'CREATE TABLE newtab (x)'
"$here/snap-small.sh" "$big" "$small" 2 2>&1 | grep -q 'table newtab is new' \
    && ok "snap-small: an unknown table fails" || bad "snap-small took an unknown table"
sqlite3 "$big/meiolol.db" 'DROP TABLE newtab'
# Never DST over SRC or data/, physical paths: each must refuse and leave SRC whole
ln -s "$t" "$t/up"
mkdir -p "$t/repo-small/deploy" "$t/repo-small/data"
cp "$here/snap-small.sh" "$t/repo-small/deploy/"
ln -s "$big" "$t/link-small"
mkdir "$t/outer-small"
cp -Rp "$big" "$t/outer-small/"
refused=0
for pair in "$small $small" "$small $small/" "$big $big/x-small" \
    "$t/up/snap $big/x-small" "$t/outer-small/snap $t/outer-small" "$big $t/link-small" \
    "$big $t"; do
    # shellcheck disable=SC2086 # two words
    "$here/snap-small.sh" $pair 2 2> /dev/null && echo "built: $pair"
    [ $? = 2 ] && refused=$((refused + 1))
done
"$t/repo-small/deploy/snap-small.sh" "$big" "$t/repo-small" 2 2> /dev/null
[ $? = 2 ] && refused=$((refused + 1))
[ $refused = 8 ] && [ -f "$big/meiolol.db" ] && [ -f "$small/meiolol.db" ] \
    && [ -f "$t/outer-small/snap/meiolol.db" ] && [ -d "$t/repo-small/data" ] \
    && ! [ -e "$big/x-small" ] && ok "snap-small: DST over SRC or data/ refused" \
    || bad "snap-small DST guard: $refused of 8 refused"

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
grep -vx bad f > f.new; mv f.new f
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
# A failing batch of 8, the 5th bad: halving tries the 8th, 4th, 6th and 5th (4 cis, not
# 5), pushes the first 4 and leaves out the bad one and those after it
cat > hooks/pre-push << EOF
#!/bin/sh
echo run >> "$t/runs"
while read -r _ sha _ _; do
    git show "\$sha:f" | grep -qx bad && exit 1
done
exit 0
EOF
$p --mode bulk 60 > /dev/null
batch=()
for x in b1 b2 b3 b4 bad b6 b7 b8; do
    batch+=("$(c "$x")")
    $p "${batch[${#batch[@]} - 1]}" > /dev/null
done
$p --flush > "$t/flush2.log" 2>&1
[ "$(wc -l < "$t/runs" | tr -d ' ')" = 4 ] && on_main "${batch[3]}" && ! on_main "${batch[4]}" \
    && ok "flush: a failing batch halved" || bad "halving: $(cat "$t/flush2.log")"
[ "$($p --status | grep -c '(ci failed)')" = 4 ] && grep -q 'first queued commit whose ci fails' "$t/flush2.log" \
    && ok "flush: the first failing commit named, newer ones left out" \
    || bad "halving left: $($p --status)"
# GitHub or the network refusing is no ci verdict: retried once (without the hook after a
# "[remote rejected]", which comes only once it passed), then kept queued, never halved
export MEIOLOL_PUSH_RETRY_S=0
grep -vx bad f > f.new; mv f.new f
cat > hooks/pre-push << EOF
#!/bin/sh
echo run >> "$t/runs2"
while read -r _ sha _ _; do
    case \$(git log -1 --format=%s "\$sha") in
        flaky) echo ' ! [remote rejected] x -> main (fatal error in commit_refs_rules)' >&2; exit 1 ;;
        offline) echo 'fatal: unable to access https://x/: Could not resolve host: x' >&2; exit 1 ;;
    esac
done
exit 0
EOF
: > "$t/runs2"
cf=$(c flaky)
$p "$cf" > /dev/null
$p --flush > "$t/flush3.log" 2>&1
on_main "$cf" && [ ! -f "$t/q/failed/$cf" ] && [ "$(wc -l < "$t/runs2" | tr -d ' ')" = 1 ] \
    && ok "push: a remote rejection retried without ci, pushed" || bad "remote rejected: $(cat "$t/flush3.log")"
: > "$t/runs2"
cg=$(c fine)
co=$(c offline)
$p "$cg" > /dev/null
$p "$co" > /dev/null
$p --flush > "$t/flush4.log" 2>&1
! on_main "$cg" && [ ! -f "$t/q/failed/$co" ] && [ ! -f "$t/q/failed/$cg" ] \
    && [ "$(wc -l < "$t/runs2" | tr -d ' ')" = 2 ] && grep -q "remote refused $(git rev-parse --short "$co")" "$t/q/log" \
    && $p --status | grep -q 'queued: .* offline$' \
    && ok "push: the network down twice: kept queued, not failed, not halved" \
    || bad "network: runs $(wc -l < "$t/runs2"), $(cat "$t/flush4.log")"

# ci-run.sh: the box's verdict stands, 75 (not built there) falls back to the Mac's ci,
# off and MEIOLOL_CI_HOST=mac skip the box; ci-mac's failure fails. Stub builds log a name
cp "$here/ci-run.sh" "$here/lib.sh" "$here/remote-build.sh" "$here/place.sh" "$here/box-ci-job.sh" deploy/
for b in box mac maconly; do
    printf '#!/bin/sh\necho %s >> "%s"\nexit "${%s_RC:-0}"\n' "$b" "$t/ci" "$(echo $b | tr a-z A-Z)" > "$t/$b"
    chmod +x "$t/$b"
done
export MEIOLOL_CI_OFF=$t/ci-off MEIOLOL_CI_MAC=$t/mac MEIOLOL_CI_MACONLY=$t/maconly
cirun() {
    : > "$t/ci"
    MEIOLOL_CI_BOX=$t/box deploy/ci-run.sh HEAD > /dev/null 2>&1
    echo "$? $(sort "$t/ci" | tr '\n' ' ')"
}
[ "$(cirun)" = "0 box maconly " ] && ok "ci-run: box and ci-mac pass" || bad "ci-run pass: $(cirun)"
[ "$(BOX_RC=1 cirun)" = "1 box maconly " ] && ok "ci-run: a box failure fails, no Mac retry" \
    || bad "ci-run box fail: $(BOX_RC=1 cirun)"
[ "$(BOX_RC=75 cirun)" = "0 box mac maconly " ] && ok "ci-run: 75 falls back to the Mac" \
    || bad "ci-run 75: $(BOX_RC=75 cirun)"
[ "$(BOX_RC=75 MAC_RC=1 cirun)" = "1 box mac maconly " ] && ok "ci-run: the fallback's failure fails" \
    || bad "ci-run 75 then fail: $(BOX_RC=75 MAC_RC=1 cirun)"
[ "$(MACONLY_RC=1 cirun)" = "1 box maconly " ] && ok "ci-run: ci-mac's failure fails" \
    || bad "ci-run ci-mac fail: $(MACONLY_RC=1 cirun)"
[ "$(MEIOLOL_CI_HOST=mac cirun)" = "0 mac " ] && ok "ci-run: MEIOLOL_CI_HOST=mac" \
    || bad "ci-run host mac: $(MEIOLOL_CI_HOST=mac cirun)"
deploy/ci-run.sh off > /dev/null
[ "$(cirun)" = "0 mac " ] && deploy/ci-run.sh status | grep -q off && ok "ci-run: off, the Mac's ci" \
    || bad "ci-run off: $(cirun)"
deploy/ci-run.sh on > /dev/null
# The real remote-build.sh to a host that doesn't resolve: 75, then the Mac
: > "$t/ci"
BOX_HOST=nohost.invalid deploy/ci-run.sh HEAD > "$t/ci.log" 2>&1
r=$?
[ $r = 0 ] && [ "$(sort "$t/ci" | tr '\n' ' ')" = "mac maconly " ] && grep -q "didn't build it" "$t/ci.log" \
    && ok "ci-run: box unreachable, the Mac's ci" || bad "ci-run unreachable: $r $(cat "$t/ci.log")"
[ $fails = 0 ] && echo "all pass"
exit $fails
