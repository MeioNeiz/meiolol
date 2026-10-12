#!/usr/bin/env bash
# The lab runs of the Mac and the gpu-box (~/ml/runs on each, deploy/lab-run.sh) as a web
# app at https://meiolol.jomify.lol/admin/training/ (basic auth, installable on Mac and
# phone) and the admin page's Training tab. Each call stages the view (page from
# deploy/training, runs.tsv, each run's metrics.tsv and log tail) and uploads it when it
# changed, or every 5 min while a run is live so the page can tell a quiet run from a Mac
# that went to sleep. The gpu-box (home network only) is staged over ssh at most once a
# minute; when unreachable its last staged copy is sent and hosts.tsv says when it was
# last reached. launchd calls it every 30 s
# once installed. Upload: a gzipped tar over ssh with a key whose forced command is
# deploy/training-receive.sh on the web server (docs/hosting.md)
#
#   deploy/lab-push.sh [--force]        stage, upload if changed
#   deploy/lab-push.sh install|uninstall  launchd agent (every 30 s)
#
# Runs report progress by appending to metrics.tsv in their run directory: a header, then
# one row per evaluation; first column the x axis (step, epoch, games), the rest numbers.
# Columns sharing the part after the last _ share a chart (train_loss and test_loss)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNS=${MEIOLOL_RUNS:-$HOME/ml/runs}
STATE=$HOME/.cache/meiolol-training
GPU=${MEIOLOL_GPU_HOST-gpu-box}
KEY=$HOME/.ssh/meiolol-training
WEB=meiolol@193.123.180.81
KEEP=30
PLIST=net.jacob.meiolol-training.plist

# The newest runs under $1 into $2/runs/<run>/ and their runs.tsv rows (no header) into
# $2/rows; prints 1 when one is live. Runs on the Mac and, sent over ssh, on the gpu-box
stage_runs() {
    local runs=$1 out=$2 host=$3 keep=$4 d pg state live=0 last
    mkdir -p "$out/runs"
    : > "$out/rows"
    [[ -d "$runs" ]] || { echo 0; return; }
    # Run names start with their UTC start time, so the newest sort last
    for d in $(cd "$runs" && find . -mindepth 2 -maxdepth 2 -name job.sh \
            | cut -d/ -f2 | sort | tail -n "$keep"); do
        pg=$(cat "$runs/$d/job.pgid" 2>/dev/null || true)
        if [[ -f "$runs/$d/exit" ]]; then state="exit $(cat "$runs/$d/exit")"
        elif [[ -f "$runs/$d/stopped" ]]; then state=stopped
        elif [[ -n "$pg" ]] && kill -0 -- "-$pg" 2>/dev/null; then
            live=1
            if [[ -f "$runs/$d/paused" ]]; then state=paused; else state=running; fi
        else state=died; fi
        mkdir "$out/runs/$d"
        tail -n 300 "$runs/$d/log" > "$out/runs/$d/log.txt" 2>/dev/null || true
        last=''
        if [[ -f "$runs/$d/metrics.tsv" ]]; then
            cp "$runs/$d/metrics.tsv" "$out/runs/$d/"
            last=$(awk -F'\t' 'NR == 1 { split($0, h) } END { if (NR > 1) for (i = 2; i <= NF; i++)
                printf "%s%s %s", (i > 2 ? ", " : ""), h[i], $i }' "$runs/$d/metrics.tsv")
        else
            # meiolol-lab's summary line (lab exp run, screen, diagnose, preds)
            last=$(grep -h '^RESULT ' "$runs/$d/log" 2>/dev/null | tail -n 1 | cut -c8- | tr '\t' ' ' || true)
        fi
        meta() { sed -n "s/^$1 //p" "$runs/$d/meta" 2>/dev/null | tr '\t' ' '; }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$state" \
            "$(cat "$runs/$d/started" 2>/dev/null)" "$(cat "$runs/$d/ended" 2>/dev/null)" \
            "$(meta args)" "$(meta head | cut -c1-10)" "$(meta dirty)" "$last" "$host" >> "$out/rows"
    done
    echo "$live"
}

# The gpu-box's runs into $STATE/gpu (kept when it can't be reached); prints 1 when live
stage_gpu() {
    local now at fresh
    now=$(date +%s)
    at=$(cat "$STATE/gpu-at" 2>/dev/null || echo 0)
    if [[ -n "$GPU" ]] && (( now - at >= 60 )); then
        fresh=$(mktemp -d)
        # shellcheck disable=SC2016 # expanded on the gpu-box
        if { declare -f stage_runs; echo 'o=$(mktemp -d); echo "$(stage_runs ~/ml/runs "$o" gpu-box '"$KEEP"')" > "$o/live"'
             echo 'tar -czf - -C "$o" .; rm -rf "$o"'; } \
            | ssh -o BatchMode=yes -o ConnectTimeout=5 "$GPU" bash -s 2>/dev/null \
            | tar -xzf - -C "$fresh" 2>/dev/null && [[ -f "$fresh/live" ]]; then
            rm -rf "$STATE/gpu"
            mv "$fresh" "$STATE/gpu"
            echo "$now" > "$STATE/gpu-seen"
        else
            rm -rf "$fresh"
        fi
        echo "$now" > "$STATE/gpu-at"
    fi
    cat "$STATE/gpu/live" 2>/dev/null || echo 0
}

stage() {
    local out=$1 mac gpu seen
    mkdir -p "$out"
    cp "$ROOT"/deploy/training/* "$out/"
    mac=$(stage_runs "$RUNS" "$out/mac" mac "$KEEP")
    gpu=$(stage_gpu)
    mkdir -p "$out/runs"
    {
        printf 'run\tstate\tstarted\tended\targs\thead\tdirty\tlast\thost\n'
        { cat "$out/mac/rows"; cat "$STATE/gpu/rows" 2>/dev/null || true; } | sort
    } > "$out/runs.tsv"
    cp -R "$out/mac/runs/." "$out/runs/"
    [[ -d "$STATE/gpu/runs" ]] && cp -R "$STATE/gpu/runs/." "$out/runs/"
    rm -rf "$out/mac"
    # Seen to 10 min, so an idle gpu-box doesn't cause an upload a minute
    seen=$(cat "$STATE/gpu-seen" 2>/dev/null || true)
    printf 'host\tseen\n' > "$out/hosts.tsv"
    [[ -n "$GPU" ]] && printf '%s\t%s\n' "$GPU" "${seen:+$(( seen / 600 * 600 ))}" >> "$out/hosts.tsv"
    echo $(( mac || gpu ))
}

push() {
    local force=${1:-} next live now last
    mkdir -p "$STATE"
    next=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: next is local
    trap "rm -rf '$next'" RETURN
    live=$(stage "$next")
    now=$(date +%s)
    last=$(cat "$STATE/pushed" 2>/dev/null || echo 0)
    if [[ -z "$force" && -d "$STATE/sent" ]] && diff -rq "$next" "$STATE/sent" > /dev/null \
        && ! (( live && now - last >= 300 )); then
        return 0
    fi
    echo "$now" > "$next/pushed.txt"
    COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -czf - -C "$next" . \
        | ssh -T -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=20 "$WEB"
    rm "$next/pushed.txt"
    rm -rf "$STATE/sent"
    cp -R "$next" "$STATE/sent"
    echo "$now" > "$STATE/pushed"
}

case "${1:-}" in
    '') push ;;
    --force) push force ;;
    install)
        cp "$ROOT/deploy/$PLIST" ~/Library/LaunchAgents/
        launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/$PLIST
        echo "installed $PLIST"
        ;;
    uninstall)
        launchctl bootout "gui/$(id -u)/${PLIST%.plist}" || true
        rm -f ~/Library/LaunchAgents/$PLIST
        ;;
    *) sed -n '10,11p' "$0"; exit 2 ;;
esac
