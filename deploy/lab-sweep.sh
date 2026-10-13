#!/usr/bin/env bash
# Random-search sweeps of one model family (30-64 trials, research C19) on the gpu-box's
# 3080, queued on deploy/lab-run.sh's gpu lock. docs/compute.md "Sweeps"
#
#   deploy/lab-sweep.sh start SWEEP SPACE [--trials N] [--rng S] [--pack K] [--head]
#                             [--build-arg A]... [--res gpu|cpu] [--dry-run] -- CMD ARGS...
#   deploy/lab-sweep.sh status SWEEP      its jobs, as deploy/lab-run.sh status shows them
#   deploy/lab-sweep.sh table SWEEP       trials ranked by inner validation, to table.md
#   deploy/lab-sweep.sh stop SWEEP        stops its queued and running jobs
#
# start samples N trials (default 32, --rng 1) from SPACE (deploy/lab-sweep.pl says the
# format), builds meiolol-lab once and queues one lab-run job per K trials (--pack,
# default 1; K > 1 runs K processes at once, if the GPU's memory allows). --res cpu for
# nets on CPU threads (netcheck --net small or resid; only big uses the GPU). Trial tNN
# runs `meiolol-lab CMD ARGS <its flags> --out tNN` in its job's run dir, output in tNN.log;
# CMD writes tNN/folds.tsv (meiolol-f1's netcheck contract, lab-sweep.pl). State here, in
# data/sweeps/SWEEP: space, trials.tsv, jobs.tsv (job, run dir, trials), table.md
#   deploy/lab-sweep.sh start big1 big.space --trials 40 --head \
#       --build-arg -Dcand=src/lab/cand/win-ratings \
#       -- netcheck "~/ml/snaps/snap-X" --net big --seeds 1,2,3
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN=$ROOT/deploy/lab-run.sh
HOST=gpu-box

usage() {
    sed -n '5,9p' "$0"
    exit 2
}

sweep_dir() {
    [[ "$1" =~ ^[a-z0-9_-]+$ ]] || { echo "SWEEP: a-z 0-9 _ - only ($1)" >&2; exit 2; }
    echo "$ROOT/data/sweeps/$1"
}

# Run dirs of the sweep's jobs, one per line
runs() { tail -n +2 "$1/jobs.tsv" | cut -f 2; }

start() {
    local sweep=$1 space=$2 trials=32 rng=1 pack=1 dry=0 res=gpu opts=()
    shift 2
    while (( $# )); do
        case "$1" in
            --trials) trials=$2; shift ;;
            --rng) rng=$2; shift ;;
            --pack) pack=$2; shift ;;
            --res) res=$2; shift ;;
            --head) opts+=(--head) ;;
            --build-arg) opts+=(--build-arg "$2"); shift ;;
            --dry-run) dry=1 ;;
            --) shift; break ;;
            *) echo "unknown option $1"; exit 2 ;;
        esac
        shift
    done
    (( $# )) || { echo "nothing to run: give CMD ARGS after --"; exit 2; }
    # As lab-run.sh: an unquoted ~ expanded here would be this Mac's home
    local tilde="~"
    set -- "${@/#$HOME/$tilde}"
    [[ "$pack" =~ ^[1-9][0-9]*$ ]] || { echo "--pack: a number"; exit 2; }
    [[ "$res" == gpu || "$res" == cpu ]] || { echo "--res: gpu or cpu"; exit 2; }
    local dir
    dir=$(sweep_dir "$sweep")
    [[ -e "$dir" ]] && (( ! dry )) && { echo "$dir exists: another SWEEP name"; exit 1; }
    local plan
    plan=$(perl "$ROOT/deploy/lab-sweep.pl" sample "$space" "$trials" "$rng") || exit 2

    # One job's ARGS per line: its trials, each `CMD ARGS flags --out tNN > tNN.log 2>&1`,
    # joined by `&` when packed (lab-run.sh puts `nice -n 10 ./meiolol-lab` before the
    # first; the others get it here)
    local flags line t v i jobs=() names=() job="" ids="" n=0
    IFS=$'\t' read -ra flags <<< "$(head -n 1 <<< "$plan")"
    while IFS=$'\t' read -ra line; do
        t=${line[0]}
        v="$* "
        for (( i = 1; i < ${#line[@]}; i++ )); do v+="${flags[i]} ${line[i]} "; done
        v+="--out $t > $t.log 2>&1"
        if [[ -z "$job" ]]; then job=$v; else job+=" & nice -n 10 ./meiolol-lab $v"; fi
        ids+="${ids:+,}$t"
        n=$((n + 1))
        if (( n == pack )); then
            (( pack > 1 )) && job+=" & wait"
            jobs+=("$job"); names+=("$ids"); job="" ids="" n=0
        fi
    done < <(tail -n +2 <<< "$plan")
    if [[ -n "$job" ]]; then
        (( pack > 1 )) && job+=" & wait"
        jobs+=("$job"); names+=("$ids")
    fi

    if (( dry )); then
        column -t -s $'\t' <<< "$plan"
        echo "${#jobs[@]} jobs on $HOST/$res, the first:"
        echo "  $(cut -c1-300 <<< "${jobs[0]}")"
        "$RUN" start "$HOST" "$sweep-j01" --res "$res" --no-build --dry-run \
            -- "${jobs[0]}" || true
        return
    fi

    mkdir -p "$dir"
    cp "$space" "$dir/space"
    echo "$plan" > "$dir/trials.tsv"
    printf 'job\trun\ttrials\tcmd\n' > "$dir/jobs.tsv"
    local k out run build=()
    for (( k = 0; k < ${#jobs[@]}; k++ )); do
        # Built once; the rest reuse that binary (lab-run.sh copies it into each run dir)
        (( k == 0 )) || build=(--no-build)
        out=$("$RUN" start "$HOST" "$sweep-j$(printf %02d $((k + 1)))" --res "$res" \
            ${opts[@]+"${opts[@]}"} ${build[@]+"${build[@]}"} -- "${jobs[k]}") \
            || { echo "$out"; exit 1; }
        run=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
        [[ -n "$run" ]] || { echo "$out"; exit 1; }
        (( k == 0 )) && grep '^predicted' <<< "$out" || true
        printf 'j%02d\t%s\t%s\t%s\n' $((k + 1)) "$run" "${names[k]}" "$*" >> "$dir/jobs.tsv"
        echo "queued $run (${names[k]})"
    done
    echo "${#jobs[@]} jobs queued on $HOST/$res; deploy/lab-sweep.sh status|table $sweep"
}

status() {
    local dir=$1
    "$RUN" status "$HOST" | grep -F -f <(runs "$dir") || echo "no jobs listed"
}

table() {
    local dir=$1 script="" run t f
    # tNN<tab>line for each line of each trial's folds.tsv
    while IFS=$'\t' read -r _ run ids _; do
        for t in ${ids//,/ }; do
            f=ml/runs/$run/$t/folds.tsv
            script+="[[ -f $f ]] && sed 's/^/$t\t/' $f
"
        done
    done < <(tail -n +2 "$dir/jobs.tsv")
    script+="true"
    # shellcheck disable=SC2029 # run dirs and trial names from our own jobs.tsv
    ssh "$HOST" "$script" | perl "$ROOT/deploy/lab-sweep.pl" table "$dir/trials.tsv" \
        | tee "$dir/table.md"
}

stop() {
    local dir=$1 run
    for run in $("$RUN" status "$HOST" | grep -F -f <(runs "$dir") \
        | awk -F ' [|] ' '$2 ~ /^(running|paused|queued)/ { print $1 }'); do
        "$RUN" stop "$HOST" "$run" && echo "stopped $run"
    done
}

cmd=${1:-}
case "$cmd" in
    start) (( $# >= 4 )) || usage; start "${@:2}" ;;
    status|table|stop)
        (( $# == 2 )) || usage
        dir=$(sweep_dir "$2")
        [[ -f "$dir/jobs.tsv" ]] || { echo "no sweep $2 (no $dir/jobs.tsv)"; exit 1; }
        "$cmd" "$dir"
        ;;
    *) usage ;;
esac
