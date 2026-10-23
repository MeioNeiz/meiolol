#!/usr/bin/env bash
# Analysis snapshots, driven from the Mac (docs/data-safety.md "Analysis snapshots",
# docs/model.md "Shared protocol"): built on the gpu-box from its backup mirror and what
# backups leave out (deploy/snapshot-gpu.sh, which also checks, anonymises, splits and
# packs), then copied here over the LAN for Mac lab runs. Real ids never come here.
#
#   deploy/snapshot.sh make            new ~/ml/snaps/snap-STAMP on the gpu-box, then fetch
#   deploy/snapshot.sh fetch NAME      the gpu-box's NAME to data/NAME here
#   deploy/snapshot.sh tick            hourly (launchd): fetch what waits, make when due
#   deploy/snapshot.sh prune           delete older snap-* here and on the gpu-box
#   deploy/snapshot.sh schedule install|uninstall   the hourly tick
#
# Due daily from 07:00 once the newest predates the day's 04:00 UTC backup (a snapshot
# holds games up to the last backup); a failed make waits 6 h before the next try. A
# gpu-box asleep, without its lab partition, with League open or a mirror over a day old
# skips the tick. A snapshot not yet fetched here waits in
# ~/.cache/meiolol-snapshot/pending. Each fetch prunes: older snapshots go, but
# docs/golden.tsv's and any a run that hasn't ended names
#
# Builds from committed HEAD in a temp tree (other sessions edit the shared checkout).
# Env: SNAP_GPU (gpu-box)
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
    local name bin tree
    bin=$BIN
    gpu_ready || return 0
    # A build that died under a day ago carries on under its name, from its last done
    # stage (snapshot-gpu.sh, which deletes older ones)
    name=$(ssh "$GPU" "cd ml/snaps 2> /dev/null && find . -maxdepth 2 -mmin -1440 \
        \( -path './.snap-*-real/started' -o -path './snap-*/.building' \)" \
        | grep -oE 'snap-[0-9]{8}T[0-9]{4}Z' | sort | tail -n 1) || true
    if [[ -n $name ]]; then log "resuming $name"
    else name=snap-$(date -u +%Y%m%dT%H%MZ)
    fi
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
    # A user unit, so a dropped ssh no longer kills the build (22 Oct, 80 min in). Each
    # poll touches awake.d (lab-watch.sh keeps Windows awake while it is fresh)
    ssh "$GPU" "systemctl --user -q is-active meiolol-snapshot && exit 1; rm -f ml/snapshot.rc; \
        systemd-run --user -q --collect --unit meiolol-snapshot --working-directory=\$HOME \
        /bin/bash -c 'ml/bin/snapshot-gpu.sh $name > ml/snapshot.log 2>&1; echo \$? > ml/snapshot.rc'" \
        || die "$GPU: a snapshot build is running already"
    local rc=
    for _ in $(seq 480); do
        sleep 30
        rc=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" "mkdir -p ml/awake.d; \
            touch ml/awake.d/snapshot; systemctl --user -q is-active meiolol-snapshot \
            || cat ml/snapshot.rc 2> /dev/null || echo lost") || continue
        [[ -n $rc ]] && break
    done
    ssh "$GPU" 'rm -f ml/awake.d/snapshot; cat ml/snapshot.log' || true
    [[ $rc == 0 ]] || die "snapshot-gpu.sh failed on $GPU for $name (${rc:-still running after 4 h})"
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
    log "done: $name"
    prune
    return 0
}

tick() {
    mkdir -p "$STATE"
    # One at a time; a lock older than 3 h is from a run that was killed (a Mac asleep)
    find "$STATE" -maxdepth 1 -name lock -mmin +180 -exec rmdir {} + 2> /dev/null || true
    mkdir "$STATE/lock" 2> /dev/null || return 0
    # shellcheck disable=SC2064 # expand now; EXIT, as die exits
    trap "rmdir '$STATE/lock'" EXIT
    local name newest failed backup
    for name in $(cat "$STATE/pending" 2> /dev/null); do fetch_snap "$name" || break; done
    # The gpu-box's: it builds them, and a Mac copy may lag
    # Finished ones only (mastery_pre.tsv is the last step, as lab-exp.sh reads it): an
    # unfinished newer one is resumed by make, not counted
    newest=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$GPU" \
        "find ml/snaps/ -maxdepth 2 -path 'ml/snaps/snap-*T*Z/mastery_pre.tsv'" 2> /dev/null \
        | sort | tail -n 1) || return 0
    newest=${newest%/mastery_pre.tsv}
    newest=${newest##*/snap-}
    failed=$(( $(date +%s) - $(stat -f %m "$STATE/failed" 2> /dev/null || echo 0) ))
    (( failed > 6 * 3600 )) || return 0
    backup=$(date -u +%Y%m%dT0400Z)
    if (( 10#$(date +%H) >= 7 )) && [[ "${newest:-0}" < "$backup" ]]; then
        touch "$STATE/failed"
        ( make_snap ) && rm -f "$STATE/failed"
    fi
}

# Snapshots named by runs that haven't ended on a host (deploy/lab-run.sh state_cmd: no
# exit or stopped, process group alive or not started yet)
# shellcheck disable=SC2016 # expands on the host
BUSY='cd && for d in ml/runs/*/; do
    [[ -f $d/exit || -f $d/stopped ]] && continue
    pg=$(cat $d/job.pgid 2> /dev/null)
    [[ -z $pg ]] || kill -0 -- -$pg 2> /dev/null || continue
    grep -ohE "snap-[0-9]{8}T[0-9]{4}Z" $d/job.sh 2> /dev/null; done; true'

here() {
    find "$ROOT/data" -maxdepth 1 -type d -name 'snap-*T*Z' | sed 's|.*/||' \
        | grep -E '^snap-[0-9]{8}T[0-9]{4}Z$'
}

# Deletes snap-STAMP dirs older than the newest the Mac has in full, on both hosts; keeps
# docs/golden.tsv's (golden.sh reruns its references on them) and busy ones. Hand-made
# copies (snap, snap-3c) don't match
prune() {
    local keep spare s
    keep=$(here | grep -vxF -f <(cat "$STATE/pending" 2> /dev/null) | sort | tail -n 1)
    [[ -n "$keep" ]] || return 0
    ssh "$GPU" "test -d ml/snaps/$keep" || { log "prune: no $keep on $GPU"; return 0; }
    spare=$({
        awk -F'\t' '!/^#/ && $2 { print "snap-" $2 }' "$ROOT/docs/golden.tsv"
        bash -c "$BUSY"
        ssh "$GPU" "$BUSY"
    }) || { log "prune: can't list runs"; return 0; }
    old() {
        grep -E '^snap-[0-9]{8}T[0-9]{4}Z$' | while read -r s; do
            [[ "$s" < "$keep" ]] && ! grep -qxF "$s" <<< "$spare" && echo "$s"
        done
    }
    for s in $(here | old); do
        log "prune $s here"
        rm -rf "${ROOT:?}/data/$s" ~/ml/snaps/"$s"
    done
    for s in $(ssh "$GPU" 'ls ml/snaps' | old); do
        log "prune $s on $GPU"
        ssh "$GPU" "rm -rf ml/snaps/$s"
    done
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
    prune) prune ;;
    *) usage ;;
esac
