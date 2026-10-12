#!/usr/bin/env bash
# Long modelling runs on the gpu-box (i5-13600KF, RTX 3080, WSL) or this Mac, detached,
# one directory per run in ~/ml/runs on that host. Builds from the working tree, not a
# clean checkout: experiments are usually uncommitted, so each run keeps HEAD and a diff.
# On the gpu-box, deploy/lab-watch.sh pauses every run while League is open (Jacob's
# rule); `watch-install` sets it up. docs/compute.md
#
#   deploy/lab-run.sh start HOST NAME [--meiolol] [--head | --no-build] [--build-arg A]...
#                           [--with PATH]... [--res cpu|gpu|none] [--literal] -- ARGS...
#   deploy/lab-run.sh status [HOST]
#   deploy/lab-run.sh logs HOST RUN [LINES]
#   deploy/lab-run.sh stop HOST RUN
#   deploy/lab-run.sh restart HOST RUN       run it again in its dir (after a WSL restart)
#   deploy/lab-run.sh pull HOST RUN          results to data/runs/RUN here
#   deploy/lab-run.sh watch-install          League watcher on the gpu-box
#
# HOST: gpu-box or mac. ARGS go to meiolol-lab (or meiolol with --meiolol), joined with
# spaces and run by bash in the run directory on the host, so ~ and globs expand there:
#   deploy/lab-run.sh start gpu-box smoke -- gpu-smoke
#   deploy/lab-run.sh start mac eval --meiolol -- eval --data "~/ml/snaps/X" ">" eval.md
# --literal: each ARG reaches the program as one word, nothing expanded but a leading ~/
# (deploy/lab-exp.sh: its words come from an agent, so they must not run as shell).
# --head builds committed HEAD in a temp tree instead (other sessions edit the working
# tree; a half-written file there breaks or silently changes the build).
# --build-arg goes to zig build (deploy/lab-exp.sh: -Dcand=DIR); --with copies a file or
# directory into the run dir (the candidate's source, kept with its scores)
# Queue: a run waits for its resource's lock on the host (~/ml/locks/RES; cpu by default,
# since every run uses all cores via par.zig), so runs go one after another, not over each
# other. A GPU run takes gpu and can share the PC with a cpu one. Waiting runs are
# "queued"; `started` is written once the lock is held
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNS=ml/runs
SRC=$ROOT
HEAD_ONLY=0
BUILD_ARGS=()
WITH=()
RES=cpu
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

# Prints the binary's path. Own prefix per host and binary, so zig-out/bin is left alone
prefix() {
    local prefix="$ROOT/zig-out/lab-run/$1"
    (( HEAD_ONLY )) && prefix+=-head
    # Own prefix per set of build args, so concurrent candidate builds don't swap binaries
    if (( ${#BUILD_ARGS[@]} )); then
        prefix+=-$(printf '%s\n' "${BUILD_ARGS[@]}" | shasum | cut -c1-8)
    fi
    echo "$prefix"
}

# Where `build` puts BIN for HOST: `zig build lab` installs a host build in bin and the
# gpu-box one in gpu-box
binpath() {
    local dir=bin
    [[ "$2" == meiolol-lab && "$1" == gpu-box ]] && dir=gpu-box
    echo "$(prefix "$1")/$dir/$2"
}

build() {
    local host=$1 bin=$2
    local args=(--prefix "$(prefix "$host")" -Doptimize=ReleaseFast)
    args+=(${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"})
    if [[ "$bin" == meiolol-lab ]]; then
        args+=(lab)
    elif [[ "$host" == gpu-box ]]; then
        args+=(-Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3)
    fi
    (cd "$SRC" && zig build "${args[@]}" --cache-dir "$ROOT/.zig-cache" >&2)
}

start() {
    local host=$1 name=$2 bin=meiolol-lab build=1
    shift 2
    while (( $# )); do
        case "$1" in
            --meiolol) bin=meiolol ;;
            --no-build) build=0 ;;
            --head) HEAD_ONLY=1 ;;
            --build-arg) BUILD_ARGS+=("$2"); shift ;;
            --with) WITH+=("$2"); shift ;;
            --res) RES=$2; shift ;;
            --literal) LITERAL=1 ;;
            --) shift; break ;;
            *) echo "unknown option $1"; exit 2 ;;
        esac
        shift
    done
    (( $# )) || { echo "nothing to run: give ARGS after --"; exit 2; }
    # An unquoted ~ expands here first; this Mac's home never exists on the gpu-box
    local tilde="~"
    [[ "$host" == mac ]] || set -- "${@/#$HOME/$tilde}"
    [[ "$name" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "NAME: letters, digits, _ . -"; exit 2; }
    [[ "$RES" =~ ^(cpu|gpu|none)$ ]] || { echo "--res: cpu, gpu or none"; exit 2; }
    if (( LITERAL )); then
        local a quoted=()
        for a in "$@"; do
            if [[ "$a" == "$tilde/"* ]]; then quoted+=("$tilde/$(printf '%q' "${a#"$tilde"/}")")
            else quoted+=("$(printf '%q' "$a")"); fi
        done
        set -- "${quoted[@]}"
    fi
    local path
    path=$(binpath "$host" "$bin")
    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: tmp is local
    trap "rm -rf '$tmp'" RETURN
    if (( HEAD_ONLY )); then
        mkdir "$tmp/src"
        git -C "$ROOT" archive HEAD | tar -x -C "$tmp/src"
        SRC=$tmp/src
    fi
    # A failed build must not start a stale binary left at the prefix
    if (( build )) && ! build "$host" "$bin"; then echo "build failed: not started"; exit 1; fi
    [[ -x "$path" ]] || { echo "no binary at $path"; exit 1; }

    local run
    run=$(date -u +%Y%m%dT%H%M%SZ)-$name
    {
        echo "host $host"
        echo "bin $bin $(shasum -a 256 "$path" | cut -c1-16)"
        echo "head $(git -C "$ROOT" rev-parse HEAD)"
        if (( HEAD_ONLY )); then echo "dirty 0 files (--head)"; else
            echo "dirty $(git -C "$ROOT" status --porcelain -- src build.zig | wc -l) files"
        fi
        echo "args $*"
        echo "res $RES"
        if (( ${#BUILD_ARGS[@]} )); then echo "build ${BUILD_ARGS[*]}"; fi
        if (( ${#WITH[@]} )); then echo "with ${WITH[*]}"; fi
    } > "$tmp/meta"
    : > "$tmp/src.diff"
    (( HEAD_ONLY )) || git -C "$ROOT" diff HEAD -- src build.zig > "$tmp/src.diff"
    # caffeinate: a Mac asleep mid-run looks like a hung run
    local awake=""
    [[ "$host" == mac ]] && awake="caffeinate -i "
    # $$ is the process group: setpgrp below makes this bash its leader. The lock is on
    # fd 9, which the job inherits, so it is held until the job and this bash are gone.
    # perl, not flock(1): the Mac has none
    local lock=""
    [[ "$RES" == none ]] || lock="mkdir -p ~/ml/locks
exec 9>> ~/ml/locks/$RES
echo $RES > queued
perl -MFcntl=:flock -e 'open(my \$f, q{>&=}, 9) or die; flock(\$f, LOCK_EX) or die' || exit 1
rm queued"
    cat > "$tmp/job.sh" <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")"
echo \$\$ > job.pgid
rm -f started
$lock
date -u +%FT%TZ > started
${awake}nice -n 10 ./$bin $*
echo \$? > exit
date -u +%FT%TZ > ended
EOF
    chmod +x "$tmp/job.sh"
    # No -p on the run dir: a second start of NAME in the same second must not share it
    on "$host" "mkdir -p $RUNS && mkdir $RUNS/$run" \
        || { echo "$run already exists on $host: not started"; exit 1; }
    copy "$host" "$RUNS/$run" "$path" "$tmp/meta" "$tmp/src.diff" "$tmp/job.sh"
    if (( ${#WITH[@]} )); then copy "$host" "$RUNS/$run" "${WITH[@]}"; fi
    on "$host" "cd $RUNS/$run && $LAUNCH"
    echo "started $run on $host"
}

# Starts job.sh detached in the run dir, its own process group. Braces: only the job goes
# to the background, so nothing keeps ssh's output open. deploy/lab-watch.sh has a copy
LAUNCH="{ nohup perl -e 'setpgrp(0,0); exec @ARGV' ./job.sh >> log 2>&1 < /dev/null & }"

# One line per run: name, state, start, last log line
status() {
    # shellcheck disable=SC2016 # expands on the host
    on "$1" 'cd '"$RUNS"' 2>/dev/null || exit 0
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
            printf "%s | %s | %s | %s\n" "$d" "$s" "$(cat $d/started 2>/dev/null)" \
                "$(tail -n 1 $d/log 2>/dev/null | cut -c1-80)"
        done'
    if [[ "$1" == gpu-box ]]; then
        echo "watcher: $(on gpu-box "systemctl --user is-active $WATCH" || true)," \
            "last said: $(on gpu-box "tail -n 1 $RUNS/watcher.log" || true)"
    fi
}

case "${1:-}" in
    start)
        (( $# >= 3 )) || { sed -n '8,14p' "$0"; exit 2; }
        check_host "$2"
        start "${@:2}"
        ;;
    status)
        if [[ -n "${2:-}" ]]; then check_host "$2"; status "$2"; else
            for h in gpu-box mac; do echo "== $h"; status "$h" || echo "unreachable"; done
        fi
        ;;
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
            && systemctl --user enable -q $WATCH \
            && systemctl --user restart $WATCH && systemctl --user is-active $WATCH"
        ;;
    *) sed -n '8,14p' "$0"; exit 2 ;;
esac
