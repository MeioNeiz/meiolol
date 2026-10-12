#!/usr/bin/env bash
# Lab agent runs (docs/lab-agent.md): the agent's only way to score a candidate. Builds
# meiolol-lab with the campaign's candidate (src/lab/cand/CAMPAIGN), runs it through
# deploy/lab-run.sh on a fixed time budget, waits, and prints the harness's RESULT line
# (the log's tail on a crash). Records live on the host in ~/ml/lab/<snapshot>/.
#
#   deploy/lab-exp.sh new CAMPAIGN [FROM]          candidate dir from FROM (default base)
#   deploy/lab-exp.sh run CAMPAIGN NAME TARGET [--select] [--desc TEXT]
#   deploy/lab-exp.sh table [CAMPAIGN]             runs, best dev gain first
#   deploy/lab-exp.sh looks                        the ladder's selection looks
#   deploy/lab-exp.sh show RUN                     summary.md: dev by outcome, role, patch, tier
#   deploy/lab-exp.sh restore CAMPAIGN RUN         a run's candidate back into the campaign
#   deploy/lab-exp.sh stop CAMPAIGN REASON         flag for a human: nothing real left
#   deploy/lab-exp.sh final CAMPAIGN TARGET [N]    humans only: test score of the last N
#                                                  (default 3) selection winners
#
# TARGET: win gold14 lanediff14 cs10 deaths15 first_item. Env: LAB_HOST (gpu-box),
# LAB_SNAP (snap-20261012T2055Z, in ~/ml/snaps on the host), LAB_BUDGET_S (600 s of
# running time; killed at twice that; paused time while League is open doesn't count),
# LAB_ROOT (ml/lab under the host's home; another root keeps smoke tests off the ladder)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${LAB_HOST:-gpu-box}
SNAP=${LAB_SNAP:-snap-20261012T2055Z}
BUDGET=${LAB_BUDGET_S:-600}
LAB_ROOT=${LAB_ROOT:-ml/lab}
LAB=$LAB_ROOT/$SNAP
CANDS=src/lab/cand
# Expands on the host, in the run's job.sh
# shellcheck disable=SC2088
SNAP_PATH="~/ml/snaps/$SNAP"
# shellcheck disable=SC2088
LAB_PATH="~/$LAB_ROOT"

on() {
    if [[ "$HOST" == mac ]]; then (cd && bash -c "$*"); else ssh "$HOST" "$*"; fi
}

usage() {
    sed -n '7,16p' "$0"
    exit 2
}

campaign_dir() {
    [[ "$1" =~ ^[a-z0-9_-]+$ ]] || { echo "CAMPAIGN: a-z 0-9 _ - only"; exit 2; }
    echo "$CANDS/$1"
}

# A candidate may compute, not reach the snapshot, labels or network behind the
# harness's back (module imports already stop it reaching other source files)
guard() {
    local hits
    hits=$(grep -nE 'std\.(Io|fs|process|posix|os|c|net|http|Build)\b|@cImport|@cInclude|@extern|\basm\b' \
        "$1"/*.zig || true)
    if [[ -n "$hits" ]]; then
        echo "candidate refused: it may use only computation (std containers, math, Thread)"
        echo "$hits"
        exit 3
    fi
}

# Builds and starts from a clean tree of HEAD plus the candidate, never the shared
# working tree: other sessions keep half-done edits there, and scoring must be the
# committed harness (an agent's edits outside its candidate never reach a run)
start_clean() {
    local name=$1 cand=$2 tree out status=0
    shift 2
    tree=$(mktemp -d)
    git -C "$ROOT" worktree add -q --detach "$tree" HEAD
    mkdir -p "$(dirname "$tree/$cand")"
    rm -rf "${tree:?}/$cand"
    cp -R "$ROOT/$cand" "$tree/$cand"
    out=$(ZIG_LOCAL_CACHE_DIR="$ROOT/.zig-cache" "$tree/deploy/lab-run.sh" start "$HOST" "$name" \
        --build-arg "-Dcand=$cand" --with "$tree/$cand" -- "$@") || status=$?
    git -C "$ROOT" worktree remove --force "$tree"
    echo "$out"
    return $status
}

# Waits for RUN to end; only running time counts toward the budget
wait_run() {
    local run=$1 used=0 state
    while true; do
        state=$(on "cd ml/runs/$run && if [[ -f exit ]]; then echo exit; \
            elif [[ -f paused ]]; then echo paused; else echo running; fi")
        [[ "$state" == exit ]] && return 0
        [[ "$state" == running ]] && used=$((used + 10))
        if (( used > 2 * BUDGET )); then
            "$ROOT/deploy/lab-run.sh" stop "$HOST" "$run" > /dev/null
            echo "killed after $used s running (budget $BUDGET s)"
            return 1
        fi
        sleep 10
    done
}

cmd=${1:-}
[[ -n "$cmd" ]] || usage
shift
case "$cmd" in
    new)
        (( $# >= 1 )) || usage
        dir=$(campaign_dir "$1")
        from=$CANDS/${2:-base}
        [[ -e "$ROOT/$dir" ]] && { echo "$dir exists"; exit 1; }
        mkdir -p "$ROOT/$dir"
        cp "$ROOT/$from"/*.zig "$ROOT/$dir/"
        printf '# %s digest\n\nWhat worked, what did not, by run id; then ideas.\n' "$1" \
            > "$ROOT/$dir/digest.md"
        echo "$dir from $from"
        ;;
    run)
        (( $# >= 3 )) || usage
        campaign=$1 name=$2 target=$3
        shift 3
        dir=$(campaign_dir "$campaign")
        [[ -f "$ROOT/$dir/root.zig" ]] || { echo "no $dir/root.zig: deploy/lab-exp.sh new"; exit 1; }
        guard "$ROOT/$dir"
        extra=()
        while (( $# )); do
            case "$1" in
                --select) extra+=(--select) ;;
                --desc) extra+=(--desc "$(printf '%q' "$2")"); shift ;;
                *) echo "unknown option $1"; exit 2 ;;
            esac
            shift
        done
        out=$(start_clean "$campaign-$name" "$dir" exp run "$SNAP_PATH" "$campaign" "$target" --lab "$LAB_PATH" ${extra[@]+"${extra[@]}"})
        run=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
        [[ -n "$run" ]] || { echo "$out"; exit 1; }
        if wait_run "$run" && [[ "$(on "cat ml/runs/$run/exit")" == 0 ]]; then
            on "grep '^RESULT' ml/runs/$run/log | tail -n 1"
        else
            on "tail -n 30 ml/runs/$run/log; mkdir -p $LAB; \
                printf '%s\t%s\t%s\t-\t-\t-\t-\tcrash\t-\t-\n' '$run' '$campaign' '$target' \
                >> $LAB/runs.tsv"
            echo "RESULT run=$run crash"
            exit 1
        fi
        ;;
    table)
        filter=${1:-}
        on "[[ -f $LAB/runs.tsv ]] || exit 0; head -n 1 $LAB/runs.tsv; tail -n +2 $LAB/runs.tsv \
            | awk -F '\t' -v c='$filter' 'c == \"\" || \$2 == c' | sort -t \$'\t' -k6,6g" \
            | column -t -s $'\t'
        ;;
    looks)
        on "cat $LAB/looks.tsv 2>/dev/null" | column -t -s $'\t'
        ;;
    show)
        (( $# == 1 )) || usage
        on "cat ml/runs/$1/summary.md"
        ;;
    restore)
        (( $# == 2 )) || usage
        dir=$(campaign_dir "$1")
        src="ml/runs/$2/$1"
        if [[ "$HOST" == mac ]]; then cp "$HOME/$src"/*.zig "$ROOT/$dir/"
        else scp -q "$HOST:$src/*.zig" "$ROOT/$dir/"; fi
        echo "$dir now holds $2's candidate"
        ;;
    stop)
        (( $# == 2 )) || usage
        on "mkdir -p $LAB; printf '%s\t%s\t%s\n' \"\$(date -u +%FT%TZ)\" '$1' $(printf '%q' "$2") \
            >> $LAB/stops.tsv"
        echo "campaign $1 stopped: $2"
        ;;
    final)
        (( $# >= 2 )) || usage
        campaign=$1 target=$2 n=${3:-3}
        runs=$(on "awk -F '\t' '\$2 == \"$campaign\" && \$3 == \"$target\" && \$4 == \"new-best\" \
            { print \$1 }' $LAB/looks.tsv 2>/dev/null | tail -n $n")
        [[ -n "$runs" ]] || { echo "no selection winners for $campaign $target"; exit 1; }
        # Named as the campaign, so the final run dir keeps it as a run's would
        dir=$CANDS/_final/$campaign
        for run in $runs; do
            rm -rf "${ROOT:?}/$dir"
            mkdir -p "$ROOT/$dir"
            if [[ "$HOST" == mac ]]; then cp "$HOME/ml/runs/$run/$campaign"/*.zig "$ROOT/$dir/"
            else scp -q "$HOST:ml/runs/$run/$campaign/*.zig" "$ROOT/$dir/"; fi
            out=$(start_clean "final-$campaign" "$dir" exp final "$SNAP_PATH" "$campaign" "$target" --lab "$LAB_PATH" --run "$run")
            frun=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
            wait_run "$frun" || true
            on "cat ml/runs/$frun/log"
        done
        ;;
    *) usage ;;
esac
