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
# A dead holder's slot is freed
mkdir -p "$t/slots/held"
: > "$t/slots/held/999999-2-000000001"
timeout 5 "$s" 2 true 2> /dev/null && ok "a dead holder's slots are freed" || bad "dead holder kept its slots"

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
touch "$small/daily/mark" "$small/dev-notes.db"
"$here/snap-small.sh" "$big" "$small" 2 2> /dev/null
[ -f "$small/daily/mark" ] && ok "snap-small: kept while built from this source" \
    || bad "snap-small rebuilt"
# A new snapshot carrying an older mtime (rsync keeps the box's)
cp -p "$big/meiolol.db" "$t/new.db"
touch -t 200001010000 "$t/new.db"
mv "$t/new.db" "$big/meiolol.db"
"$here/snap-small.sh" "$big" "$small" 2 2> /dev/null
! [ -f "$small/daily/mark" ] && [ -f "$small/dev-notes.db" ] && [ -f "$small/.source" ] \
    && ! [ -e "$small.tmp" ] && ! [ -e "$small.old" ] \
    && ok "snap-small: rebuilt for a new source, notes kept" || bad "snap-small stale"
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
[ $fails = 0 ] && echo "all pass"
exit $fails
