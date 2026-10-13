#!/usr/bin/env bash
# Analysis snapshot end to end, run on the Mac (it holds the salt; docs/data-safety.md
# "Analysis snapshots", docs/model.md "Shared protocol"): box VACUUM INTO, streamed here,
# checked, anonymised, checked again, split, legendaries, seat stats and pack, then to
# the gpu-box.
# The real-id copies (box and here) are deleted on every exit, success or not.
#
#   deploy/snapshot.sh make            new data/snap-STAMP here, then push
#   deploy/snapshot.sh push NAME       to ~/ml/snaps on the gpu-box, then mastery-pre there
#   deploy/snapshot.sh tick            hourly (launchd): push what waits, make when due
#   deploy/snapshot.sh prune KEEP      delete every other snap-* here and on the gpu-box
#   deploy/snapshot.sh schedule install|uninstall   the hourly tick
#
# Due: Sundays from 04:00, or any day once the newest is 8 days old; a failed make waits
# 6 h before the next try. The gpu-box often sleeps at night: a snapshot it can't take
# waits in ~/.cache/meiolol-snapshot/pending for a tick that finds it awake
#
# Builds from committed HEAD in a temp tree (other sessions edit the shared checkout).
# The lab agent's snapshot is LAB_SNAP in deploy/lab-exp.sh: move it to the new one
# before prune. Env: SNAP_BOX (meiolol-cloud), SNAP_GPU (gpu-box)
set -euo pipefail
# launchd's login bash finds Homebrew's zig (0.16) first and no wz: the pinned 0.17 and
# wz live in ~/.local/bin
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BOX=${SNAP_BOX:-meiolol-cloud}
GPU=${SNAP_GPU:-gpu-box}
DBS="meiolol timeline raw"
STATE=$HOME/.cache/meiolol-snapshot
BIN=$ROOT/zig-out/snapshot
ARCHIVE=/mnt/wsl/archive/meiolol-raw

# Keepalives: VACUUM INTO prints nothing for minutes, and an idle session was dropped
box() { ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=6 "$BOX" "$@"; }
log() { echo "$(date -u +%FT%TZ) $*"; }
# A toast too: weekly runs have no one watching (wz is the Mac's notifier)
die() {
    log "$*"
    command -v wz > /dev/null && wz notify --for 60 meiolol "snapshot failed: $*"
    exit 1
}
count() { sqlite3 "file:$1?mode=ro" "SELECT count(*) FROM $2"; }

make_snap() {
    local stamp name raw out bin tree
    stamp=$(date -u +%Y%m%dT%H%MZ)
    name=snap-$stamp
    raw=$ROOT/data/$name-raw
    out=$ROOT/data/$name
    bin=$BIN
    [[ -e "$out" || -e "$raw" ]] && die "$out exists"
    [[ -f ~/.config/meiolol/snap-salt ]] || die "no salt at ~/.config/meiolol/snap-salt"
    # Here: the real-id copy and the anonymised one side by side, ~2x the box's dbs
    local need
    need=$(box "du -cb ~/ml/meiolol/data/{meiolol,timeline,raw}.db | tail -n 1 | cut -f1")
    (( $(df -k "$ROOT/data" | awk 'NR == 2 { print $4 }') * 1024 > 3 * need )) \
        || die "not enough space in data/ for 3x $need bytes"

    tree=$(mktemp -d)
    # Real ids must not outlive the run, whatever happens
    # shellcheck disable=SC2064 # expand now
    trap "rm -rf '$raw' '$tree'; box 'rm -rf ~/$name'" EXIT
    log "building HEAD $(git -C "$ROOT" rev-parse --short HEAD)"
    git -C "$ROOT" archive HEAD | tar -x -C "$tree"
    (cd "$tree" && zig build --prefix "$bin" -Doptimize=ReleaseFast --cache-dir "$ROOT/.zig-cache" \
        && zig build lab --prefix "$bin" -Doptimize=ReleaseFast --cache-dir "$ROOT/.zig-cache")

    # Each VACUUM INTO holds a read that blocks WAL checkpoints while it runs: one at a time
    log "box: VACUUM INTO ~/$name"
    # shellcheck disable=SC2087 # expands here on purpose: name and DBS
    box bash -s <<EOF
set -euo pipefail
cd ~/ml/meiolol/data
need=\$(du -cb meiolol.db timeline.db raw.db | tail -n 1 | cut -f1)
free=\$(df --output=avail -B1 ~ | tail -n 1)
(( free > 2 * need )) || { echo "box: \$free bytes free for \$need"; exit 1; }
mkdir ~/$name
for d in $DBS; do nice -n 10 sqlite3 "file:\$PWD/\$d.db?mode=ro" "VACUUM INTO '\$HOME/$name/\$d.db'"; done
EOF
    log "streaming to $raw"
    mkdir -p "$raw"
    box "cd ~/$name && tar cf - *.db | zstd -3 -T2 -q" | zstd -d -q | tar x -C "$raw"
    box "rm -rf ~/$name"
    for d in $DBS; do
        [[ "$(sqlite3 "file:$raw/$d.db?mode=ro" 'PRAGMA quick_check')" == ok ]] || die "$d.db: quick_check failed"
    done

    log "anonymising"
    "$bin/bin/meiolol-lab" anonymise "$raw" "$out"
    check "$raw" "$out"
    rm -rf "$raw"

    log "split, legendaries, seat stats, pack"
    "$bin/bin/meiolol-lab" split "$out" > /dev/null
    "$bin/bin/meiolol" legendaries --data "$out" --platform all
    seat_stats "$bin" "$out"
    "$bin/bin/meiolol-lab" pack "$out"

    trap - EXIT
    rm -rf "$tree"
    mkdir -p "$STATE"
    echo "$name" >> "$STATE/pending"
    log "made $name here"
    push_snap "$name" || log "$GPU unreachable: $name waits for a tick that finds it awake"
    return 0
}

# OUT/seat_stats.tsv (rows.Row.stats), with resists and range from Data Dragon of each
# queue 420 patch in OUT/ddragon/PATCH; a patch Data Dragon lacks gets NaN there
seat_stats() {
    local bin=$1 out=$2 versions patches patch v f
    versions=$(curl -sf https://ddragon.leagueoflegends.com/api/versions.json) \
        || die "Data Dragon versions.json unreachable"
    # Not ?mode=ro: a read-only open fails (14) while the WAL has no -shm yet
    patches=$(sqlite3 "$out/meiolol.db" "SELECT DISTINCT patch FROM matches WHERE queue_id = 420") \
        || die "$out/meiolol.db: no patches"
    [[ -n "$patches" ]] || die "$out/meiolol.db: no queue 420 patches"
    for patch in $patches; do
        v=$(grep -o "\"${patch//./\\.}\.[0-9]*\"" <<< "$versions" | head -n 1 | tr -d '"')
        [[ -n "$v" ]] || { log "no Data Dragon version for $patch"; continue; }
        mkdir -p "$out/ddragon/$patch"
        for f in champion item; do
            curl -sfo "$out/ddragon/$patch/$f.json" \
                "https://ddragon.leagueoflegends.com/cdn/$v/data/en_US/$f.json" \
                || die "Data Dragon $v $f.json"
        done
    done
    if [[ -d "$out/ddragon" ]]; then
        "$bin/bin/meiolol-lab" seat-stats "$out" "$out/ddragon"
    else
        "$bin/bin/meiolol-lab" seat-stats "$out"
    fi
}

# Copies NAME to the gpu-box with the gpu-box meiolol-lab that make built, then writes
# mastery_pre.tsv there (pre-game mastery from the raw archive, which lives there only)
push_snap() {
    local name=$1
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" true 2> /dev/null || return 1
    log "to $GPU:ml/snaps/$name"
    rsync -a "$ROOT/data/$name" "$GPU:ml/snaps/"
    scp -q "$BIN/gpu-box/meiolol-lab" "$GPU:ml/bin/meiolol-lab-snapshot"
    if ssh "$GPU" "ml/bin/meiolol-lab-snapshot 2>&1 | grep -q mastery-pre"; then
        log "mastery-pre on $GPU"
        # zstd lives in the gpu-box's ~/bin (no sudo there), not on a plain ssh's PATH
        ssh "$GPU" "PATH=\$HOME/bin:\$PATH nice -n 10 ml/bin/meiolol-lab-snapshot mastery-pre ml/snaps/$name $ARCHIVE" \
            || die "mastery-pre failed on $GPU for $name"
    fi
    [[ -f "$STATE/pending" ]] && sed -i '' "/^$name\$/d" "$STATE/pending"
    log "done: $name. Next: LAB_SNAP in deploy/lab-exp.sh, then deploy/snapshot.sh prune $name"
    command -v wz > /dev/null && wz notify meiolol "snapshot $name ready (here and gpu-box)"
    return 0
}

tick() {
    mkdir -p "$STATE"
    # One at a time; a lock older than 3 h is from a run that was killed (a Mac asleep)
    find "$STATE" -maxdepth 1 -name lock -mmin +180 -exec rmdir {} + 2> /dev/null || true
    mkdir "$STATE/lock" 2> /dev/null || return 0
    # shellcheck disable=SC2064 # expand now; EXIT, as die exits
    trap "rmdir '$STATE/lock'" EXIT
    local name newest age failed
    for name in $(cat "$STATE/pending" 2> /dev/null); do push_snap "$name" || break; done
    newest=$(find "$ROOT/data" -maxdepth 1 -type d -name 'snap-*T*Z' | sort | tail -n 1)
    newest=${newest##*/snap-}
    age=$(( $(date -u +%s) - $(date -j -u -f %Y%m%dT%H%MZ "${newest:-19700101T0000Z}" +%s) ))
    failed=$(( $(date +%s) - $(stat -f %m "$STATE/failed" 2> /dev/null || echo 0) ))
    (( failed > 6 * 3600 )) || return 0
    if (( age > 8 * 86400 )) || { (( $(date +%u) == 7 && 10#$(date +%H) >= 4 )) && (( age > 3 * 86400 )); }; then
        touch "$STATE/failed"
        ( make_snap ) && rm -f "$STATE/failed"
    fi
}

# The anonymised copy against its source: same rows (but the forgotten list and raw
# timelines, left out on purpose), no real PUUID, no real match id. Tables keyed by
# puuidKey (ranks, rank_history) keep only keys of a PUUID the snapshot holds: fewer
check() {
    local src=$1 dst=$2 d t a b id
    [[ "$(count "$dst/meiolol.db" anon_meta)" == 1 ]] || die "check: no anon_meta"
    for d in $DBS; do
        for t in $(sqlite3 "file:$src/$d.db?mode=ro" \
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
             AND name NOT IN ('forgotten', 'timeline_docs')"); do
            a=$(count "$src/$d.db" "$t")
            b=$(count "$dst/$d.db" "$t")
            if [[ "$d $t" == "meiolol ranks" || "$d $t" == "meiolol rank_history" ]]; then
                (( b > 0 && b <= a )) || die "check: $d.$t has $b rows, source $a"
                log "$t: $b of $a rows (keys without a PUUID left out)"
            else
                [[ "$a" == "$b" ]] || die "check: $d.$t has $b rows, source $a"
            fi
        done
    done
    for t in participants players mastery; do
        a=$(sqlite3 "file:$dst/meiolol.db?mode=ro" "SELECT count(*) FROM $t WHERE length(puuid) != 16")
        [[ "$a" == 0 ]] || die "check: $a unhashed PUUIDs in $t"
    done
    id=$(sqlite3 "file:$src/meiolol.db?mode=ro" "SELECT match_id FROM matches LIMIT 1")
    a=$(sqlite3 "file:$dst/meiolol.db?mode=ro" "SELECT count(*) FROM participants WHERE match_id = '$id'")
    [[ "$a" == 0 ]] || die "check: real match id $id in participants"
    log "checks passed"
}

prune() {
    local keep=$1
    [[ "$keep" =~ ^snap-[0-9]{8}T[0-9]{4}Z$ ]] || die "KEEP: snap-STAMP"
    [[ -d "$ROOT/data/$keep" ]] || die "no data/$keep here"
    ssh "$GPU" "test -d ml/snaps/$keep" || die "no ml/snaps/$keep on $GPU"
    grep -q "LAB_SNAP:-$keep" "$ROOT/deploy/lab-exp.sh" || die "LAB_SNAP isn't $keep yet"
    # Only snap-STAMP dirs: data/ also holds hand-made copies (snap, snap-3c)
    find "$ROOT/data" -maxdepth 1 -type d -regex '.*/snap-[0-9]\{8\}T[0-9]\{4\}Z' \
        ! -name "$keep" -print -exec rm -rf {} +
    ssh "$GPU" "find ml/snaps -maxdepth 1 -type d -name 'snap-*T*Z' ! -name '$keep' -print \
        -exec rm -rf {} +"
}

schedule() {
    local plist=net.jacob.meiolol-snapshot.plist
    case "${1:-}" in
        install)
            cp "$ROOT/deploy/$plist" ~/Library/LaunchAgents/
            launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/$plist
            echo "installed $plist (log /tmp/meiolol-snapshot.log)"
            ;;
        uninstall)
            launchctl bootout "gui/$(id -u)/${plist%.plist}" || true
            rm -f ~/Library/LaunchAgents/$plist
            ;;
        *) usage ;;
    esac
}

usage() { sed -n '7,11p' "$0"; exit 2; }

case "${1:-}" in
    make) make_snap ;;
    push) (( $# == 2 )) || usage; push_snap "$2" || die "$GPU unreachable" ;;
    tick) tick ;;
    schedule) schedule "${2:-}" ;;
    prune) (( $# == 2 )) || usage; prune "$2" ;;
    *) usage ;;
esac
