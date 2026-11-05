#!/usr/bin/env bash
# One zig build (the pre-push ci) on the box, run detached in ~/meiolol-ci/jobs/ID (own
# process group, outlives ssh). deploy/remote-build.sh --host box sends it with each
# build (sha, args), so only the tools need installing (deploy/box-ci.sh install).
# Production first: one build at a time, in a user scope capped at 10 cores and 12 GB,
# nice 10 (ionice is moot: the disks' scheduler is none, and the user cgroup has no io
# controller). One fixed tree ~/meiolol-ci/tree: zig's cache is keyed by path.
# Each run appends a line to ~/meiolol-ci/runs.tsv (deploy/box-ci.sh runs).
# exit: the build's code, 75 when not built here (no tools, waited 15 min for the
# running build, disk short, stopped): the Mac builds it instead
set -u
jd=$(cd "$(dirname "$0")" && pwd) || exit 1
cd "$jd" || exit 1
c=$HOME/meiolol-ci
id=${jd##*/}
echo $$ > job.pid
ps -o pgid= $$ | tr -d ' ' > job.pgid
finish() {
    echo "$1" > "$jd/exit.tmp" && mv "$jd/exit.tmp" "$jd/exit"
    git -C "$c/repo.git" update-ref -d "refs/heads/job-$id" 2> /dev/null
    exit "$1"
}
say() { echo "remote-build: $*"; }
export PATH=$c/tools/bin:$PATH ZIG_GLOBAL_CACHE_DIR=$c/global
trap 'say "stopped"; finish 75' TERM
for t in zig node shellcheck git; do
    command -v $t > /dev/null || { say "no $t on the box (deploy/box-ci.sh install)"; finish 75; }
done

exec 9>> "$c/lock"
if ! flock -n 9; then
    say "waiting for the box's running build"
    flock -w 900 9 || { say "the box's build still running after 15 min"; finish 75; }
fi
echo 0 > slot

# Cache all or nothing past 5 GB (zig-cache-prune.sh's why); / keeps 3 GB beside a run
gb() { echo $(($1 / 1048576)); }
kb=$(du -sk "$c/cache" 2> /dev/null | cut -f1)
if (( ${kb:-0} > 5 * 1048576 )); then
    old=$(mktemp -d "$c/prune.XXXXXX")
    for d in o h z tmp; do [[ -e $c/cache/$d ]] && mv "$c/cache/$d" "$old/"; done
    rm -rf "$old"
    say "cache past 5 GB ($(gb "$kb") GB): emptied, this build is cold"
fi
free=$(df -k --output=avail / | tail -n 1)
(( free > 3 * 1048576 )) || { say "only $(gb "$free") GB free on /"; finish 75; }

tree=$c/tree
sha=$(cat sha)
if [[ ! -e $tree/.git ]]; then
    rm -rf "$tree"
    git -C "$c/repo.git" worktree prune
    git -C "$c/repo.git" worktree add -q --detach "$tree" "$sha" || finish 1
fi
git -C "$tree" checkout -q --force --detach "$sha" && git -C "$tree" clean -qfd || finish 1

mapfile -d '' args < args
say "box: zig $(zig version), shellcheck $(shellcheck --version | awk '/^version/ { print $2 }')," \
    "node $(node --version), $(git --version)"

# Production's share while it runs: pressure "some" totals (µs) of the crawler and the
# web loop, and every 15 s whether a site round is on (the loop is bash and its sleep)
app=/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service/app.slice
tot() { awk '/^some/ { sub("total=", "", $5); print $5 }' "$app/$1.service/$2.pressure" 2> /dev/null || echo 0; }
avg300() { awk '/^some/ { sub("avg300=", "", $4); print $4 }' "$app/$1.service/$2.pressure" 2> /dev/null || echo 0; }
p0=() p300=()
for u in crawl web; do for r in io cpu; do
    p0+=("$(tot "meiolol-$u" $r)") p300+=("$(avg300 "meiolol-$u" $r)")
done; done
(
    exec 9>&-
    while :; do
        n=$(wc -l < "$app/meiolol-web.service/cgroup.procs" 2> /dev/null || echo 0)
        echo $((n > 2)) >> "$jd/web.samples"
        sleep 15
    done
) &
sampler=$!
start=$(date +%s)

cd "$tree" || finish 1
# Its own cgroup's totals, read inside before the scope goes
# shellcheck disable=SC2016 # the scope's bash expands them
systemd-run --user --scope --quiet --collect --unit "meiolol-ci-$id" \
    -p CPUQuota=1000% -p MemoryMax=12G -p MemoryHigh=10G \
    nice -n 10 bash -c 'zig build -j10 "$@"; rc=$?
        cg=/sys/fs/cgroup$(cut -d: -f3 /proc/self/cgroup)
        cat "$cg/cpu.stat" > "$0/cpu.stat"; cat "$cg/memory.peak" > "$0/memory.peak"
        exit $rc' "$jd" "${args[@]}" --cache-dir "$c/cache" &
wait $!
code=$?
end=$(date +%s)
kill "$sampler" 2> /dev/null

wall=$((end - start))
cpu=$(awk '$1 == "usage_usec" { printf "%d", $2 / 1e6 }' "$jd/cpu.stat" 2> /dev/null)
thr=$(awk '$1 == "throttled_usec" { printf "%d", $2 / 1e6 }' "$jd/cpu.stat" 2> /dev/null)
peak=$(awk '{ printf "%.1f", $1 / 1073741824 }' "$jd/memory.peak" 2> /dev/null)
# Pressure as % of the run's wall time, beside the 5 min average before it
p=() i=0
for u in crawl web; do for r in io cpu; do
    p+=("$(awk -v a="${p0[i]}" -v b="$(tot "meiolol-$u" $r)" -v w="$wall" -v before="${p300[i]}" \
        'BEGIN { printf "%s/%.1f", before, (w > 0 ? (b - a) / w / 1e4 : 0) }')")
    i=$((i + 1))
done; done
web=$(awk '{ s += $1 } END { printf "%d/%d", s, NR }' "$jd/web.samples" 2> /dev/null)
[[ -s $c/runs.tsv ]] || printf '%s\n' "start	sha	exit	wall_s	cpu_s	throttled_s	mem_peak_gb	crawl_io	crawl_cpu	web_io	web_cpu	web_round	free_gb	cache_gb	args" > "$c/runs.tsv"
printf '%s\t' "$(date -d "@$start" +%FT%T)" "${sha:0:8}" "$code" "$wall" "${cpu:-?}" "${thr:-?}" \
    "${peak:-?}" "${p[@]}" "${web:-?}" "$(gb "$(df -k --output=avail / | tail -n 1)")" \
    "$(gb "$(du -sk "$c/cache" | cut -f1)")" >> "$c/runs.tsv"
echo "${args[*]}" >> "$c/runs.tsv"
say "box: ${wall} s, ${cpu:-?} s CPU (${thr:-?} s throttled), ${peak:-?} GB peak"
finish "$code"
