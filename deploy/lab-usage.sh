#!/usr/bin/env bash
# What a lab-run run used of its slot (deploy/lab-run.sh copies this into the run dir as
# usage.sh; job.sh runs it there).
#   usage.sh sample PGID      every 5 s until killed: the job's runnable threads, the
#                             card's busy % and the job's resident memory (KiB), one
#                             line each to usage.samples
#   usage.sh summary T0 CORES after the job: `usage` (key value lines) and a USAGE line
#                             for the log
# CPU is the job's CPU seconds (bash `times` in job.sh, so `times`) over its active wall
# time (pauses for League taken out) and its slot's cores. Runnable threads per core well
# over 1 means the job oversubscribes its slot (process pools that each take the whole
# OMP_NUM_THREADS); well under 1, cores idle. The card's % is the whole GPU, shared with
# the other gpu slot's run. Memory sums the group's RSS: forked pool workers' shared pages
# count once each, so an upper bound
set -u

sample() {
    local g=$1 smi=/usr/lib/wsl/lib/nvidia-smi gpu
    [[ -x $smi ]] || smi=$(command -v nvidia-smi || true)
    while sleep 5; do
        gpu=-
        [[ -n $smi ]] && gpu=$($smi --query-gpu=utilization.gpu \
            --format=csv,noheader,nounits 2> /dev/null | head -n 1)
        # The sampler shares the job's process group: its own tools don't count
        printf '%s\t%s\t%s\n' "$(ps -eLo pgid=,stat=,comm= | awk -v g="$g" '
            $1 == g && $2 ~ /^R/ && $3 !~ /^(ps|awk|sleep|nvidia-smi|head|bash)$/ { n++ }
            END { print n + 0 }')" "${gpu:--}" \
            "$(ps -eo pgid=,rss= | awk -v g="$g" '$1 == g { k += $2 }
                END { print k + 0 }')"
    done >> usage.samples
}

# Seconds from bash's `times` output: its second line is children's user and system time
cpu_seconds() {
    sed -n 2p times 2> /dev/null | tr 'ms' '  ' \
        | awk '{ print $1 * 60 + $2 + $3 * 60 + $4 }'
}

# Paused seconds since T0 from the watcher's STOP/CONT pairs (pauses.log); a pause still
# open at the end runs to now
paused_seconds() {
    local t0=$1 total=0 stop='' t w s
    [[ -f pauses.log ]] || { echo 0; return; }
    while read -r t w; do
        s=$(date -d "$t" +%s 2> /dev/null) || continue
        (( s >= t0 )) || continue
        if [[ $w == STOP ]]; then stop=$s
        elif [[ $w == CONT && -n $stop ]]; then total=$(( total + s - stop )); stop=''; fi
    done < pauses.log
    [[ -n $stop ]] && total=$(( total + $(date +%s) - stop ))
    echo $total
}

summary() {
    local t0=$1 cores=${2:-} now active cpu f=usage.samples
    [[ $cores =~ ^[0-9]+$ ]] && (( cores > 0 )) || cores=$(getconf _NPROCESSORS_ONLN)
    now=$(date +%s)
    active=$(( now - t0 - $(paused_seconds "$t0") ))
    (( active > 0 )) || active=1
    cpu=$(cpu_seconds)
    [[ -f $f ]] || f=/dev/null
    awk -F '\t' -v cores="$cores" -v active="$active" -v cpu="${cpu:-0}" '
        { n++; run += $1; if ($2 != "-" && $2 != "") { g++; gpu += $2 }
          if ($3 > rss) rss = $3 }
        END {
            used = cpu / active
            f = "usage"
            printf "cores %d\nactive_s %d\ncpu_s %.1f\n", cores, active, cpu > f
            printf "cpu_cores %.2f\n", used > f
            rpc = n ? sprintf("%.2f", run / n / cores) : "-"
            printf "runnable_per_core %s\n", rpc > f
            printf "gpu_pct %s\nsamples %d\n", g ? sprintf("%.0f", gpu / g) : "-", n > f
            printf "peak_rss_gb %s\n", rss ? sprintf("%.1f", rss / 1048576) : "-" > f
            line = sprintf("USAGE cpu %.1f of %d cores over %d s", used, cores, active)
            if (n) {
                r = run / n / cores
                line = line sprintf(", %.1f runnable threads per core", r)
                if (r > 1.5) line = line " (oversubscribed)"
            }
            if (g) line = line sprintf(", card %.0f%% busy", gpu / g)
            if (rss) line = line sprintf(", peak %.1f GB", rss / 1048576)
            print line
        }' "$f"
}

case ${1:-} in
    sample) sample "$2" ;;
    summary) summary "$2" "${3:-}" ;;
    *) echo "usage: usage.sh sample PGID | summary T0 [CORES]" >&2; exit 2 ;;
esac
