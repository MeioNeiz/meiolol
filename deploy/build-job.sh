#!/usr/bin/env bash
# One zig build on the gpu-box, run detached in its job dir ~/ml/build/jobs/ID (own
# process group, outlives ssh). deploy/remote-build.sh sends it each time with the job's
# inputs (sha, args, patch, untracked.tar), so the gpu-box needs no install for it.
# Steps: League check, a build slot (~/ml/locks/build.K, build.slots of them, default
# 2; 60 s at most), its fixed tree ~/ml/build/tree.K (a worktree of repo.git: zig's
# cache is keyed by path, so a tree per slot stays warm) at sha plus the patch and
# untracked files, then `zig build ARGS` at nice 0, ahead of lab runs.
# exit: the build's code, 75 when not built here (League, no slot, preempted: the
# watcher, deploy/lab-watch.sh, ends builds while League is up)
set -u
jd=$(cd "$(dirname "$0")" && pwd) || exit 1
cd "$jd" || exit 1
b=~/ml/build
echo $$ > job.pid
ps -o pgid= $$ | tr -d ' ' > job.pgid
finish() {
    echo "$1" > "$jd/exit.tmp" && mv "$jd/exit.tmp" "$jd/exit"
    git -C "$b/repo.git" update-ref -d "refs/heads/job-${jd##*/}" 2> /dev/null
    exit "$1"
}
say() { echo "remote-build: $*"; }
# zig, and node (deploy/gpu-box.sh install)
export PATH=$HOME/.local/bin:$PATH
trap 'touch "$jd/preempted"; say "ended here (League up, or stopped)"; finish 75' TERM

out=$(/mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null) \
    || { say "can't ask Windows whether League is up"; finish 75; }
if grep -qiE '^"(LeagueClient|League of Legends)\.exe"' <<< "$out"; then
    say "League is up"
    finish 75
fi

mkdir -p ~/ml/locks
n=$(cat ~/ml/locks/build.slots 2> /dev/null || echo 2)
k=''
for _ in $(seq 60); do
    for ((i = 0; i < n; i++)); do
        exec 9>> ~/ml/locks/build.$i
        if flock -n 9; then k=$i; break 2; fi
        exec 9>&-
    done
    sleep 1
done
[[ -n $k ]] || { say "no free build slot in 60 s"; finish 75; }
echo "$k" > slot

tree=$b/tree.$k
sha=$(cat sha)
if [[ ! -e $tree/.git ]]; then
    rm -rf "$tree"
    git -C "$b/repo.git" worktree prune
    git -C "$b/repo.git" worktree add -q --detach "$tree" "$sha" || finish 1
    # zig-pkg: zig 0.17 unpacks fetched packages into the build root; lab-run's tree
    # has most of them
    [[ -d ~/ml/lab-build/tree.0/zig-pkg ]] && cp -a ~/ml/lab-build/tree.0/zig-pkg "$tree/"
fi
git -C "$tree" checkout -q --force --detach "$sha" && git -C "$tree" clean -qfd || finish 1
if [[ -s patch ]]; then git -C "$tree" apply --binary --whitespace=nowarn "$jd/patch" || finish 1; fi
if [[ -s untracked.tar ]]; then tar -x -C "$tree" -f untracked.tar || finish 1; fi

mapfile -d '' args < args
if [[ " ${args[*]} " == *" ci "* ]]; then
    say "tools: shellcheck $(shellcheck --version 2> /dev/null | awk '/^version/ { print $2 }'), node" \
        "$(node --version 2> /dev/null), zstd $(zstd --version 2> /dev/null | grep -o 'v[0-9.]*')," \
        "jq $(jq --version 2> /dev/null), $(gzip --version | head -1)"
fi
cd "$tree" || finish 1
nice -n 0 zig build "${args[@]}" --cache-dir "$b/cache" &
wait $!
code=$?
[[ -f $jd/preempted ]] && code=75
finish "$code"
