#!/usr/bin/env bash
# Long modelling runs on the gpu-box (i5-13600KF, RTX 3080, WSL) or this Mac, detached,
# one directory per run in ~/ml/runs on that host. Builds from the working tree, not a
# clean checkout: experiments are usually uncommitted, so each run keeps HEAD and a diff.
# On the gpu-box, deploy/lab-watch.sh pauses every run while League is open (Jacob's
# rule); `watch-install` sets it up. docs/compute.md
#
#   deploy/lab-run.sh start [HOST] NAME [--meiolol] [--head | --commit SHA | --bin KEY]
#                           [--no-build] [--build-arg A]... [--with PATH]...
#                           [--res cpu|gpu|none|auto] [--literal] [--dry-run] -- ARGS...
#   deploy/lab-run.sh start [gpu-box] NAME --python SCRIPT [--with PATH]... [--res R]
#                           -- ARGS...
#   deploy/lab-run.sh status [HOST]
#   deploy/lab-run.sh wait RUN... [--timeout S]  until each has ended: state, RESULT lines
#   deploy/lab-run.sh logs HOST RUN [LINES]
#   deploy/lab-run.sh stop HOST RUN
#   deploy/lab-run.sh restart HOST RUN       run it again in its dir (after a WSL restart)
#   deploy/lab-run.sh pull HOST RUN          results to data/runs/RUN here
#   deploy/lab-run.sh watch-install          League watcher on the gpu-box
#
# HOST: gpu-box, or auto (also when left out): host and resource by predicted
# finish, deploy/lab-place.pl (wait for the lock + run time from past runs; it says why).
# mac only with LAB_ALLOW_MAC=1 (runs slow the Mac down).
# --res auto with a named HOST picks the resource only; a named HOST without --res is cpu.
# --dry-run: the placement or prediction only. ARGS go to meiolol-lab (or meiolol with
# --meiolol), joined with spaces and run by bash in the run directory on the host, so ~
# and globs expand there:
#   deploy/lab-run.sh start smoke -- gpu-smoke
#   deploy/lab-run.sh start gpu-box eval --meiolol -- eval --data "~/ml/snaps/X" ">" eval.md
# --literal: each ARG reaches the program as one word, nothing expanded but a leading ~/
# (deploy/lab-exp.sh: its words come from an agent, so they must not run as shell).
# --head builds committed HEAD instead, --commit SHA that commit (other sessions edit the
# working tree; a half-written file there breaks or silently changes the build).
# Binaries are kept by KEY, a hash of the build's inputs (every file under src, build.zig,
# the build args and the files they name), in the host's store (gpu-box: ~/ml/lab-store/
# KEY, built there from inputs rsynced to a fixed mirror, so the Mac's CPU stays free;
# mac: zig-out/lab-run/KEY): built once per KEY under a lock on this Mac, never replaced,
# so concurrent starts share one build. A key only in the Mac's store (built before
# late 2026-10-13) is copied across instead of rebuilt. Each start prints
# `binary KEY`; --bin KEY starts that binary whatever the tree holds now (a sweep's jobs),
# --no-build the current inputs' binary if built, never a build. Meta records src KEY.
# --build-arg goes to zig build (deploy/lab-exp.sh: -Dcand=DIR); --with copies a file or
# directory into the run dir (the candidate's source, kept with its scores)
# --python SCRIPT: no build; SCRIPT and the other *.py in its directory (it may import
# them), with py/labpy.py, py/pyproject.toml and py/uv.lock, are copied into the run dir
# and SCRIPT runs there with ARGS in the shared env of py/uv.lock (~/ml/pyenv/HASH, made
# on first use). Meta: `bin python HASH` (of those *.py), pyenv HASH. Slots as for any
# run; OMP_NUM_THREADS is the slot's share of the cores, and on a gpu slot torch gets
# 0.95/N of the card's memory (N gpu slots), so jobs fit together
# Queue: a run waits for its resource's lock on the host (~/ml/locks/RES; cpu by default,
# since every run uses all cores via par.zig), so runs go one after another, not over each
# other. A GPU run takes gpu and can share the PC with a cpu one. Waiting runs are
# "queued"; `started` is written once the lock is held
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNS=ml/runs
BUILD_ARGS=()
WITH=()
RES=
DRY=0
LITERAL=0
WATCH=meiolol-lab-watch

on() {
    local host=$1
    shift
    if [[ "$host" == mac ]]; then (cd && bash -c "$*"); else ssh "$host" "$*"; fi
}

copy() {
    local host=$1 dst=$2
    shift 2
    if [[ "$host" == mac ]]; then cp -R "$@" "$HOME/$dst/"
    else scp -qr "$@" "$host:$dst/"; fi
}

check_host() {
    [[ "$1" == mac || "$1" == gpu-box ]] && return
    echo "HOST is gpu-box or mac, not $1"
    exit 2
}

# RUN goes into shell commands on the host: a run dir name only
check_run() {
    [[ "$1" =~ ^[A-Za-z0-9_.-]+$ && "$1" != *..* ]] && return
    echo "RUN: a run dir name (letters, digits, _ . -), not $1"
    exit 2
}

# Pinned zig: a plain PATH can reach Homebrew's older zig before the ~/.local/bin shim
ZIG=zig
[[ -x "$HOME/.local/bin/zig" ]] && ZIG=$HOME/.local/bin/zig
# deploy/lab-exp.sh runs this script from a temp worktree: binaries and zig's cache stay
# in the main checkout, so they outlive it
STORE=${LAB_STORE:-$ROOT/zig-out/lab-run}
CACHE=${ZIG_LOCAL_CACHE_DIR:-$ROOT/.zig-cache}
# The gpu-box's store, mirror tree (its zig-pkg stays there) and zig cache, under ~
RSTORE=ml/lab-store
RTREE=ml/lab-build/tree
RCACHE=ml/lab-build/cache
COMMIT=
PIN=
PY=

# "blob path" per build input under src, build.zig and build.zig.zon: at commit $1, else
# in directory $2 (the working tree, untracked files too)
inputs() {
    local paths=(src build.zig build.zig.zon)
    if [[ -n "$1" ]]; then
        git -C "$ROOT" ls-tree -r --format='%(objectname) %(path)' "$1" -- "${paths[@]}"
    else
        local names
        if [[ "$2" == "$ROOT" ]]; then
            names=$(cd "$ROOT" && git ls-files -co --exclude-standard -- "${paths[@]}" \
                | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done)
        else
            names=$(cd "$2" && find "${paths[@]}" -type f)
        fi
        paste -d ' ' <(cd "$2" && git -C "$ROOT" hash-object --stdin-paths \
            <<< "$(sed "s|^|$2/|" <<< "$names")") - <<< "$names"
    fi | LC_ALL=C sort -k 2
}

# The binary store key: the inputs (inputs' arguments), the build args, and the files of
# any build arg naming an absolute path (a lab agent's candidate outside the tree)
key() {
    local a v f
    {
        echo "lab-run store 1"
        inputs "$@"
        for a in ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}; do
            echo "arg $a"
            [[ "$a" == -D*=* ]] || continue
            v=${a#*=}
            [[ "$v" == /* ]] || continue
            [[ -e "$v" ]] || continue
            find "$v" -type f | LC_ALL=C sort | while IFS= read -r f; do
                echo "$(git hash-object "$f") $f"
            done
        done
    } | shasum | cut -c1-16
}

# Where `build` puts BIN for HOST in the store dir $1: `zig build lab` installs a host
# build in bin and the gpu-box one in gpu-box
binpath() {
    local dir=bin
    [[ "$3" == meiolol-lab && "$2" == gpu-box ]] && dir=gpu-box
    echo "$1/$dir/$3"
}

# zig build's arguments for BIN on HOST but --prefix, in ZARGS
zig_args() {
    local host=$1 bin=$2
    ZARGS=(-Doptimize=ReleaseFast)
    ZARGS+=(${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"})
    if [[ "$bin" == meiolol-lab && "$host" == gpu-box ]]; then
        ZARGS+=(lab-gpu-box)
    elif [[ "$bin" == meiolol-lab ]]; then
        ZARGS+=(lab-native)
    elif [[ "$host" == gpu-box ]]; then
        ZARGS+=(-Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3)
    fi
}

# Builds BIN for HOST into store dir PREFIX from the inputs in STAGE, through the host's
# mirror tree: a fixed path keeps zig's cache warm
build() {
    local host=$1 bin=$2 prefix=$3 stage=$4 a q=""
    if [[ "$host" == gpu-box ]]; then
        for a in ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}; do
            [[ "$a" != -D*=/* ]] && continue
            echo "--build-arg $a: gpu-box builds take paths inside the tree" >&2
            return 1
        done
        zig_args "$host" "$bin"
        for a in "${ZARGS[@]}"; do q+=" $(printf '%q' "$a")"; done
        on gpu-box "mkdir -p $RTREE $RCACHE" || return 1
        # zig-pkg: zig 0.17 keeps fetched packages (sqlite, translate-c) in the build
        # root; the mirror's stays, so they are fetched once
        rsync -a --delete --checksum --exclude /zig-pkg "$stage/" "gpu-box:$RTREE/" || return 1
        # Runs' niceness: at 19 a build starved behind 8 runs (2.5 min)
        on gpu-box "cd $RTREE && nice -n 10 ~/.local/bin/zig build --prefix ~/$prefix$q" \
            "--cache-dir ~/$RCACHE" >&2
        return
    fi
    # A fresh tree per build unpacked all of zig-pkg again (~560 MB, minutes): the mirror
    # links the main checkout's, also when ROOT is deploy/lab-exp.sh's temp worktree
    local pkg
    pkg=$(dirname "$(git -C "$ROOT" rev-parse --path-format=absolute \
        --git-common-dir)")/zig-pkg
    mkdir -p "$STORE/tree"
    [[ -L "$STORE/tree/zig-pkg" ]] || rm -rf "$STORE/tree/zig-pkg"
    ln -sfn "$pkg" "$STORE/tree/zig-pkg"
    rsync -a --delete --checksum --exclude /zig-pkg "$stage/" "$STORE/tree/"
    zig_args "$host" "$bin"
    (cd "$STORE/tree" && "$ZIG" build --prefix "$prefix" "${ZARGS[@]}" --cache-dir "$CACHE" >&2)
}

# Holds an exclusive lock on file $1 on fd 8 until `exec 8>&-` (perl: the Mac has no
# flock(1); the lock lives on the shared open file, so it outlasts perl)
lock8() {
    exec 8>> "$1"
    perl -MFcntl=:flock -e 'open(my $f, q{>&=}, 8) or die; flock($f, LOCK_EX) or die'
}

# The store dir of KEY's BIN on HOST; the gpu-box's relative to its ~
storedir() {
    if [[ "$1" == gpu-box ]]; then echo "$RSTORE/$3/$1-$2"; else echo "$STORE/$3/$1-$2"; fi
}

# Whether store dir DIR on HOST holds a finished build
built() {
    if [[ "$1" == gpu-box ]]; then on gpu-box "[[ -f $2/done ]]"; else [[ -f "$2/done" ]]; fi
}

# Copies KEY's BIN for the gpu-box from this Mac's store (built here before builds moved
# to the gpu-box), if it is there
carry() {
    local old=$STORE/$3/$1-$2 dir
    [[ "$1" == gpu-box && -f "$old/done" ]] || return 1
    dir=$(storedir "$1" "$2" "$3")
    echo "copying $3 for $1 $2 from this Mac's store" >&2
    on gpu-box "mkdir -p $RSTORE/$3 && rm -rf $dir.part" && scp -qr "$old" "gpu-box:$dir.part" \
        && on gpu-box "mv $dir.part $dir"
}

# Prints the store dir holding BIN for HOST built from the inputs keyed KEY (from commit
# COMMIT, else the working tree), building it unless BUILD is 0. Builds take a lock on
# this Mac: the inputs are copied to a stage first and keyed there, so a file another
# session saves mid-build can't make a binary that matches no key. A finished dir has
# `done` and is never written again. The key printed can differ from KEY when the tree
# moved on since
ensure() {
    local host=$1 bin=$2 key=$3 commit=$4 build=$5 dir stage harness
    dir=$(storedir "$host" "$bin" "$key")
    if ! built "$host" "$dir"; then
        mkdir -p "$STORE"
        # A lock per host: gpu-box builds don't queue behind the Mac's
        if [[ "$host" == gpu-box ]]; then lock8 "$STORE/build-gpu-box.lock"
        else lock8 "$STORE/build.lock"; fi
        if ! built "$host" "$dir" && ! carry "$host" "$bin" "$key"; then
            if (( ! build )); then
                exec 8>&-
                echo "no binary $key for $host $bin: start once without --no-build/--bin" >&2
                return 1
            fi
            stage=$(mktemp -d)
            if [[ -n "$commit" ]]; then
                git -C "$ROOT" archive "$commit" -- src build.zig build.zig.zon \
                    | tar -x -C "$stage"
            else
                (cd "$ROOT" && git ls-files -co --exclude-standard -- src build.zig \
                    build.zig.zon | while IFS= read -r f; do [[ -f "$f" ]] && echo "$f"; done \
                    | rsync -a --files-from=- . "$stage/")
                key=$(key "" "$stage")
                dir=$(storedir "$host" "$bin" "$key")
            fi
            if ! built "$host" "$dir" && ! carry "$host" "$bin" "$key"; then
                echo "building $key for $host $bin" >&2
                harness=$(inputs "" "$stage" | grep -v ' src/lab/cand/' | shasum | cut -c1-16)
                on "$host" "rm -rf $dir"
                if ! build "$host" "$bin" "$dir" "$stage"; then
                    on "$host" "rm -rf $dir"
                    rm -rf "$stage"
                    exec 8>&-
                    echo "build failed: not started" >&2
                    return 1
                fi
                on "$host" "echo $harness > $dir/harness && touch $dir/done"
            fi
            rm -rf "$stage"
        fi
        exec 8>&-
    fi
    # Newest first in prune's eyes
    if [[ "$host" == gpu-box ]]; then on gpu-box "touch $RSTORE/$key; $(prune_cmd "$RSTORE")"
    else touch "$STORE/$key"; fi
    echo "$dir"
}

# Prints "snap PATH HASH" when PATH on the host is a snapshot dir: a hash of its input
# files' names and sizes, the same on both hosts' copies. A copy lacking seat_stats.tsv
# (the Mac's on 2026-10-13, which turned win-comp into plain ratings) gets another hash
# shellcheck disable=SC2016 # expands on the host
snapcmd() {
    echo 'd='"$1"'; [[ -f $d/meiolol.db ]] || exit 0
        h=$(cd $d && for f in meiolol.db raw.db timeline.db seat_stats.tsv mastery_pre.tsv \
            legendaries.tsv; do [[ -f $f ]] && echo "$f $(( $(wc -c < $f) ))"; done \
            | { sha1sum 2> /dev/null || shasum; } | cut -c1-16)
        echo "snap '"$1"' $h"'
}

# The shared Python env of py/uv.lock on the gpu-box, ~/ml/pyenv/HASH/venv (HASH of
# py/pyproject.toml and py/uv.lock), made on first use under a lock there. Prints HASH
pyenv() {
    local h
    h=$(cat "$ROOT/py/pyproject.toml" "$ROOT/py/uv.lock" | shasum | cut -c1-16)
    on gpu-box "[[ -f ml/pyenv/$h/done ]]" && { echo "$h"; return; }
    echo "making python env $h on gpu-box" >&2
    on gpu-box "mkdir -p ml/pyenv/$h" \
        && scp -q "$ROOT/py/pyproject.toml" "$ROOT/py/uv.lock" "gpu-box:ml/pyenv/$h/" \
        && on gpu-box "cd ml/pyenv/$h && flock .lock bash -c '[[ -f done ]] || {
            UV_PROJECT_ENVIRONMENT=\$PWD/venv ~/.local/bin/uv sync --frozen -q && touch done; }'" \
            >&2 || return 1
    echo "$h"
}

# Keeps store dir $1 to the newest 40 keys, and anything used in the last 3 days: a
# script for the host holding it
# shellcheck disable=SC2016 # expands on the host
prune_cmd() {
    echo 'cd '"$(printf '%q' "$1")"' 2> /dev/null && ls -t | tail -n +41 | while read -r k; do
        [[ $k =~ ^[0-9a-f]{16}$ && -n $(find "$k" -maxdepth 0 -mtime +3) ]] && rm -rf "./$k"
        done; true'
}

start() {
    local host=$1 name=$2 bin=meiolol-lab build=1
    shift 2
    # Runs on the Mac slow Jacob's machine down (2026-10-13): gpu-box only
    if [[ "$host" == mac && "${LAB_ALLOW_MAC-}" != 1 ]]; then
        echo "model runs go on the gpu-box: start gpu-box NAME (LAB_ALLOW_MAC=1 overrides)"
        exit 2
    fi
    while (( $# )); do
        case "$1" in
            --meiolol) bin=meiolol ;;
            --python) PY=$2 bin=python; shift ;;
            --no-build) build=0 ;;
            --head) COMMIT=HEAD ;;
            --commit) COMMIT=$2; shift ;;
            --bin) PIN=$2; shift ;;
            --build-arg) BUILD_ARGS+=("$2"); shift ;;
            --with) WITH+=("$2"); shift ;;
            --res) RES=$2; shift ;;
            --literal) LITERAL=1 ;;
            --dry-run) DRY=1 ;;
            --) shift; break ;;
            *) echo "unknown option $1"; exit 2 ;;
        esac
        shift
    done
    (( $# )) || [[ "$bin" == python ]] || { echo "nothing to run: give ARGS after --"; exit 2; }
    # An unquoted ~ expands here first; this Mac's home never exists on the gpu-box
    local tilde="~"
    [[ "$host" == mac ]] || set -- "${@/#$HOME/$tilde}"
    [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "NAME: letters, digits, _ . -"; exit 2; }
    # Explicit HOST: cpu unless --res says otherwise, as before placement existed
    [[ -n "$RES" ]] || { if [[ "$host" == auto ]]; then RES=auto; else RES=cpu; fi; }
    [[ "$RES" =~ ^(cpu|gpu|none|auto)$ ]] || { echo "--res: cpu, gpu, none or auto"; exit 2; }
    if (( LITERAL )); then
        local a quoted=()
        for a in "$@"; do
            if [[ "$a" == "$tilde/"* ]]; then quoted+=("$tilde/$(printf '%q' "${a#"$tilde"/}")")
            else quoted+=("$(printf '%q' "$a")"); fi
        done
        set -- "${quoted[@]}"
    fi
    # Placement (auto) or just the prediction (explicit; a failure there changes nothing)
    local placed p_host p_res predicted=- why="" auto=0
    [[ "$host" == auto || "$RES" == auto ]] && auto=1
    if placed=$(place "$host" "$RES" "$bin" "$*" "${BUILD_ARGS[*]-}" 2>&1); then
        read -r p_host p_res predicted <<< "$(head -n 1 <<< "$placed")"
        why=$(sed -n 2p <<< "$placed")
        if (( auto )); then host=$p_host RES=$p_res; echo "placed: $why"
        else echo "predicted: $why"; fi
    elif (( auto )); then
        echo "not placed: $placed"
        exit 1
    fi
    (( DRY )) && exit 0
    local commit="" key=- dir path info env=""
    if [[ "$bin" == python ]]; then
        [[ "$host" == gpu-box ]] || { echo "--python runs on the gpu-box"; exit 2; }
        [[ -z "$COMMIT$PIN${BUILD_ARGS[*]-}" ]] \
            || { echo "--python: no --head, --commit, --bin or --build-arg"; exit 2; }
        [[ -f "$PY" ]] || { echo "--python: no file $PY"; exit 2; }
        env=$(pyenv) || { echo "python env failed: not started"; exit 1; }
        path=$PY
        info=$(cat "$(dirname "$PY")"/*.py | shasum -a 256 | cut -c1-16)$'\n-'
    else
        if [[ -n "$COMMIT" ]]; then
            commit=$(git -C "$ROOT" rev-parse --verify -q "$COMMIT^{commit}") \
                || { echo "--commit: no commit $COMMIT"; exit 2; }
        fi
        if [[ -n "$PIN" ]]; then
            [[ "$PIN" =~ ^[0-9a-f]{16}$ ]] || { echo "--bin: a 16-digit KEY from a start"; exit 2; }
            [[ -z "$commit" ]] || { echo "--bin with --head/--commit: give one"; exit 2; }
            key=$PIN build=0
        else
            key=$(key "$commit" "$ROOT")
        fi
        dir=$(ensure "$host" "$bin" "$key" "$commit" "$build") || exit 1
        key=$(basename "$(dirname "$dir")")
        path=$(binpath "$dir" "$host" "$bin")
        # One round trip: the binary's hash, then its harness key
        info=$(on "$host" "[[ -x $path ]] \
            && { sha256sum $path 2> /dev/null || shasum -a 256 $path; } | cut -c1-16 \
            && { cat $dir/harness 2> /dev/null || echo -; }") \
            || { echo "no binary at $path on $host"; exit 1; }
        echo "binary $key"
        bash -c "$(prune_cmd "$STORE")"
    fi
    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: tmp is local
    trap "rm -rf '$tmp'" RETURN

    local run
    run=$(date -u +%Y%m%dT%H%M%SZ)-$name
    {
        echo "host $host"
        echo "bin $bin $(sed -n 1p <<< "$info")"
        # Float results differ in the last bits between CPU targets (FMA): paired
        # comparisons need both sides from the same one. gpu-box: build.zig's gpu_box
        # query and --meiolol's -Dcpu, both x86_64_v3 since 2026-10-13
        if [[ "$host" == gpu-box ]]; then echo "cpu x86_64_v3"; else echo "cpu native"; fi
        # src: the store key, the same for any two runs built from the same inputs;
        # harness: the same without the candidate (src/lab/cand, -Dcand), what
        # `meiolol-lab compare` needs equal on both sides
        echo "src $key"
        echo "harness $(sed -n 2p <<< "$info")"
        local w
        # shellcheck disable=SC2048 # the words as the host's bash will split them
        for w in $*; do
            w=${w//[\'\"\\]/}
            [[ "$w" == *snap-* && "$w" =~ ^[A-Za-z0-9_./~-]+$ ]] || continue
            on "$host" "$(snapcmd "$w")" 2> /dev/null || true
        done
        if [[ -n "$commit" ]]; then echo "head $commit"; echo "dirty 0 files (--commit)"
        elif [[ -n "$PIN" ]]; then echo "head - (--bin)"; echo "dirty - (--bin)"
        elif [[ -n "$env" ]]; then
            echo "head $(git -C "$ROOT" rev-parse HEAD)"
            echo "dirty $(git -C "$ROOT" status --porcelain -- "$(dirname "$PY")" py 2> /dev/null \
                | wc -l) files (py)"
        else
            echo "head $(git -C "$ROOT" rev-parse HEAD)"
            echo "dirty $(git -C "$ROOT" status --porcelain -- src build.zig | wc -l) files"
        fi
        echo "args $*"
        echo "res $RES"
        if (( ${#BUILD_ARGS[@]} )); then echo "build ${BUILD_ARGS[*]}"; fi
        if [[ -n "$env" ]]; then echo "python $PY"; echo "pyenv $env"; fi
        if (( ${#WITH[@]} )); then echo "with ${WITH[*]}"; fi
    } > "$tmp/meta"
    # Seconds of running time expected (deploy/lab-place.pl), and why: status checks it
    [[ "$predicted" == - ]] || printf "%s\t%s\n" "$predicted" "$why" > "$tmp/predicted"
    : > "$tmp/src.diff"
    [[ -n "$commit$PIN$env" ]] || git -C "$ROOT" diff HEAD -- src build.zig > "$tmp/src.diff"
    # caffeinate: a Mac asleep mid-run looks like a hung run
    local awake=""
    [[ "$host" == mac ]] && awake="caffeinate -i "
    # $$ is the process group: setpgrp below makes this bash its leader. The lock is on
    # fd 9, which the job inherits, so it is held until the job and this bash are gone.
    # perl, not flock(1): the Mac has none. Slots: RES has N locks (~/ml/locks/RES.slots on
    # the host, default 4), so N runs of a resource share the PC; the job takes the first
    # free one. A cpu slot pins the job to its share of the cores (taskset; par.zig and
    # Zig's thread pool size themselves from the affinity mask), so runs don't fight over
    # cores and results don't change: par.zig's loops match serially whatever the count
    local lock="" pin=""
    # shellcheck disable=SC2016 # expands on the host
    [[ "$RES" == none ]] || lock='mkdir -p ~/ml/locks
n=$(cat ~/ml/locks/@RES@.slots 2> /dev/null || echo 4)
echo @RES@ > queued
slot=
while [[ -z $slot ]]; do
    for (( i = 0; i < n; i++ )); do
        exec 9>> ~/ml/locks/@RES@.$i
        if perl -MFcntl=:flock -e '"'"'open(my $f, q{>&=}, 9) or die; flock($f, LOCK_EX | LOCK_NB) or exit 1'"'"'; then
            slot=$i
            break
        fi
        exec 9>&-
    done
    [[ -n $slot ]] || sleep 5
done
rm queued
echo "@RES@.$slot of $n" > slot
# Not nproc: it honours OMP_NUM_THREADS
c=$(getconf _NPROCESSORS_ONLN)
export OMP_NUM_THREADS=$(( c / n ))'
    # shellcheck disable=SC2016 # expands on the host
    [[ "$RES" == cpu ]] && lock+='
pin=
if command -v taskset > /dev/null; then
    k=$(( c / n )); lo=$(( slot * k ))
    pin="taskset -c $lo-$(( lo + k - 1 ))"
    echo "cores $lo-$(( lo + k - 1 ))" >> slot
fi' pin='$pin '
    # shellcheck disable=SC2016 # expands on the host
    [[ "$RES" == gpu ]] && lock+='
printf -v LAB_GPU_FRACTION "0.%03d" $(( 950 / n ))
export LAB_GPU_FRACTION'
    lock=${lock//@RES@/$RES}
    local cmd="./$bin"
    # shellcheck disable=SC2088 # expands on the host
    [[ -z "$env" ]] || cmd="env PYTHONUNBUFFERED=1 ~/ml/pyenv/$env/venv/bin/python labpy.py"
    [[ -z "$env" ]] || cmd+=" $(basename "$PY")"
    cat > "$tmp/job.sh" <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")"
echo \$\$ > job.pgid
rm -f started
$lock
date -u +%FT%TZ > started
${awake}${pin}nice -n 10 $cmd $*
echo \$? > exit
date -u +%FT%TZ > ended
EOF
    chmod +x "$tmp/job.sh"
    # No -p on the run dir: a second start of NAME in the same second must not share it
    on "$host" "mkdir -p $RUNS && mkdir $RUNS/$run" \
        || { echo "$run already exists on $host: not started"; exit 1; }
    local files=("$tmp/meta" "$tmp/src.diff" "$tmp/job.sh")
    if [[ -n "$env" ]]; then
        files+=("$(dirname "$PY")"/*.py "$ROOT/py/labpy.py" "$ROOT/py/pyproject.toml" \
            "$ROOT/py/uv.lock")
    elif [[ "$host" == gpu-box ]]; then on gpu-box "cp $path $RUNS/$run/"
    else files+=("$path"); fi
    copy "$host" "$RUNS/$run" "${files[@]}"
    [[ -f "$tmp/predicted" ]] && copy "$host" "$RUNS/$run" "$tmp/predicted"
    if (( ${#WITH[@]} )); then copy "$host" "$RUNS/$run" "${WITH[@]}"; fi
    on "$host" "cd $RUNS/$run && $LAUNCH"
    echo "started $run on $host"
}

# Starts job.sh detached in the run dir, its own process group. Braces: only the job goes
# to the background, so nothing keeps ssh's output open. deploy/lab-watch.sh has a copy
LAUNCH="{ nohup perl -e 'setpgrp(0,0); exec @ARGV' ./job.sh >> log 2>&1 < /dev/null & }"

# What deploy/lab-place.pl reads about HOST, tab-separated, each line led by HOST: its
# clock, the watcher's last League line, which of PATHS exist (~/ paths, checked by
# lab-place.pl inputs), and one line per run. Fails if the host can't be reached
listing() {
    local host=$1 have="" p
    shift
    for p in "$@"; do have+="[[ -e $p ]] && printf 'have\t%s\n' '$p'
"; done
    # shellcheck disable=SC2016 # expands on the host
    local script='printf "now\t%s\n" "$(date -u +%FT%TZ)"
        '"$have"'cd '"$RUNS"' 2>/dev/null || exit 0
        [[ -f watcher.log ]] && grep -a "League " watcher.log | tail -n 200 | sed "s/^/league\t/"
        for r in cpu gpu; do
            printf "slots\t%s\t%s\n" $r "$(cat ~/ml/locks/$r.slots 2>/dev/null || echo 4)"
        done
        for d in */; do
            d=${d%/}; [[ -f $d/job.sh ]] || continue
            pg=$(cat $d/job.pgid 2>/dev/null)
            if [[ -f $d/exit ]]; then s="exit $(cat $d/exit)"
            elif [[ -f $d/stopped ]]; then s=stopped
            elif [[ -n $pg ]] && kill -0 -- -$pg 2>/dev/null; then
                if [[ -f $d/paused ]]; then s=paused
                elif [[ -f $d/queued ]]; then s="queued $(cat $d/queued)"
                else s=running; fi
            else s=died; fi
            m() { sed -n "s/^$1 //p" $d/meta 2>/dev/null | tr "\t" " "; }
            printf "run\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$d" "$s" \
                "$(cat $d/started 2>/dev/null)" "$(cat $d/ended 2>/dev/null)" \
                "$(m res)" "$(m bin | cut -d " " -f 1)" "$(m args)" \
                "$(tr "\n" , 2>/dev/null < $d/pauses.log)" "$(cut -f 1 $d/predicted 2>/dev/null)" \
                "$(m build)" "$(head -n 1 $d/slot 2>/dev/null | cut -d " " -f 1)" \
                "$(tail -n 1 $d/log 2>/dev/null | cut -c1-80 | tr "\t" " ")"
        done'
    if [[ "$host" == mac ]]; then on mac "$script"
    else ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "$script"; fi | sed "s/^/$host	/"
}

# Prints "HOST RES SECONDS" (- if unknown), then why: deploy/lab-place.pl from both hosts'
# runs. HOST and RES may be auto
place() {
    local paths h
    paths=$(perl "$ROOT/deploy/lab-place.pl" inputs "$4" | tr '\n' ' ')
    # shellcheck disable=SC2086 # plain ~/ paths, no spaces (lab-place.pl inputs)
    for h in gpu-box mac; do listing "$h" $paths || true; done \
        | perl "$ROOT/deploy/lab-place.pl" place "$@"
}

# One line per run: name, state, start, run time (so far) against its prediction, last
# log line
status() {
    local out
    out=$(listing "$1") || return 1
    perl "$ROOT/deploy/lab-place.pl" status "$1" <<< "$out"
    if [[ "$1" == gpu-box ]]; then

        echo "watcher: $(on gpu-box "systemctl --user is-active $WATCH" || true)," \
            "last said: $(on gpu-box "tail -n 1 $RUNS/watcher.log" || true)"
    fi
}

# Run $1's state on its host: exit N, stopped, died, running (queued and paused too) or
# missing. No job.pgid yet: the job is still starting
# shellcheck disable=SC2016 # expands on the host
state_cmd() {
    echo 'cd '"$RUNS/$1"' 2>/dev/null || { echo missing; exit; }
        if [[ -f exit ]]; then echo "exit $(cat exit)"; elif [[ -f stopped ]]; then echo stopped
        else pg=$(cat job.pgid 2>/dev/null)
            if [[ -z $pg ]] || kill -0 -- -$pg 2>/dev/null; then echo running; else echo died; fi
        fi'
}

# Blocks until every RUN has ended (on whichever host has it), then prints each one's
# state and RESULT lines. Exit 0 when all exited 0, 3 on timeout, else 1
wait_runs() {
    local runs=() hosts=() states=() timeout=0 i h st pending t0=$SECONDS
    while (( $# )); do
        case "$1" in
            --timeout) timeout=${2:-}; shift ;;
            *) check_run "$1"; runs+=("$1") ;;
        esac
        shift
    done
    (( ${#runs[@]} )) || { echo "wait RUN... [--timeout S]"; exit 2; }
    [[ "$timeout" =~ ^[0-9]+$ ]] || { echo "--timeout: seconds"; exit 2; }
    for i in "${!runs[@]}"; do
        hosts[i]=
        for h in mac gpu-box; do
            if on "$h" "[[ -d $RUNS/${runs[i]} ]]" 2> /dev/null; then hosts[i]=$h; break; fi
        done
        [[ -n "${hosts[i]}" ]] || { echo "${runs[i]}: on neither host"; exit 2; }
        states[i]=
    done
    while :; do
        pending=0
        for i in "${!runs[@]}"; do
            [[ -z "${states[i]}" ]] || continue
            st=$(on "${hosts[i]}" "$(state_cmd "${runs[i]}")" 2> /dev/null) || st=unreachable
            case "$st" in
                exit*|stopped|died|missing) states[i]=$st ;;
                *) pending=1 ;;
            esac
        done
        (( pending )) || break
        if (( timeout && SECONDS - t0 >= timeout )); then break; fi
        sleep 20
    done
    local status=0
    for i in "${!runs[@]}"; do
        st=${states[i]:-not ended (timeout)}
        echo "${runs[i]} on ${hosts[i]}: $st"
        on "${hosts[i]}" "grep -a '^RESULT' $RUNS/${runs[i]}/log | tail -n 5" 2> /dev/null \
            | sed 's/^/  /' || true
        if [[ -z "${states[i]}" ]]; then status=3
        elif [[ "$st" != "exit 0" && $status == 0 ]]; then status=1; fi
    done
    return $status
}

main() {
case "${1:-}" in
    start)
        (( $# >= 3 )) || { sed -n '8,18p' "$0"; exit 2; }
        # No HOST (start NAME [OPTIONS] -- ARGS): placed by predicted finish, as auto
        if [[ "$2" != mac && "$2" != gpu-box && "$2" != auto && "$3" == -* ]]; then
            set -- start auto "${@:2}"
        fi
        [[ "$2" == auto ]] || check_host "$2"
        start "${@:2}"
        ;;
    status)
        if [[ -n "${2:-}" ]]; then check_host "$2"; status "$2"; else
            for h in gpu-box mac; do echo "== $h"; status "$h" || echo "unreachable"; done
        fi
        ;;
    wait) shift; wait_runs "$@" ;;
    logs)
        check_host "$2"
        check_run "${3:-}"
        [[ "${4:-40}" =~ ^[0-9]+$ ]] || { echo "LINES: a number"; exit 2; }
        on "$2" "tail -n ${4:-40} $RUNS/$3/log"
        ;;
    restart)
        check_host "$2"
        check_run "${3:-}"
        # shellcheck disable=SC2016 # expands on the host
        on "$2" 'cd '"$RUNS/$3"' || exit 1
            pg=$(cat job.pgid 2>/dev/null)
            if [[ -n $pg ]] && kill -0 -- -$pg 2>/dev/null; then echo "still running"; exit 1; fi
            rm -f exit ended stopped paused queued
            echo "$(date -u +%FT%TZ) restart" >> restarts && '"$LAUNCH"
        echo "restarted $3 on $2"
        ;;
    stop)
        check_host "$2"
        check_run "${3:-}"
        # CONT after TERM: a paused group only acts on the TERM once it runs again
        # shellcheck disable=SC2016 # expands on the host
        on "$2" 'cd '"$RUNS/$3"' && pg=$(cat job.pgid) && touch stopped \
            && kill -TERM -- -$pg && kill -CONT -- -$pg 2>/dev/null; rm -f paused'
        ;;
    pull)
        check_host "$2"
        check_run "${3:-}"
        mkdir -p "$ROOT/data/runs/$3"
        src="$HOME/$RUNS/$3/"
        [[ "$2" == mac ]] || src="$2:$RUNS/$3/"
        rsync -a --exclude meiolol-lab --exclude meiolol "$src" "$ROOT/data/runs/$3/"
        echo "in data/runs/$3"
        ;;
    watch-install)
        on gpu-box "mkdir -p ml/bin $RUNS .config/systemd/user"
        scp -q "$ROOT/deploy/lab-watch.sh" gpu-box:ml/bin/
        scp -q "$ROOT/deploy/systemd/$WATCH.service" gpu-box:.config/systemd/user/
        # The raw archive's hourly pull (docs/data-safety.md "Raw archive") rides along:
        # nothing else syncs it. Its unit's environment drop-ins on the host are kept
        scp -q "$ROOT/deploy/archive-pull.sh" gpu-box:ml/bin/
        scp -q "$ROOT/deploy/systemd/meiolol-archive-pull".{service,timer} gpu-box:.config/systemd/user/
        # Windows side (deploy/windows) to %USERPROFILE%\.meiolol, CRLF for Windows. WSL
        # can write there, so nothing there runs elevated: the archive mount (admin) is
        # installed once, by hand, by install-watchdog.ps1 (docs/compute.md). cmd.exe
        # reads stdin, so it gets /dev/null
        # shellcheck disable=SC2016 # expands on the host
        win=$(on gpu-box 'cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /c "echo %USERPROFILE%" \
            < /dev/null | tr -d "\r\n" | xargs -0 wslpath')/.meiolol
        on gpu-box "mkdir -p '$win'"
        for f in "$ROOT"/deploy/windows/*; do
            sed 's/$/\r/' "$f" | on gpu-box "cat > '$win/$(basename "$f")'"
        done
        on gpu-box "loginctl enable-linger \$USER; systemctl --user daemon-reload \
            && systemctl --user enable -q $WATCH meiolol-archive-pull.timer \
            && systemctl --user restart $WATCH && systemctl --user start meiolol-archive-pull.timer \
            && systemctl --user is-active $WATCH meiolol-archive-pull.timer"
        ;;
    *) sed -n '8,18p' "$0"; exit 2 ;;
esac
}

# Bash reads a script as it runs: a commit rewriting this file under a running start would
# run the new file's bytes from the old offset. main is parsed whole before it runs
main "$@"
exit
