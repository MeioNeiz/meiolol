#!/usr/bin/env bash
# A small copy of a dev snapshot (deploy/box.sh snapshot) for page checks: every Nth game
# (default 20, by rowid, so every patch and day keeps its share) with its participants and
# bans, those players' mastery, every Nth draft, the small tables whole. The dev server
# loads it in ~100 s (Debug; data/snap ~22 min). Memory hardly shrinks: ~1.3 GB private,
# 640 MB of it the export builds files, which every view reads whatever the games
# Files beside the databases are copied (the site writes Daily Draft files and icons
# there), but export, the curves and builds (~1 GB, mapped read-only), is symlinked.
#   deploy/snap-small.sh SRC DST [N]   builds DST unless built from this SRC/meiolol.db
# DST (named *-small) is replaced whole, so it may not be SRC, inside it, around it, or
# around data/. Built beside it and swapped in: small servers running on the old copy
# keep its database; dev-notes.db moves over. deploy/dev.sh --small runs it
set -euo pipefail
usage='usage: snap-small.sh SRC DST [N]'
src=${1:?$usage}
dst=${2:?$usage}
n=${3:-20}
[[ -f "$src/meiolol.db" ]] || { echo "no $src/meiolol.db" >&2; exit 1; }
refuse() { echo "snap-small: refusing DST $dst: $1" >&2; exit 2; }
[[ -L "$dst" ]] && refuse "a symlink"
src=$(cd "$src" && pwd -P)
mkdir -p "$(dirname "$dst")"
if [[ -d "$dst" ]]; then
    dst=$(cd "$dst" && pwd -P)
else
    dst=$(cd "$(dirname "$dst")" && pwd -P)/$(basename "$dst")
fi
[[ $dst == *-small ]] || refuse "its name must end in -small"
# within A B: A is B or inside it (physical paths)
within() { [[ $1/ == "$2"/* ]]; }
within "$dst" "$src" && refuse "it is $src or inside it"
for d in "$dst" "$dst.tmp" "$dst.old" "$dst.lock"; do
    within "$src" "$d" && refuse "$d holds $src"
done
# This checkout's data/ and, from a worktree, the main checkout's
roots=("$(cd "$(dirname "$0")/.." && pwd -P)")
if gitdir=$(cd "${roots[0]}" && git rev-parse --git-common-dir 2> /dev/null); then
    roots+=("$(cd "${roots[0]}" && cd "$gitdir/.." && pwd -P)")
fi
for r in "${roots[@]}"; do
    [[ -d "$r/data" ]] || continue
    d=$(cd "$r/data" && pwd -P)
    within "$d" "$dst" && refuse "it holds $d"
done
# Which source DST was built from, written last: a snapshot rsync keeps the box's mtime,
# so a newer-than test would miss one that landed after DST was built
ident() { stat -c '%i %s %Y' "$1" 2> /dev/null || stat -f '%i %z %m' "$1"; }
want="$src $(ident "$src/meiolol.db") 1/$n"
fresh() { [[ -f "$dst/meiolol.db" && "$(cat "$dst/.source" 2> /dev/null)" == "$want" ]]; }
# Built before .source existed, when newer than the source meant built from it
if [[ -f "$dst/meiolol.db" && ! -e "$dst/.source" ]] &&
    [[ "$dst/meiolol.db" -nt "$src/meiolol.db" ]]; then
    echo "$want" > "$dst/.source"
fi
fresh && exit 0
sampled='matches participants bans mastery drafts'
whole='champions players ladder_pages forgotten ranks rank_history'
# Created empty: the crawler's queues and backfill state
skipped='match_queue timeline_queue draft_backfill'
tables="SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
for t in $(sqlite3 -readonly "$src/meiolol.db" "$tables"); do
    case " $sampled $whole $skipped " in
        *" $t "*) ;;
        *) echo "snap-small: table $t is new: add it to sampled, whole or skipped" >&2
            exit 1 ;;
    esac
done
# Two lanes starting at once: one builds, the other waits for it
lock=$dst.lock
until mkdir "$lock" 2> /dev/null; do
    pid=$(cat "$lock/pid" 2> /dev/null || true)
    [[ -n "$pid" ]] && ! kill -0 "$pid" 2> /dev/null && rm -rf "$lock"
    [[ -n "${said:-}" ]] || echo "snap-small: waiting for pid ${pid:-?}'s build" >&2
    said=1
    sleep 2
done
trap 'rm -rf "$lock"' EXIT
echo $$ > "$lock/pid"
fresh && exit 0
tmp=$dst.tmp old=$dst.old
rm -rf "$tmp" "$old"
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
$(for t in $whole; do echo "INSERT INTO $t SELECT * FROM s.$t;"; done)
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
echo "$want" > "$tmp/.source"
# A rename keeps a running server's open notes database with it
for f in "$dst"/dev-notes.db*; do
    if [[ -e "$f" ]]; then mv "$f" "$tmp/"; fi
done
if [[ -e "$dst" ]]; then mv "$dst" "$old"; fi
mv "$tmp" "$dst"
# Something made $dst again between the two renames: tmp went inside it
if ! [[ -f "$dst/.source" ]]; then
    echo "snap-small: $dst was recreated meanwhile; remove it and run again" >&2
    exit 1
fi
rm -rf "$old"
echo "snap-small: $(du -sh "$dst/meiolol.db" | cut -f1) in $((SECONDS - start)) s:" \
    "$(sqlite3 -readonly "$dst/meiolol.db" 'SELECT count(*) FROM matches') games" >&2
