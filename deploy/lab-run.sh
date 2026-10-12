#!/usr/bin/env bash
# Long modelling runs on the gpu-box (i5-13600KF, RTX 3080, WSL) or this Mac, detached,
# one directory per run in ~/ml/runs on that host. Builds from the working tree, not a
# clean checkout: experiments are usually uncommitted, so each run keeps HEAD and a diff.
# On the gpu-box, deploy/lab-watch.sh pauses every run while League is open (Jacob's
# rule); `watch-install` sets it up. docs/compute.md
#
#   deploy/lab-run.sh start HOST NAME [--meiolol] [--no-build] -- ARGS...
#   deploy/lab-run.sh status [HOST]
#   deploy/lab-run.sh logs HOST RUN [LINES]
#   deploy/lab-run.sh stop HOST RUN
#   deploy/lab-run.sh pull HOST RUN          results to data/runs/RUN here
#   deploy/lab-run.sh watch-install          League watcher on the gpu-box
#
# HOST: gpu-box or mac. ARGS go to meiolol-lab (or meiolol with --meiolol), joined with
# spaces and run by bash in the run directory on the host, so ~ and globs expand there:
#   deploy/lab-run.sh start gpu-box smoke -- gpu-smoke
#   deploy/lab-run.sh start mac eval --meiolol -- eval --data "~/ml/snaps/X" ">" eval.md
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RUNS=ml/runs
WATCH=meiolol-lab-watch

on() {
    local host=$1
    shift
    if [[ "$host" == mac ]]; then (cd && bash -c "$*"); else ssh "$host" "$*"; fi
}

copy() {
    local host=$1 dst=$2
    shift 2
    if [[ "$host" == mac ]]; then cp "$@" "$HOME/$dst/"
    else scp -q "$@" "$host:$dst/"; fi
}

check_host() {
    [[ "$1" == mac || "$1" == gpu-box ]] && return
    echo "HOST is gpu-box or mac, not $1"
    exit 2
}

# Prints the binary's path. Own prefix per host and binary, so zig-out/bin is left alone
build() {
    local host=$1 bin=$2 prefix="$ROOT/zig-out/lab-run/$1"
    local args=(--prefix "$prefix" -Doptimize=ReleaseFast) dir=bin
    # `zig build lab` installs a host build in bin and the gpu-box one in gpu-box
    if [[ "$bin" == meiolol-lab ]]; then
        args+=(lab)
        [[ "$host" == gpu-box ]] && dir=gpu-box
    elif [[ "$host" == gpu-box ]]; then
        args+=(-Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3)
    fi
    (cd "$ROOT" && zig build "${args[@]}" >&2)
    echo "$prefix/$dir/$bin"
}

start() {
    local host=$1 name=$2 bin=meiolol-lab build=1
    shift 2
    while (( $# )); do
        case "$1" in
            --meiolol) bin=meiolol ;;
            --no-build) build=0 ;;
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
    local path="$ROOT/zig-out/lab-run/$host/bin/$bin"
    (( build )) && path=$(build "$host" "$bin")
    [[ -x "$path" ]] || { echo "no binary at $path"; exit 1; }

    local run tmp
    run=$(date -u +%Y%m%dT%H%MZ)-$name
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: tmp is local
    trap "rm -rf '$tmp'" RETURN
    {
        echo "host $host"
        echo "bin $bin $(shasum -a 256 "$path" | cut -c1-16)"
        echo "head $(git -C "$ROOT" rev-parse HEAD)"
        echo "dirty $(git -C "$ROOT" status --porcelain -- src build.zig | wc -l) files"
        echo "args $*"
    } > "$tmp/meta"
    git -C "$ROOT" diff HEAD -- src build.zig > "$tmp/src.diff"
    # $$ is the process group: setpgrp below makes this bash its leader
    cat > "$tmp/job.sh" <<EOF
#!/usr/bin/env bash
cd "\$(dirname "\$0")"
echo \$\$ > job.pgid
date -u +%FT%TZ > started
nice -n 10 ./$bin $*
echo \$? > exit
date -u +%FT%TZ > ended
EOF
    chmod +x "$tmp/job.sh"
    on "$host" "mkdir -p $RUNS/$run"
    copy "$host" "$RUNS/$run" "$path" "$tmp/meta" "$tmp/src.diff" "$tmp/job.sh"
    # Braces: only the job goes to the background, so nothing keeps ssh's output open
    on "$host" "cd $RUNS/$run && { nohup perl -e 'setpgrp(0,0); exec @ARGV' ./job.sh \
        > log 2>&1 < /dev/null & }"
    echo "started $run on $host"
}

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
                if [[ -f $d/paused ]]; then s=paused; else s=running; fi
            else s=died; fi
            printf "%s | %s | %s | %s\n" "$d" "$s" "$(cat $d/started 2>/dev/null)" \
                "$(tail -n 1 $d/log 2>/dev/null | cut -c1-80)"
        done'
    if [[ "$1" == gpu-box ]]; then
        echo "watcher: $(on gpu-box "systemctl --user is-active $WATCH" || true)"
    fi
}

case "${1:-}" in
    start)
        (( $# >= 3 )) || { sed -n '8,13p' "$0"; exit 2; }
        check_host "$2"
        start "${@:2}"
        ;;
    status)
        if [[ -n "${2:-}" ]]; then check_host "$2"; status "$2"; else
            for h in gpu-box mac; do echo "== $h"; status "$h" || echo "unreachable"; done
        fi
        ;;
    logs) check_host "$2"; on "$2" "tail -n ${4:-40} $RUNS/$3/log" ;;
    stop)
        check_host "$2"
        # CONT after TERM: a paused group only acts on the TERM once it runs again
        # shellcheck disable=SC2016 # expands on the host
        on "$2" 'cd '"$RUNS/$3"' && pg=$(cat job.pgid) && touch stopped \
            && kill -TERM -- -$pg && kill -CONT -- -$pg 2>/dev/null; rm -f paused'
        ;;
    pull)
        check_host "$2"
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
        on gpu-box "loginctl enable-linger \$USER; systemctl --user daemon-reload \
            && systemctl --user enable -q $WATCH \
            && systemctl --user restart $WATCH && systemctl --user is-active $WATCH"
        ;;
    *) sed -n '8,13p' "$0"; exit 2 ;;
esac
