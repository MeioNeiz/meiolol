#!/usr/bin/env bash
# On the gpu-box: an analysis snapshot from what it holds (docs/data-safety.md "Analysis
# snapshots"), started by deploy/snapshot.sh make on the Mac, which copies this script
# and the binaries built from HEAD first. The real-id copy is put together from the
# backup mirror (`meiolol restore`) and what backups leave out, fetched from the box
# (backup-serve.sh snapshot-extra: players, ladder_pages, ranks, raw summaries, ...), in
# the box's own schema; then anonymised with the salt here, as on the Mac before, and
# deleted on any exit. The box sends ~3 GB instead of the ~23 GB VACUUM INTO.
#   snapshot-gpu.sh NAME     builds ~/ml/snaps/NAME (snap-STAMP)
# Needs ~/bin/sqlite3 and zstd (Ubuntu's packages unpacked there, no sudo), curl
set -euo pipefail
name=$1
[[ "$name" =~ ^snap-[0-9]{8}T[0-9]{4}Z$ ]] || { echo "NAME: snap-STAMP" >&2; exit 2; }
export PATH="$HOME/bin:$PATH"
bin=$HOME/ml/bin
mirror=${SNAP_MIRROR:-/mnt/wsl/archive/meiolol-backups}
salt=$HOME/.config/meiolol/snap-salt
snaps=$HOME/ml/snaps
box=${SNAP_BOX:-meiolol-backup}
DBS="meiolol timeline raw"
log() { echo "$(date -u +%FT%TZ) $*"; }
die() { log "$*"; exit 1; }
count() { sqlite3 "file:$1?mode=ro" "SELECT count(*) FROM \"$2\""; }
box_ssh() { ssh -n -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$box" "$@"; }
# The box's copy of the extra (real ids) goes on any exit too
cleanup() {
    rm -rf "$work"
    [[ -n "${SNAP_EXTRA:-}" ]] || box_ssh snapshot-done > /dev/null 2>&1 || true
}

mountpoint -q /mnt/wsl/lab || die "/mnt/wsl/lab not mounted"
[[ -f "$salt" ]] || die "no salt at $salt"
[[ -f "$mirror/.mirrored" ]] || die "no backup mirror at $mirror"
out=$snaps/$name
[[ -e "$out" ]] && die "$out exists"
# Real ids: owner only, gone on any exit
umask 077
work=$snaps/.$name-real
rm -rf "$work"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT
raw=$work/$name
restored=$work/restored
extra=$work/extra
mkdir -p "$raw" "$extra"

# The mirror's own lock (backup-mirror.sh): no scrub or rotation under the restore
mkdir "$mirror/.lock" 2> /dev/null || die "backup mirror busy: try again later"
trap 'cleanup; rmdir "$mirror/.lock" 2> /dev/null || true' EXIT
log "restore from $mirror (mirrored $(date -u -r "$mirror/.mirrored" +%FT%TZ))"
nice -n 10 "$bin/meiolol-snapshot" restore --from "$mirror" --data "$restored" > "$work/restore.log" 2>&1 \
    || { tail -n 5 "$work/restore.log"; die "restore failed"; }
rmdir "$mirror/.lock"
trap cleanup EXIT
day=$(sqlite3 "file:$restored/meiolol.db?mode=ro" "SELECT coalesce(max(day), 0) FROM rank_history")

log "box: what backups leave out (rank_history after day $day)"
# SNAP_EXTRA: a file of that stream fetched before (a rehearsal; its day may be older).
# Else the box builds it detached and it comes in pieces, each ssh retried: a long one
# from home dies now and then ("message authentication code incorrect")
if [[ -n "${SNAP_EXTRA:-}" ]]; then file=$SNAP_EXTRA
else
    box_ssh snapshot-extra "$day" > /dev/null || die "box: snapshot-extra failed"
    state=
    for _ in $(seq 240); do
        sleep 30
        state=$(box_ssh snapshot-state) || continue
        [[ "$state" == running* ]] || break
    done
    read -r what size sum _ <<< "$state"
    [[ "$what" == ready ]] || die "box: snapshot-extra $state"
    file=$work/extra.tar.zst
    : > "$file"
    for _ in $(seq 20); do
        have=$(stat -c %s "$file")
        (( have < size )) || break
        box_ssh snapshot-send "$have" >> "$file" || log "piece from $have cut short: again"
    done
    [[ "$(stat -c %s "$file")" == "$size" ]] || die "box: got $(stat -c %s "$file") of $size bytes"
    [[ "$(sha256sum < "$file" | cut -d' ' -f1)" == "$sum" ]] || die "box: sha256 differs"
    box_ssh snapshot-done || true
    log "box: $(( size >> 20 )) MB"
fi
zstd -dc -q "$file" | tar x -C "$extra"
[[ "$file" == "$work/extra.tar.zst" ]] && rm -f "$file"
for d in $DBS; do [[ -s "$extra/$d.sql" && -f "$extra/$d.db" ]] || die "box sent no $d"; done

# The box's schema; rows from the box's file where it sent them, else from the restore
# (by column name: a restored table's columns may be in another order). Indexes last
for d in $DBS; do
    # Statements span lines: split into tables and indexes by an empty database of them
    sqlite3 -bail "$work/$d.schema.db" < "$extra/$d.sql"
    ddl() { sqlite3 "$work/$d.schema.db" "SELECT sql || ';' FROM sqlite_schema WHERE type = '$1' AND sql IS NOT NULL"; }
    {
        echo "PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;"
        ddl table
        echo "ATTACH 'file:$extra/$d.db?mode=ro' AS x;"
        [[ -f "$restored/$d.db" ]] && echo "ATTACH 'file:$restored/$d.db?mode=ro' AS r;"
        echo "BEGIN;"
        while IFS=$'\t' read -r db t n; do
            [[ "$db" == "$d" ]] || continue
            sent=$(count "$extra/$d.db" "$t")
            if (( sent > 0 )) || [[ ! -f "$restored/$d.db" ]] \
                || [[ -z "$(sqlite3 "file:$restored/$d.db?mode=ro" \
                    "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = '$t'")" ]]; then
                echo "INSERT INTO main.\"$t\" SELECT * FROM x.\"$t\";"
            fi
            if (( sent < n )) && [[ -f "$restored/$d.db" ]] && [[ -n "$(sqlite3 "file:$restored/$d.db?mode=ro" \
                "SELECT 1 FROM sqlite_schema WHERE type = 'table' AND name = '$t'")" ]]; then
                cols=$(sqlite3 "file:$extra/$d.db?mode=ro" \
                    "SELECT group_concat('\"' || name || '\"', ', ') FROM pragma_table_info('$t')")
                echo "INSERT OR IGNORE INTO main.\"$t\" ($cols) SELECT $cols FROM r.\"$t\";"
            fi
        done < "$extra/counts.tsv"
        if [[ "$d" == meiolol ]]; then
            echo "UPDATE main.participants SET tier = l.tier, division = l.division, gold10 = l.gold10,
                gold14 = l.gold14, gold15 = l.gold15, puuid = CASE WHEN l.no_puuid THEN NULL ELSE puuid END
                FROM x.participants_late l
                WHERE l.match_id = participants.match_id AND l.slot = participants.slot;"
        fi
        echo "COMMIT;"
        ddl index
    } > "$work/$d.load.sql"
    nice -n 10 sqlite3 -bail "$raw/$d.db" < "$work/$d.load.sql"
done
rm -rf "$restored"

# Against the box: tables it sent hold what it counted; restored ones what the mirror
# had, at most what the box has now plus a day of crawling (a newer box, or forgotten
# players gone since). Every box table is there
while IFS=$'\t' read -r d t n; do
    sent=$(count "$extra/$d.db" "$t")
    have=$(count "$raw/$d.db" "$t")
    if [[ "$d $t" == "raw timeline_docs" ]]; then continue
    elif (( sent == n )); then (( have == n )) || die "$d.$t: $have rows, box $n"
    else (( have > 0 || n == 0 )) || die "$d.$t: empty, box $n"
    fi
    log "$d.$t: $have (box $n)"
done < "$extra/counts.tsv"
rm -rf "$extra"
for d in $DBS; do
    [[ "$(sqlite3 "file:$raw/$d.db?mode=ro" 'PRAGMA quick_check')" == ok ]] || die "$d.db: quick_check failed"
done

log "anonymising"
nice -n 10 "$bin/meiolol-lab-snapshot" anonymise "$raw" "$out"
# The checks deploy/snapshot.sh ran on the Mac
fail() { rm -rf "$out"; die "check: $*"; }
[[ "$(count "$out/meiolol.db" anon_meta)" == 1 ]] || fail "no anon_meta"
for d in $DBS; do
    for t in $(sqlite3 "file:$raw/$d.db?mode=ro" "SELECT name FROM sqlite_master WHERE type = 'table'
        AND name NOT LIKE 'sqlite_%' AND name NOT IN ('forgotten', 'timeline_docs')"); do
        a=$(count "$raw/$d.db" "$t")
        b=$(count "$out/$d.db" "$t")
        if [[ "$d $t" == "meiolol ranks" || "$d $t" == "meiolol rank_history" ]]; then
            (( b > 0 && b <= a )) || fail "$d.$t has $b rows, source $a"
        else
            [[ "$a" == "$b" ]] || fail "$d.$t has $b rows, source $a"
        fi
    done
done
for t in participants players mastery; do
    a=$(sqlite3 "file:$out/meiolol.db?mode=ro" "SELECT count(*) FROM $t WHERE length(puuid) != 16")
    [[ "$a" == 0 ]] || fail "$a unhashed PUUIDs in $t"
done
id=$(sqlite3 "file:$raw/meiolol.db?mode=ro" "SELECT match_id FROM matches LIMIT 1")
a=$(sqlite3 "file:$out/meiolol.db?mode=ro" "SELECT count(*) FROM participants WHERE match_id = '$id'")
[[ "$a" == 0 ]] || fail "real match id $id in participants"
rm -rf "$work"
log "checks passed"

log "split, legendaries, seat and comp stats, pack, mastery-pre"
nice -n 10 "$bin/meiolol-lab-snapshot" split "$out" > /dev/null
nice -n 10 "$bin/meiolol-snapshot" legendaries --data "$out" --platform all
versions=$(curl -sf https://ddragon.leagueoflegends.com/api/versions.json) || die "Data Dragon versions.json unreachable"
# Not ?mode=ro: a read-only open fails (14) while the WAL has no -shm yet
patches=$(sqlite3 "$out/meiolol.db" "SELECT DISTINCT patch FROM matches WHERE queue_id = 420")
[[ -n "$patches" ]] || die "$out/meiolol.db: no queue 420 patches"
for patch in $patches; do
    v=$(grep -o "\"${patch//./\\.}\.[0-9]*\"" <<< "$versions" | head -n 1 | tr -d '"')
    [[ -n "$v" ]] || { log "no Data Dragon version for $patch"; continue; }
    mkdir -p "$out/ddragon/$patch"
    for f in champion item; do
        curl -sfo "$out/ddragon/$patch/$f.json" "https://ddragon.leagueoflegends.com/cdn/$v/data/en_US/$f.json" \
            || die "Data Dragon $v $f.json"
    done
done
# Summaries leave the box's raw.db for the archive after ~2 days: read both
arch=/mnt/wsl/archive/meiolol-raw
if [[ -d "$out/ddragon" ]]; then
    nice -n 10 "$bin/meiolol-lab-snapshot" seat-stats "$out" "$out/ddragon" "$arch"
    nice -n 10 "$bin/meiolol-lab-snapshot" comp-stats "$out" "$out/ddragon" "$arch"
else
    nice -n 10 "$bin/meiolol-lab-snapshot" seat-stats "$out"
fi
nice -n 10 "$bin/meiolol-lab-snapshot" pack "$out"
nice -n 10 "$bin/meiolol-lab-snapshot" mastery-pre "$out" "$arch"
chmod -R go+rX "$out"
log "made $name ($(du -sh "$out" | cut -f1))"
