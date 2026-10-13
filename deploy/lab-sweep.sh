#!/usr/bin/env bash
# Random-search sweeps of one model family (30-64 trials, research C19) on the gpu-box's
# 3080, queued on deploy/lab-run.sh's gpu lock. docs/compute.md "Sweeps"
#
#   deploy/lab-sweep.sh start SWEEP SPACE [--trials N] [--rng S] [--pack K] [--serial]
#                             [--head | --commit SHA] [--build-arg A]... [--res gpu|cpu]
#                             [--skip N] [--dry-run] -- CMD ARGS...
#   deploy/lab-sweep.sh status SWEEP      its jobs, as deploy/lab-run.sh status shows them
#   deploy/lab-sweep.sh table SWEEP       trials ranked by inner validation, to table.md
#   deploy/lab-sweep.sh stop SWEEP        stops its queued and running jobs
#
# start samples N trials (default 32, --rng 1) from SPACE (deploy/lab-sweep.pl says the
# format), builds meiolol-lab once and queues one lab-run job per K trials (--pack,
# default 1; K > 1 runs K processes at once, if the GPU's memory allows; --serial runs
# them one after another, so a CPU sweep holds few slots). --res cpu for
# nets on CPU threads (netcheck --net small or resid; only big uses the GPU). Trial tNN
# runs `meiolol-lab CMD ARGS <its flags> --out tNN` in its job's run dir, output in tNN.log;
# CMD writes tNN/folds.tsv (meiolol-f1's netcheck contract, lab-sweep.pl). State here, in
# data/sweeps/SWEEP: space, trials.tsv, jobs.tsv (job, run dir, trials), table.md
# --skip N: a start cut short after queuing jobs 1..N (jobs.tsv lists what it recorded):
# the rest, with the same SPACE, --trials and --rng
#   deploy/lab-sweep.sh start big1 big.space --trials 40 --head \
#       --build-arg -Dcand=src/lab/cand/win-ratings \
#       -- netcheck "~/ml/snaps/snap-X" --net big --seeds 1,2,3
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUN=$ROOT/deploy/lab-run.sh
HOST=gpu-box

usage() {
    sed -n '5,10p' "$0"
    exit 2
}

sweep_dir() {
    [[ "$1" =~ ^[a-z0-9_-]+$ ]] || { echo "SWEEP: a-z 0-9 _ - only ($1)" >&2; exit 2; }
    echo "$ROOT/data/sweeps/$1"
}

# Run dirs of the sweep's jobs, one per line
runs() { tail -n +2 "$1/jobs.tsv" | cut -f 2; }

start() {
    local sweep=$1 space=$2 trials=32 rng=1 pack=1 dry=0 res=gpu skip=0 serial=0 opts=()
    shift 2
    while (( $# )); do
        case "$1" in
            --trials) trials=$2; shift ;;
            --rng) rng=$2; shift ;;
            --pack) pack=$2; shift ;;
            --res) res=$2; shift ;;
            --serial) serial=1 ;;
            --head) opts+=(--head) ;;
            --commit) opts+=(--commit "$2"); shift ;;
            --build-arg) opts+=(--build-arg "$2"); shift ;;
            --dry-run) dry=1 ;;
            --skip) skip=$2; shift ;;
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
    [[ "$skip" =~ ^[0-9]+$ ]] || { echo "--skip: a number"; exit 2; }
    if (( skip )); then
        [[ -f "$dir/jobs.tsv" ]] || { echo "--skip: no $dir/jobs.tsv to add to"; exit 1; }
    elif [[ -e "$dir" ]] && (( ! dry )); then
        echo "$dir exists: another SWEEP name"; exit 1
    fi
    local plan
    plan=$(perl "$ROOT/deploy/lab-sweep.pl" sample "$space" "$trials" "$rng") || exit 2

    # One job's ARGS per line: its trials, each `CMD ARGS flags --out tNN > tNN.log 2>&1`,
    # joined by `&` when packed, `;` when --serial (lab-run.sh puts `$pin nice -n 10
    # ./meiolol-lab` before the first; the others get it here, $pin left for job.sh to
    # expand: its slot's taskset, else they'd float over every core)
    local sep='&'
    (( serial )) && sep=';'
    local flags line t v i jobs=() names=() job="" ids="" n=0
    IFS=$'\t' read -ra flags <<< "$(head -n 1 <<< "$plan")"
    while IFS=$'\t' read -ra line; do
        t=${line[0]}
        v="$* "
        for (( i = 1; i < ${#line[@]}; i++ )); do v+="${flags[i]} ${line[i]} "; done
        v+="--out $t > $t.log 2>&1"
        # shellcheck disable=SC2016 # $pin expands in job.sh
        if [[ -z "$job" ]]; then job=$v
        else job+=" $sep "'$pin '"nice -n 10 ./meiolol-lab $v"; fi
        ids+="${ids:+,}$t"
        n=$((n + 1))
        if (( n == pack )); then
            (( pack > 1 && ! serial )) && job+=" & wait"
            jobs+=("$job"); names+=("$ids"); job="" ids="" n=0
        fi
    done < <(tail -n +2 <<< "$plan")
    if [[ -n "$job" ]]; then
        (( pack > 1 && ! serial )) && job+=" & wait"
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

    if (( skip )); then
        # Same SPACE, --trials and --rng sample the same trials: anything else is a new sweep
        [[ "$plan" == "$(cat "$dir/trials.tsv")" ]] \
            || { echo "--skip: these trials differ from $dir/trials.tsv"; exit 1; }
    else
        mkdir -p "$dir"
        cp "$space" "$dir/space"
        echo "$plan" > "$dir/trials.tsv"
        printf 'job\trun\ttrials\tcmd\n' > "$dir/jobs.tsv"
    fi
    local k out run key o kept
    for (( k = skip; k < ${#jobs[@]}; k++ )); do
        # Built once; the rest start that binary by its store key, whatever the tree
        # holds by then (lab-run.sh copies it into each run dir)
        if (( k == skip + 1 )); then
            key=$(sed -n 's/^binary \([0-9a-f]*\)$/\1/p' <<< "$out")
            [[ -n "$key" ]] || { echo "no binary key from the first start"; exit 1; }
            kept=()
            # --head and --commit SHA built the binary: the rest start it by its key
            local skip_next=0
            for o in ${opts[@]+"${opts[@]}"}; do
                if (( skip_next )); then skip_next=0; continue; fi
                [[ "$o" == --commit ]] && { skip_next=1; continue; }
                [[ "$o" == --head ]] || kept+=("$o")
            done
            opts=(${kept[@]+"${kept[@]}"} --bin "$key")
        fi
        out=$("$RUN" start "$HOST" "$sweep-j$(printf %02d $((k + 1)))" --res "$res" \
            ${opts[@]+"${opts[@]}"} -- "${jobs[k]}") \
            || { echo "$out"; exit 1; }
        run=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
        [[ -n "$run" ]] || { echo "$out"; exit 1; }
        (( k == skip )) && grep '^predicted' <<< "$out" || true
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
