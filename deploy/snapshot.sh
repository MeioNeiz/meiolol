#!/usr/bin/env bash
# Analysis snapshots, driven from the Mac (docs/data-safety.md "Analysis snapshots",
# docs/model.md "Shared protocol"): built on the gpu-box from its backup mirror and what
# backups leave out (deploy/snapshot-gpu.sh, which also checks, anonymises, splits and
# packs), then copied here over the LAN for Mac lab runs. Real ids never come here.
#
#   deploy/snapshot.sh make            new ~/ml/snaps/snap-STAMP on the gpu-box, then fetch
#   deploy/snapshot.sh fetch NAME      the gpu-box's NAME to data/NAME here
#   deploy/snapshot.sh tick            hourly (launchd): fetch what waits, make when due
#   deploy/snapshot.sh prune KEEP      delete every other snap-* here and on the gpu-box
#   deploy/snapshot.sh schedule install|uninstall   the hourly tick
#
# Due: Sundays from 07:00 (after the day's 04:00 UTC backup has reached the mirror), or
# any day once the newest is 8 days old; a failed make waits 6 h before the next try. A
# gpu-box asleep, without its lab partition, with League open or a mirror over a day old
# skips the tick. A snapshot not yet fetched here waits in ~/.cache/meiolol-snapshot/pending
#
# Builds from committed HEAD in a temp tree (other sessions edit the shared checkout).
# The lab agent's snapshot is LAB_SNAP in deploy/lab-exp.sh: move it to the new one
# before prune. Env: SNAP_GPU (gpu-box)
set -euo pipefail
# launchd's login bash finds Homebrew's zig (0.16) first and no wz: the pinned 0.17 and
# wz live in ~/.local/bin
export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
GPU=${SNAP_GPU:-gpu-box}
STATE=$HOME/.cache/meiolol-snapshot
BIN=$ROOT/zig-out/snapshot

log() { echo "$(date -u +%FT%TZ) $*"; }
# A toast too: weekly runs have no one watching (wz is the Mac's notifier)
die() {
    log "$*"
    command -v wz > /dev/null && wz notify --for 60 meiolol "snapshot failed: $*"
    exit 1
}

make_snap() {
    local stamp name bin tree
    stamp=$(date -u +%Y%m%dT%H%MZ)
    name=snap-$stamp
    bin=$BIN
    gpu_ready || return 0
    tree=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now
    trap "rm -rf '$tree'" EXIT
    log "building HEAD $(git -C "$ROOT" rev-parse --short HEAD)"
    git -C "$ROOT" archive HEAD | tar -x -C "$tree"
    (cd "$tree" && zig build lab --prefix "$bin" -Doptimize=ReleaseFast --cache-dir "$ROOT/.zig-cache" \
        && zig build --prefix "$bin/gpu-box-meiolol" -Doptimize=ReleaseSafe -Dtarget=x86_64-linux-musl \
            -Dcpu=x86_64_v3 --cache-dir "$ROOT/.zig-cache")
    scp -q "$bin/gpu-box/meiolol-lab" "$GPU:ml/bin/meiolol-lab-snapshot"
    scp -q "$bin/gpu-box-meiolol/bin/meiolol" "$GPU:ml/bin/meiolol-snapshot"
    scp -q "$tree/deploy/snapshot-gpu.sh" "$GPU:ml/bin/"
    trap - EXIT
    rm -rf "$tree"
    log "$GPU: building $name"
    ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$GPU" "ml/bin/snapshot-gpu.sh $name" \
        || die "snapshot-gpu.sh failed on $GPU for $name"
    mkdir -p "$STATE"
    echo "$name" >> "$STATE/pending"
    fetch_snap "$name" || log "$name waits for a tick to fetch it here"
    command -v wz > /dev/null && wz notify meiolol "snapshot $name ready (gpu-box and here)"
    return 0
}

# The gpu-box can take a build now: awake, the lab partition mounted, League closed
# (Jacob's rule for long jobs there), the backup mirror less than a day old
gpu_ready() {
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" true 2> /dev/null || { log "$GPU asleep"; return 1; }
    ssh "$GPU" 'mountpoint -q /mnt/wsl/lab' || { log "$GPU: /mnt/wsl/lab not mounted"; return 1; }
    if ssh "$GPU" "/mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null \
        | grep -qiE '^\"(LeagueClient|League of Legends)\.exe\"'"; then
        log "$GPU: League is open"
        return 1
    fi
    ssh "$GPU" 'test -n "$(find /mnt/wsl/archive/meiolol-backups/.mirrored -mmin -1440)"' \
        || { log "$GPU: backup mirror older than a day"; return 1; }
}

# A copy here for Mac lab runs (deploy/lab-run.sh places runs on either host), over the
# LAN from the gpu-box
fetch_snap() {
    local name=$1
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" true 2> /dev/null || return 1
    log "from $GPU:ml/snaps/$name"
    rsync -a "$GPU:ml/snaps/$name" "$ROOT/data/"
    # Same path on both hosts, so deploy/lab-run.sh can place a run on either
    mkdir -p ~/ml/snaps && ln -sfn "$ROOT/data/$name" ~/ml/snaps/"$name"
    [[ -f "$STATE/pending" ]] && sed -i '' "/^$name\$/d" "$STATE/pending"
    log "done: $name. Next: LAB_SNAP in deploy/lab-exp.sh, then deploy/snapshot.sh prune $name"
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
    for name in $(cat "$STATE/pending" 2> /dev/null); do fetch_snap "$name" || break; done
    # The gpu-box's: it builds them, and a Mac copy may lag
    newest=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" \
        "find ml/snaps/ -maxdepth 1 -type d -name 'snap-*T*Z'" 2> /dev/null | sort | tail -n 1) || return 0
    newest=${newest##*/snap-}
    age=$(( $(date -u +%s) - $(date -j -u -f %Y%m%dT%H%MZ "${newest:-19700101T0000Z}" +%s) ))
    failed=$(( $(date +%s) - $(stat -f %m "$STATE/failed" 2> /dev/null || echo 0) ))
    (( failed > 6 * 3600 )) || return 0
    if (( age > 8 * 86400 )) || { (( $(date +%u) == 7 && 10#$(date +%H) >= 7 )) && (( age > 3 * 86400 )); }; then
        touch "$STATE/failed"
        ( make_snap ) && rm -f "$STATE/failed"
    fi
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
    find ~/ml/snaps -maxdepth 1 -type l -name 'snap-*T*Z' ! -name "$keep" -delete \
        2> /dev/null || true
    ssh "$GPU" "find ml/snaps -maxdepth 1 -type d -name 'snap-*T*Z' ! -name '$keep' -print \
        -exec rm -rf {} +"
}

schedule() {
    local plist=net.jacob.meiolol-snapshot.plist
    case "${1:-}" in
        install)
            launchd_install "$plist"
            echo "installed $plist (log /tmp/meiolol-snapshot.log)"
            ;;
        uninstall) launchd_uninstall "$plist" ;;
        *) usage ;;
    esac
}

usage() { usage_of "$0"; exit 2; }

case "${1:-}" in
    make) make_snap ;;
    fetch) (( $# == 2 )) || usage; fetch_snap "$2" || die "$GPU unreachable" ;;
    tick) tick ;;
    schedule) schedule "${2:-}" ;;
    prune) (( $# == 2 )) || usage; prune "$2" ;;
    *) usage ;;
esac
