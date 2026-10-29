#!/usr/bin/env bash
# A zig build on the gpu-box that looks local: the output streams back with the gpu-box
# tree's paths turned into this checkout's, and the exit code is the build's. Inputs:
# HEAD's commit plus the working tree's changes (a patch and the untracked files, as a
# local build sees them), or a commit alone. deploy/build-job.sh runs it there; where
# builds go and why: deploy/place.sh, docs/compute.md "Builds on the gpu-box".
#   deploy/remote-build.sh [--commit REV] ZIG_BUILD_ARGS...
# Exit 75: not built there (gpu-box off, asleep or unreachable, League up, no build slot
# in 60 s, lost for 30 s mid-build): build it on the Mac instead
set -uo pipefail
HOST=${GPU_HOST:-gpu-box}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
. "$ROOT/deploy/place.sh"

rev=''
if [[ ${1-} == --commit ]]; then
    rev=$(git -C "$ROOT" rev-parse --verify -q "${2-}^{commit}") || { echo "remote-build: no commit ${2-}" >&2; exit 2; }
    shift 2
fi
(( $# )) || { usage_of "$0" >&2; exit 2; }
fail() { echo "remote-build: $*: build it on the Mac" >&2; exit 75; }
[[ -f $PLACE_OFF ]] && fail "gpu-box builds are off (deploy/place.sh on)"

id=$(date -u +%Y%m%dT%H%M%SZ)-$$
jd=ml/build/jobs/$id
in=$(mktemp -d)
pid='' done=''
cleanup() {
    rm -rf "$in"
    # Ctrl-C or zb.sh giving up: the build there stops too
    [[ -n $pid && -z $done ]] && gpu "kill -TERM -- -$pid 2> /dev/null"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

cp "$ROOT/deploy/build-job.sh" "$in/job.sh"
printf '%s\0' "$@" > "$in/args"
if [[ -n $rev ]]; then
    echo "$rev" > "$in/sha"
else
    git -C "$ROOT" rev-parse HEAD > "$in/sha"
    git -C "$ROOT" diff --binary HEAD > "$in/patch"
    (cd "$ROOT" && git ls-files -o --exclude-standard -z | tar --no-mac-metadata --no-xattrs --null -T - -cf "$in/untracked.tar")
fi
gpu "mkdir -p $jd ml/build/cache && { [[ -d ml/build/repo.git ]] || git init -q --bare ml/build/repo.git; }" \
    || fail "$HOST unreachable"
git -C "$ROOT" push -q -f "$HOST:ml/build/repo.git" "$(cat "$in/sha"):refs/heads/job-$id" \
    || fail "git push to $HOST failed"
# setsid: its own session and process group (pgid = pid), so it outlives this ssh
pid=$(tar --no-mac-metadata --no-xattrs -C "$in" -cf - . \
    | gpu "tar -x -C $jd && cd $jd && { setsid nohup bash job.sh > log 2>&1 < /dev/null & echo \$!; }")
[[ -n $pid ]] || fail "$HOST: job didn't start"

# Follow the log from the last byte shown; a dropped ssh (sleep, WSL restart, network)
# gets 30 s to come back. Shown with the tree's paths turned into this checkout's
rtree=$(gpu 'echo ~/ml/build/tree.')
show() {
    perl -e '$| = 1; my ($from, $to, $countf) = @ARGV; my $n = 0;
        while (<STDIN>) { $n += length; s/\Q$from\E\d+/$to/g; print }
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
