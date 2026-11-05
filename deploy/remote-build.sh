#!/usr/bin/env bash
# A zig build on the gpu-box that looks local: the output streams back with the gpu-box
# tree's paths turned into this checkout's, and the exit code is the build's. Inputs:
# HEAD's commit plus the working tree's changes (a patch and the untracked files, as a
# local build sees them), or a commit alone. deploy/build-job.sh runs it there; where
# builds go and why: deploy/place.sh, docs/compute.md "Builds on the gpu-box".
# --host box: on the box instead (the pre-push ci, deploy/ci-run.sh): deploy/box-ci-job.sh
# there, one capped build at a time; docs/hosting.md "Builds on the box"
#   deploy/remote-build.sh [--host box] [--commit REV] ZIG_BUILD_ARGS...
# Exit 75: not built there (gpu-box off, asleep or unreachable, League up, no build slot
# in 60 s, lost for 30 s mid-build; box: no tools, disk short, its build busy 15 min):
# build it on the Mac instead
set -uo pipefail
box=''
if [[ ${1-} == --host ]]; then
    [[ ${2-} == box ]] || { echo "remote-build: --host box, or none for the gpu-box" >&2; exit 2; }
    box=1
    GPU_HOST=${BOX_HOST:-essex-vm}
    shift 2
fi
HOST=${GPU_HOST:-gpu-box}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
. "$ROOT/deploy/place.sh"
# Where it builds there: job dirs, the repo pushed to, the job script sent
if [[ -n $box ]]; then base=meiolol-ci job=box-ci-job.sh; else base=ml/build job=build-job.sh; fi

rev=''
if [[ ${1-} == --commit ]]; then
    rev=$(git -C "$ROOT" rev-parse --verify -q "${2-}^{commit}") || { echo "remote-build: no commit ${2-}" >&2; exit 2; }
    shift 2
fi
(( $# )) || { usage_of "$0" >&2; exit 2; }
fail() { echo "remote-build: $*: build it on the Mac" >&2; exit 75; }
[[ -z $box && -f $PLACE_OFF ]] && fail "gpu-box builds are off (deploy/place.sh on)"

id=$(date -u +%Y%m%dT%H%M%SZ)-$$
jd=$base/jobs/$id
in=$(mktemp -d)
pid='' done=''
cleanup() {
    rm -rf "$in"
    # Ctrl-C or zb.sh giving up: the build there stops too
    [[ -n $pid && -z $done ]] && gpu "kill -TERM -- -$pid 2> /dev/null"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

cp "$ROOT/deploy/$job" "$in/job.sh"
printf '%s\0' "$@" > "$in/args"
if [[ -n $rev ]]; then
    echo "$rev" > "$in/sha"
else
    git -C "$ROOT" rev-parse HEAD > "$in/sha"
    git -C "$ROOT" diff --binary HEAD > "$in/patch"
    (cd "$ROOT" && git ls-files -o --exclude-standard -z | tar --no-mac-metadata --no-xattrs --null -T - -cf "$in/untracked.tar")
fi
gpu "mkdir -p $jd $base/cache && { [[ -d $base/repo.git ]] || git init -q --bare $base/repo.git; }" \
    || fail "$HOST unreachable"
refs=("$(cat "$in/sha"):refs/heads/job-$id")
# The box's ci compares ui.wasm sizes with origin/main's (wasmsize)
[[ -n $box ]] && refs+=("$(git -C "$ROOT" rev-parse refs/remotes/origin/main):refs/remotes/origin/main")
git -C "$ROOT" push -q -f "$HOST:$base/repo.git" "${refs[@]}" \
    || fail "git push to $HOST failed"
# setsid: its own session and process group (pgid = pid), so it outlives this ssh
pid=$(tar --no-mac-metadata --no-xattrs -C "$in" -cf - . \
    | gpu "tar -x -C $jd && cd $jd && { setsid nohup bash job.sh > log 2>&1 < /dev/null & echo \$!; }")
[[ -n $pid ]] || fail "$HOST: job didn't start"

# Follow the log from the last byte shown; a dropped ssh (sleep, WSL restart, network)
# gets 30 s to come back. Shown with the tree's paths turned into this checkout's
if [[ -n $box ]]; then rtree=$(gpu 'echo ~/meiolol-ci/tree'); else rtree=$(gpu 'echo ~/ml/build/tree.'); fi
show() {
    perl -e '$| = 1; my ($from, $to, $countf) = @ARGV; my $n = 0;
        while (<STDIN>) { $n += length; s/\Q$from\E\d*/$to/g; print }
        open(my $f, ">", $countf) or die; print $f $n' "$rtree" "$ROOT" "$in/n"
}
off=0
while :; do
    gpu -o ServerAliveInterval=5 -o ServerAliveCountMax=3 \
        "tail -c +$((off + 1)) -F --pid=$pid $jd/log 2> /dev/null" | show
    rc=${PIPESTATUS[0]}
    off=$((off + $(cat "$in/n")))
    if (( rc == 255 )); then
        for _ in $(seq 10); do
            sleep 3
            gpu true && continue 2
        done
        done=1
        fail "lost $HOST for 30 s mid-build"
    fi
    if code=$(gpu "cat $jd/exit 2> /dev/null") && [[ -n $code ]]; then
        # Lines written after tail's last read
        gpu "tail -c +$((off + 1)) $jd/log" | show
        done=1
        (( code == 75 )) && fail "$HOST gave it back"
        exit "$code"
    fi
    gpu "kill -0 $pid 2> /dev/null" || { done=1; fail "the job on $HOST died (WSL restart?)"; }
done
