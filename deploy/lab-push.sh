#!/usr/bin/env bash
# The lab runs of the Mac and the gpu-box (~/ml/runs on each, deploy/lab-run.sh) as a web
# app at https://meio.lol/admin/training/ (basic auth, installable on Mac and
# phone) and the admin page's Training tab. Each call stages the view (page from
# deploy/training, runs.tsv, each run's metrics.tsv and log tail) and uploads it when it
# changed, or every 5 min while a run is live so the page can tell a quiet run from a Mac
# that went to sleep. Also sent: docs/learned.md, docs/model.md and docs/nn-results/*.tsv
# (nn.txt lists them) from this checkout, each lab campaign's digest.md and hypotheses.tsv
# (~/ml/agent/<campaign>, LAB_CANDS), and a run's result.tsv, findings.tsv and
# effects-*.tsv (meiolol-lab), all also read into training.bin for the admin
# page (`meiolol admin --training`); and the admin Draft tester's models
# (draft-model.json, lane-model.json and their -ref.json) from the export a human chose
# with `use`, never just the newest (a smoke or agent run may export one). The tester
# reads the box's daily files (private/models/, `meiolol draft-model`) as "Shipped model";
# these are "Lab experiment".
# The gpu-box (home network only) is staged over ssh at most once a minute; when
# unreachable its last staged copy is sent and hosts.tsv says when it was last reached.
# launchd calls it every 30 s once installed. Upload: a gzipped tar over ssh with a key
# whose forced command is deploy/training-receive.sh on the web server (docs/hosting.md)
#
#   deploy/lab-push.sh [--force]        stage, upload if changed
#   deploy/lab-push.sh install|uninstall  launchd agent (every 30 s)
#   deploy/lab-push.sh use draft|lane [RUN|DIR|none]
#                                       the tester's model: a run (this Mac's or the
#                                       gpu-box's) or a dir holding <kind>-model.json;
#                                       no argument shows the choice
#
# Runs report progress by appending to metrics.tsv in their run directory: a header, then
# one row per evaluation; first column the x axis (step, epoch, games), the rest numbers.
# Columns sharing the part after the last _ share a chart (train_loss and test_loss)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
RUNS=${MEIOLOL_RUNS:-$HOME/ml/runs}
STATE=$HOME/.cache/meiolol-training
GPU=${MEIOLOL_GPU_HOST-gpu-box}
CAMPAIGNS=${LAB_CANDS:-$HOME/ml/agent}
KEY=$HOME/.ssh/meiolol-training
WEB=meiolol@100.95.95.44
KEEP=30
PLIST=net.jacob.meiolol-training.plist
NEXT=''
# Not a RETURN trap in push: set -e exits (an unreachable server) skip those
trap 'rm -rf "${NEXT:-}"' EXIT

# This script's own meiolol, built from origin/main (what the site runs): the checkout's
# zig-out is whatever a session last installed, often days old. Rebuilt when origin/main
# moves; a failed build keeps the last binary and isn't tried again at that commit
meiolol_bin() {
    local bin=$STATE/bin/meiolol rev
    rev=$(git -C "$ROOT" rev-parse -q --verify origin/main) || { echo "$bin"; return; }
    if [[ "$(cat "$STATE/bin/rev" 2>/dev/null)" != "$rev" \
        && "$(cat "$STATE/bin/failed" 2>/dev/null)" != "$rev" ]]; then
        mkdir -p "$STATE/bin"
        # shellcheck disable=SC2016 # the inner sh expands it
        if "$ROOT/deploy/slots.sh" 1 "$ROOT/deploy/build-tree.sh" lab-push "$rev" sh -c \
            'zig build backend -Doptimize=ReleaseSafe && cp zig-out/bin/meiolol "$1.new"' \
            _ "$bin" >&2 && mv "$bin.new" "$bin"; then
            echo "$rev" > "$STATE/bin/rev"
        else
            echo "$rev" > "$STATE/bin/failed"
            echo "lab-push: meiolol build at $rev failed, kept the last one" >&2
        fi
    fi
    echo "$bin"
}

# The newest runs under $1 into $2/runs/<run>/ and their runs.tsv rows (no header) into
# $2/rows; prints 1 when one is live. Runs on the Mac and, sent over ssh, on the gpu-box
stage_runs() {
    local runs=$1 out=$2 host=$3 keep=$4 d pg state live=0 last found
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
        # meiolol-lab's plain results: result.tsv (the run's record, category, error removed),
        # findings.tsv (one sentence per line) and its effects-*.tsv tables; `found` lists the
        # ones present so the page fetches only those
        found=''
        for f in result.tsv findings.tsv draft-model.json draft-ref.json lane-model.json \
            lane-ref.json "$runs/$d"/effects-*.tsv; do
            f=${f##*/}
            if [[ -f "$runs/$d/$f" ]]; then
                cp "$runs/$d/$f" "$out/runs/$d/"
                [[ $f == *.tsv ]] && found+="${found:+,}$f"
            fi
        done
        meta() { sed -n "s/^$1 //p" "$runs/$d/meta" 2>/dev/null | tr '\t' ' '; }
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$d" "$state" \
            "$(cat "$runs/$d/started" 2>/dev/null)" "$(cat "$runs/$d/ended" 2>/dev/null)" \
            "$(meta args)" "$(meta head | cut -c1-10)" "$(meta dirty)" "$last" "$host" "$found" >> "$out/rows"
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
    local out=$1 mac gpu seen d f
    mkdir -p "$out"
    cp "$ROOT"/deploy/training/* "$out/"
    mac=$(stage_runs "$RUNS" "$out/mac" mac "$KEEP")
    gpu=$(stage_gpu)
    mkdir -p "$out/runs"
    {
        printf 'run\tstate\tstarted\tended\targs\thead\tdirty\tlast\thost\tfindings\n'
        { cat "$out/mac/rows"; cat "$STATE/gpu/rows" 2>/dev/null || true; } | sort
    } > "$out/runs.tsv"
    cp -R "$out/mac/runs/." "$out/runs/"
    [[ -d "$STATE/gpu/runs" ]] && cp -R "$STATE/gpu/runs/." "$out/runs/"
    rm -rf "$out/mac"
    for m in draft lane; do model "$m" "$out"; done
    cp "$ROOT/docs/learned.md" "$ROOT/docs/model.md" "$out/" 2>/dev/null || true
    mkdir -p "$out/nn"
    cp "$ROOT"/docs/nn-results/*.tsv "$out/nn/" 2>/dev/null || true
    (cd "$out/nn" && find . -name '*.tsv' | cut -c3- | sort) > "$out/nn.txt"
    mkdir -p "$out/campaigns"
    for d in "$CAMPAIGNS"/*/; do
        [[ -d "$d" ]] || continue
        f=$(basename "$d")
        mkdir -p "$out/campaigns/$f"
        cp "$d"digest.md "$d"hypotheses.tsv "$out/campaigns/$f/" 2>/dev/null || true
    done
    (cd "$out/campaigns" && find . -mindepth 1 -maxdepth 1 -type d | cut -c3- | sort) > "$out/campaigns.txt"
    # Seen to 10 min, so an idle gpu-box doesn't cause an upload a minute
    seen=$(cat "$STATE/gpu-seen" 2>/dev/null || true)
    printf 'host\tseen\n' > "$out/hosts.tsv"
    [[ -n "$GPU" ]] && printf '%s\t%s\n' "$GPU" "${seen:+$(( seen / 600 * 600 ))}" >> "$out/hosts.tsv"
    # The new admin page's Models tab reads these files (hosts.tsv too) as training.bin
    # and runs/*/metrics.bin
    "$(meiolol_bin)" admin --training "$out" \
        || echo "lab-push: no training.bin (meiolol admin --training failed)" >&2
    echo $(( mac || gpu ))
}

# The Draft tester's KIND model (meiolol-lab draft or lane --export) into $2, from the
# export `use` chose: a dir, or a run here or in the gpu-box's staged runs (--export DIR
# may write into a dir that isn't a lab-run.sh run). Kept in $STATE/model-KIND once
# found, so a gpu-box run that drops out of the newest $KEEP still serves
model() {
    local kind=$1 out=$2 pick cache=$STATE/model-$1 d
    pick=$(cat "$STATE/use-$kind" 2>/dev/null || true)
    [[ -n "$pick" ]] || return 0
    for d in "$pick" "$RUNS/$pick" "$out/runs/$pick"; do
        if [[ "$d" == /* && -f "$d/$kind-model.json" ]]; then
            # Copied once per pick (or a re-export), not every call: the bin below
            # is made from the copy
            if [[ "$(cat "$cache/from" 2>/dev/null)" != "$pick" \
                || "$d/$kind-model.json" -nt "$cache/$kind-model.json" ]]; then
                rm -rf "$cache"
                mkdir -p "$cache"
                cp "$d/$kind"-*.json "$cache/"
                echo "$pick" > "$cache/from"
            fi
            break
        fi
    done
    [[ "$(cat "$cache/from" 2>/dev/null)" == "$pick" ]] || return 0
    # The new tester page reads <kind>-model.bin (and draft-setnet.bin), made by this
    # checkout's build. Tried once per copy and build: no-bin holds why it failed.
    # --data: every command makes its data dir, and launchd's cwd is /
    local bin rev
    bin=$(meiolol_bin)
    rev=$(cat "$STATE/bin/rev" 2>/dev/null || true)
    if [[ "$(cat "$cache/bin-rev" 2>/dev/null)" != "$rev" ]]; then
        if ! "$bin" tester-bin "$cache" --data "$cache" > "$cache/no-bin" 2>&1; then
            echo "lab-push: tester-bin for $pick: $(tail -1 "$cache/no-bin")" >&2
        else
            rm -f "$cache/no-bin"
        fi
        echo "$rev" > "$cache/bin-rev"
    fi
    cp "$cache/$kind"-*.json "$out/"
    for f in "$cache/$kind"-*.bin; do
        [[ -f "$f" ]] && cp "$f" "$out/"
    done
    return 0
}

use() {
    local kind=$1 pick=${2:-}
    [[ "$kind" == draft || "$kind" == lane ]] || { echo "use draft|lane [RUN|DIR|none]"; exit 2; }
    if [[ -z "$pick" ]]; then
        echo "$kind: $(cat "$STATE/use-$kind" 2>/dev/null || echo none)"
    elif [[ "$pick" == none ]]; then
        rm -f "$STATE/use-$kind"
        echo "$kind: none (the tester gets no $kind model)"
    else
        [[ "$pick" != /* || -f "$pick/$kind-model.json" ]] || { echo "no $pick/$kind-model.json"; exit 1; }
        [[ "$pick" == /* || "$pick" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "RUN: a run name"; exit 2; }
        mkdir -p "$STATE"
        echo "$pick" > "$STATE/use-$kind"
        echo "$kind: $pick (sent with the next push if it has $kind-model.json)"
    fi
}

push() {
    local force=${1:-} next live now last
    mkdir -p "$STATE"
    NEXT=$(mktemp -d)
    next=$NEXT
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
    use) use "${2:-}" "${3:-}" ;;
    install) launchd_install "$PLIST" && echo "installed $PLIST" ;;
    uninstall) launchd_uninstall "$PLIST" ;;
    *) usage_of "$0"; exit 2 ;;
esac
