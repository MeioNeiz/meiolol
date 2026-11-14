#!/usr/bin/env bash
# On the gpu-box, nightly (systemd user timer meiolol-fuzz; deploy/gpu-box.sh install):
# deploy/backend-fuzz.sh over origin main, as a run in ~/ml/runs named
# <UTC start>-backend-fuzz, so deploy/lab-watch.sh pauses it while League is open and
# keeps Windows awake while it runs, and the admin Training tab lists it (RESULT line).
# Its own clone, ~/ml/fuzz/meiolol: the corpus stays in that clone's build tree between
# nights. A crash's input is kept in the run dir (crash-N, the FAILED line names it).
# Outcome in ~/ml/fuzz/last, "TIME SHA ok|fail|error RUN", which each archive pull sends
# to the box's health check (deploy/archive-pull.sh, docs/health.md).
#   fuzz-nightly.sh     start tonight's run (the timer). As RUN/job.sh: the run itself,
#                       which lab-watch.sh starts again after a WSL restart
# Env: FUZZ_INPUTS per fuzz test (default 300K), FUZZ_ORIGIN (the GitHub repo)
set -uo pipefail
inputs=${FUZZ_INPUTS:-300K}
origin=${FUZZ_ORIGIN:-https://github.com/MeioNeiz/meiolol.git}
base=$HOME/ml/fuzz
repo=$base/meiolol

if [[ ${0##*/} != job.sh ]]; then
    run=$HOME/ml/runs/$(date -u +%Y%m%dT%H%M%SZ)-backend-fuzz
    mkdir -p "$run" || exit 1
    cp "$0" "$run/job.sh" || exit 1
    printf 'host gpu-box\nargs backend-fuzz --fuzz %s\nres none\n' "$inputs" > "$run/meta"
    exec "$run/job.sh"
fi

cd "$(dirname "$0")" || exit 1
run=$PWD
# Its own group (systemd's session, or lab-watch's restart): the watcher stops it whole
ps -o pgid= $$ | tr -d ' ' > job.pgid
exec >> log 2>&1
mkdir -p "$base"
exec 9> "$base/.lock"
if ! flock -n 9; then
    echo "another backend fuzz run is live"
    cd && rm -rf "$run"
    exit 0
fi
date -u +%FT%TZ > "$run/started"
sha=-
end() {
    echo "RESULT backend-fuzz ${sha:0:7}: $2"
    echo "$(date +%s) ${sha:0:12} $1 ${run##*/}" > "$base/last.tmp" && mv "$base/last.tmp" "$base/last"
    date -u +%FT%TZ > "$run/ended"
    [[ $1 == ok ]] && rc=0 || rc=1
    echo "$rc" > "$run/exit"
    exit "$rc"
}
if [[ ! -d $repo/.git ]]; then
    GIT_TERMINAL_PROMPT=0 git clone -q "$origin" "$repo" || end error "clone of $origin failed"
fi
GIT_TERMINAL_PROMPT=0 git -C "$repo" fetch -q origin main || end error "fetch failed"
sha=$(git -C "$repo" rev-parse FETCH_HEAD) || end error "no FETCH_HEAD"
git -C "$repo" checkout -q --force --detach "$sha" || end error "checkout failed"
echo "head $sha" >> meta
# backend-fuzz.sh builds in a clean tree of the sha (build-tree.sh), one test at a time
"$repo/deploy/backend-fuzz.sh" "$sha" --fuzz "$inputs" -j 4 --keep "$run"
case $? in
    0) end ok "no crash, $(grep -c '^ok ' log) fuzz tests of $inputs inputs" ;;
    *)
        failed=$(grep -c '^backend-fuzz: FAILED' log)
        if (( failed > 0 )); then end fail "$failed fuzz tests FAILED (crash-N inputs here)"
        else end error "backend-fuzz.sh failed before fuzzing"; fi
        ;;
esac
