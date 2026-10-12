#!/usr/bin/env bash
# Lab agent runs (docs/lab-agent.md): the agent's only way to score a candidate. Builds
# meiolol-lab with the campaign's candidate (src/lab/cand/CAMPAIGN), runs it through
# deploy/lab-run.sh on a fixed time budget, waits, and prints the harness's RESULT line
# (the log's tail on a crash). Records live on the host in ~/ml/lab/<snapshot>/.
#
#   deploy/lab-exp.sh new CAMPAIGN [FROM]          candidate dir from FROM (default base)
#   deploy/lab-exp.sh run CAMPAIGN NAME TARGET [--select] [--fraction F] [--hyp ID]
#                         [--desc TEXT]
#   deploy/lab-exp.sh screen CAMPAIGN TARGET       dev: the candidate's features one by one
#   deploy/lab-exp.sh diagnose CAMPAIGN TARGET     dev: residual bias by covariate
#   deploy/lab-exp.sh table [CAMPAIGN]             runs, best dev gain first
#   deploy/lab-exp.sh looks                        the ladder's selection looks
#   deploy/lab-exp.sh show RUN                     summary.md: dev by outcome, role, patch, tier
#   deploy/lab-exp.sh restore CAMPAIGN RUN         a run's candidate back into the campaign
#   deploy/lab-exp.sh finding CAMPAIGN RUN TEXT [EFFECT_FILE]
#                                                  what RUN learnt about the game, one plain
#                                                  sentence, to the run's findings.tsv
#   deploy/lab-exp.sh stop CAMPAIGN REASON         flag for a human: nothing real left
#   deploy/lab-exp.sh final CAMPAIGN TARGET [N]    humans only: test score of the last N
#                                                  (default 3) selection winners
#   deploy/lab-exp.sh preds CAMPAIGN               humans only: test-row predictions (no
#                                                  scores) to RUN/preds.tsv, to check a port
#
# TARGET: win gold14 lanediff14 cs10 deaths15 first_item. Env: LAB_HOST (gpu-box),
# LAB_SNAP (snap-20261012T2055Z, in ~/ml/snaps on the host), LAB_BUDGET_S (600 s of
# running time; killed at twice that; paused time while League is open doesn't count),
# LAB_ROOT (ml/lab under the host's home; another root keeps smoke tests off the ladder),
# LAB_CANDS (campaign dirs; default src/lab/cand here), LAB_MAX_RUNS (per campaign; unset:
# no cap)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=${LAB_HOST:-gpu-box}
SNAP=${LAB_SNAP:-snap-20261012T2055Z}
BUDGET=${LAB_BUDGET_S:-600}
MAX_RUNS=${LAB_MAX_RUNS:-}
LAB_ROOT=${LAB_ROOT:-ml/lab}
LAB=$LAB_ROOT/$SNAP
CANDS=src/lab/cand
# Where campaigns live: an agent session works outside the shared checkout (docs/
# lab-brief.md), so it can't touch other sessions' files
CAND_ROOT=${LAB_CANDS:-$ROOT/$CANDS}
# Expands on the host, in the run's job.sh
# shellcheck disable=SC2088
SNAP_PATH="~/ml/snaps/$SNAP"
# shellcheck disable=SC2088
LAB_PATH="~/$LAB_ROOT"

on() {
    if [[ "$HOST" == mac ]]; then (cd && bash -c "$*"); else ssh "$HOST" "$*"; fi
}

usage() {
    sed -n '7,25p' "$0"
    exit 2
}

campaign_dir() {
    [[ "$1" =~ ^[a-z0-9_-]+$ ]] || { echo "CAMPAIGN: a-z 0-9 _ - only"; exit 2; }
    echo "$CAND_ROOT/$1"
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
    local name=$1 src=$2 tree out status=0 cand
    shift 2
    cand=$CANDS/$(basename "$src")
    tree=$(mktemp -d)
    git -C "$ROOT" worktree add -q --detach "$tree" HEAD
    rm -rf "${tree:?}/$cand"
    mkdir -p "$tree/$cand"
    cp "$src"/*.zig "$tree/$cand/"
    out=$(ZIG_LOCAL_CACHE_DIR="$ROOT/.zig-cache" "$tree/deploy/lab-run.sh" start "$HOST" "$name" \
        --build-arg "-Dcand=$cand" --with "$tree/$cand" -- "$@") || status=$?
    git -C "$ROOT" worktree remove --force "$tree"
    echo "$out"
    return $status
}

# Waits for RUN to end; only running time counts toward the budget, not time paused or
# queued behind another run (deploy/lab-run.sh: no `started` until it holds its lock)
wait_run() {
    local run=$1 used=0 state
    while true; do
        state=$(on "cd ml/runs/$run && if [[ -f exit ]]; then echo exit; \
            elif [[ -f paused || ! -f started ]]; then echo waiting; else echo running; fi")
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
        from=$CAND_ROOT/${2:-base}
        [[ -d "$from" ]] || from=$ROOT/$CANDS/${2:-base}
        [[ -e "$dir" ]] && { echo "$dir exists"; exit 1; }
        mkdir -p "$dir"
        cp "$from"/*.zig "$dir/"
        printf '# %s digest\n\nWhat worked, what did not, by run id; then ideas.\n' "$1" \
            > "$dir/digest.md"
        printf 'id\tstatus\truns\thypothesis\n' > "$dir/hypotheses.tsv"
        echo "$dir from $from"
        ;;
    run)
        (( $# >= 3 )) || usage
        campaign=$1 name=$2 target=$3
        shift 3
        dir=$(campaign_dir "$campaign")
        [[ -f "$dir/root.zig" ]] || { echo "no $dir/root.zig: deploy/lab-exp.sh new"; exit 1; }
        guard "$dir"
        [[ -z "$MAX_RUNS" ]] || done_runs=$(on "awk -F '\t' '\$2 == \"$campaign\"' $LAB/runs.tsv 2>/dev/null | wc -l")
        if [[ -n "$MAX_RUNS" ]] && (( done_runs >= MAX_RUNS )); then
            echo "campaign $campaign has used its $MAX_RUNS runs (LAB_MAX_RUNS): stop and report"
            exit 4
        fi
        extra=()
        while (( $# )); do
            case "$1" in
                --select) extra+=(--select) ;;
                --fraction|--hyp) extra+=("$1" "$(printf '%q' "$2")"); shift ;;
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
            echo "NEXT: $ROOT/deploy/lab-exp.sh finding $campaign $run \"<what it learnt about the game, human units>\"" \
                "[effects-....tsv]  (docs/lab-brief.md \"Findings\")"
            # Headless agents can't take session messages: humans leave notes here
            if [[ -s "$dir/inbox.md" ]]; then
                echo "NOTE FROM THE HUMANS (shown once, kept as $(basename "$dir")/inbox-read.md):"
                cat "$dir/inbox.md"
                cat "$dir/inbox.md" >> "$dir/inbox-read.md"
                rm "$dir/inbox.md"
            fi
        else
            on "tail -n 30 ml/runs/$run/log; mkdir -p $LAB; \
                printf '%s\t%s\t%s\t-\t-\t-\t-\tcrash\t-\t-\n' '$run' '$campaign' '$target' \
                >> $LAB/runs.tsv"
            echo "RESULT run=$run crash"
            exit 1
        fi
        ;;
    screen|diagnose|preds)
        [[ "$cmd" == preds ]] && set -- "${1:-}" win
        (( $# == 2 )) || usage
        campaign=$1 target=$2
        dir=$(campaign_dir "$campaign")
        guard "$dir"
        out=$(start_clean "$campaign-$cmd" "$dir" exp "$cmd" "$SNAP_PATH" "$campaign" "$target" \
            --lab "$LAB_PATH")
        run=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
        [[ -n "$run" ]] || { echo "$out"; exit 1; }
        wait_run "$run" || true
        on "cat ml/runs/$run/log"
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
        if [[ "$HOST" == mac ]]; then cp "$HOME/$src"/*.zig "$dir/"
        else scp -q "$HOST:$src/*.zig" "$dir/"; fi
        echo "$dir now holds $2's candidate"
        ;;
    finding)
        (( $# == 3 || $# == 4 )) || usage
        campaign=$1 run=$2 text=$3 effect=${4:--}
        campaign_dir "$campaign" > /dev/null
        [[ "$run" =~ ^[A-Za-z0-9_.-]+$ && "$run" == *"-$campaign-"* ]] \
            || { echo "$run is not a run of $campaign"; exit 2; }
        [[ "$effect" == - || "$effect" =~ ^effects-[a-z0-9_-]+\.tsv$ ]] \
            || { echo "EFFECT_FILE: an effects-<name>.tsv from the run's RESULT"; exit 2; }
        on "test -f ml/runs/$run/summary.md" || { echo "no scored run $run"; exit 1; }
        [[ "$effect" == - ]] || on "test -f ml/runs/$run/$effect" \
            || { echo "$run has no $effect (see effects= in its RESULT)"; exit 1; }
        text=${text//$'\t'/ }
        text=${text//$'\n'/ }
        on "f=ml/runs/$run/findings.tsv; [[ -f \$f ]] || printf 'campaign\tfinding\teffect_file\n' > \$f; \
            printf '%s\t%s\t%s\n' '$campaign' $(printf '%q' "$text") '$effect' >> \$f"
        echo "finding recorded for $run"
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
        dir=$ROOT/$CANDS/_final/$campaign
        for run in $runs; do
            rm -rf "${dir:?}"
            mkdir -p "$dir"
            if [[ "$HOST" == mac ]]; then cp "$HOME/ml/runs/$run/$campaign"/*.zig "$dir/"
            else scp -q "$HOST:ml/runs/$run/$campaign/*.zig" "$dir/"; fi
            out=$(start_clean "final-$campaign" "$dir" exp final "$SNAP_PATH" "$campaign" "$target" --lab "$LAB_PATH" --run "$run")
            frun=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
            wait_run "$frun" || true
            on "cat ml/runs/$frun/log"
        done
        ;;
    *) usage ;;
esac
