#!/usr/bin/env bash
# The Mac's lab runs (~/ml/runs, deploy/lab-run.sh) as a web app at
# https://meiolol.jomify.lol/admin/training/ (basic auth, installable on Mac and phone).
# Each call stages the view (page from deploy/training, runs.tsv, each run's metrics.tsv
# and log tail) and uploads it when it changed, or every 5 min while a run is live so the
# page can tell a quiet run from a Mac that went to sleep. launchd calls it every 30 s
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
KEY=$HOME/.ssh/meiolol-training
WEB=meiolol@193.123.180.81
KEEP=30
PLIST=net.jacob.meiolol-training.plist

stage() {
    local out=$1 d pg state live=0
    mkdir -p "$out/runs"
    cp "$ROOT"/deploy/training/* "$out/"
    printf 'run\tstate\tstarted\tended\targs\thead\tdirty\tlast\n' > "$out/runs.tsv"
    [[ -d "$RUNS" ]] || { echo 0; return; }
    # Run names start with their UTC start time, so the newest sort last
    for d in $(cd "$RUNS" && find . -mindepth 2 -maxdepth 2 -name job.sh \
            | cut -d/ -f2 | sort | tail -n "$KEEP"); do
        pg=$(cat "$RUNS/$d/job.pgid" 2>/dev/null || true)
        if [[ -f "$RUNS/$d/exit" ]]; then state="exit $(cat "$RUNS/$d/exit")"
        elif [[ -f "$RUNS/$d/stopped" ]]; then state=stopped
        elif [[ -n "$pg" ]] && kill -0 -- "-$pg" 2>/dev/null; then
            live=1
            if [[ -f "$RUNS/$d/paused" ]]; then state=paused; else state=running; fi
        else state=died; fi
        mkdir "$out/runs/$d"
        tail -n 300 "$RUNS/$d/log" > "$out/runs/$d/log.txt" 2>/dev/null || true
        local last=''
        if [[ -f "$RUNS/$d/metrics.tsv" ]]; then
            cp "$RUNS/$d/metrics.tsv" "$out/runs/$d/"
            last=$(awk -F'\t' 'NR == 1 { split($0, h) } END { if (NR > 1) for (i = 2; i <= NF; i++)
                printf "%s%s %s", (i > 2 ? ", " : ""), h[i], $i }' "$RUNS/$d/metrics.tsv")
        fi
        meta() { sed -n "s/^$1 //p" "$RUNS/$d/meta" 2>/dev/null | tr '\t' ' '; }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$state" \
            "$(cat "$RUNS/$d/started" 2>/dev/null)" "$(cat "$RUNS/$d/ended" 2>/dev/null)" \
            "$(meta args)" "$(meta head | cut -c1-10)" "$(meta dirty)" "$last" >> "$out/runs.tsv"
    done
    echo "$live"
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
