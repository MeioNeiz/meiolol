#!/usr/bin/env bash
# A small copy of a dev snapshot (deploy/box.sh snapshot) for page checks: every Nth game
# (default 20, by rowid, so every patch and day keeps its share) with its participants and
# bans, those players' mastery, every Nth draft, the small tables whole. The dev server
# loads it in ~100 s (Debug; data/snap ~22 min). Memory hardly shrinks: ~1.3 GB private,
# 640 MB of it the export builds files, which every view reads whatever the games
# Files beside the databases are copied (the site writes Daily Draft files and icons
# there), but export, the curves and builds (~1 GB, mapped read-only), is symlinked.
#   deploy/snap-small.sh SRC DST [N]   builds DST unless it is newer than SRC/meiolol.db
# deploy/dev.sh --small runs it
set -euo pipefail
src=${1:?usage: snap-small.sh SRC DST [N]}
dst=${2:?usage: snap-small.sh SRC DST [N]}
n=${3:-20}
src=$(cd "$src" && pwd)
[[ -f "$src/meiolol.db" ]] || { echo "no $src/meiolol.db" >&2; exit 1; }
[[ "$dst/meiolol.db" -nt "$src/meiolol.db" ]] && exit 0
# Two lanes starting at once: one builds, the other waits for it
lock=$dst.lock
until mkdir "$lock" 2> /dev/null; do
    pid=$(cat "$lock/pid" 2> /dev/null || true)
    [[ -n "$pid" ]] && ! kill -0 "$pid" 2> /dev/null && rm -rf "$lock"
    sleep 2
done
trap 'rm -rf "$lock"' EXIT
echo $$ > "$lock/pid"
[[ "$dst/meiolol.db" -nt "$src/meiolol.db" ]] && exit 0
tmp=$dst.tmp
rm -rf "$tmp"
mkdir -p "$tmp"
echo "snap-small: 1 in $n games of $src into $dst" >&2
start=$SECONDS
sqlite3 -readonly "$src/meiolol.db" \
    "SELECT sql || ';' FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'" |
    sqlite3 "$tmp/meiolol.db"
nice sqlite3 "$tmp/meiolol.db" > /dev/null << SQL
ATTACH 'file:$src/meiolol.db?mode=ro' AS s;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
BEGIN;
INSERT INTO matches SELECT * FROM s.matches WHERE rowid % $n = 0;
INSERT INTO participants SELECT p.* FROM matches m CROSS JOIN s.participants p USING (match_id);
INSERT INTO bans SELECT b.* FROM matches m CROSS JOIN s.bans b USING (match_id);
INSERT INTO mastery SELECT * FROM s.mastery
    WHERE puuid IN (SELECT puuid FROM participants WHERE puuid IS NOT NULL);
INSERT INTO drafts SELECT * FROM s.drafts WHERE id % $n = 0;
INSERT INTO champions SELECT * FROM s.champions;
INSERT INTO players SELECT * FROM s.players;
INSERT INTO ladder_pages SELECT * FROM s.ladder_pages;
INSERT INTO forgotten SELECT * FROM s.forgotten;
INSERT INTO ranks SELECT * FROM s.ranks;
INSERT INTO rank_history SELECT * FROM s.rank_history;
COMMIT;
PRAGMA user_version = $(sqlite3 -readonly "$src/meiolol.db" 'PRAGMA user_version');
SQL
sqlite3 -readonly "$src/meiolol.db" \
    "SELECT sql || ';' FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL" |
    sqlite3 "$tmp/meiolol.db"
sqlite3 "$tmp/meiolol.db" 'PRAGMA journal_mode=WAL' > /dev/null
for db in raw timeline; do
    sqlite3 -readonly "$src/$db.db" '.schema --nosys' | sqlite3 "$tmp/$db.db"
done
for f in "$src"/*; do
    case ${f##*/} in
        *.db | *.db-* | site) ;;
        export) ln -s "$f" "$tmp/" ;;
        *) cp -Rp "$f" "$tmp/" ;;
    esac
done
rm -rf "$dst"
mv "$tmp" "$dst"
echo "snap-small: $(du -sh "$dst/meiolol.db" | cut -f1) in $((SECONDS - start)) s:" \
    "$(sqlite3 -readonly "$dst/meiolol.db" 'SELECT count(*) FROM matches') games" >&2
