#!/usr/bin/env bash
# The webview app (src/shell, meiolol-shell.exe) on the gpu-box's Windows: built here,
# run there in Jacob's session through a one-off `schtasks /it` task (from WSL over ssh a
# window can't open), in %LOCALAPPDATA%\meiolol-shell-test (never Programs\meiolol), and
# what it wrote copied back. Scripted runs open a window that doesn't take the keyboard.
#   deploy/shell.sh build [EDITION]            ReleaseSafe exe (private default) in
#                                              zig-out/shell/EDITION/bin
#   deploy/shell.sh pages [DIR]                pages to measure (default data/shell-pages):
#                                              the draft board mock with shell-demo.js,
#                                              the champions mock, the zig-tree table
#   deploy/shell.sh smoke [EXE]                --self-test with each loader (ours, then
#                                              WebView2Loader.dll): both must paint
#   deploy/shell.sh measure OUT [ARGS...]      --measure on the pages, results in OUT
#                                              (ARGS e.g. --scale 1.5)
#   deploy/shell.sh run [ARGS...]              start it there and leave it open (--demo)
#   deploy/shell.sh stop                       close a run left open
# A window on Jacob's screen during his game: runs refuse while League of Legends.exe
# (a game, not the client) is running, unless IN_GAME=1 (he agreed to an in-game run)
set -euo pipefail

HOST=${MEIOLOL_GPU_HOST:-gpu-box}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=deploy/lib.sh
. "$ROOT/deploy/lib.sh"
main=$(dirname "$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)")
S=/mnt/c/Windows/System32

build() {
    local e=${1:-private}
    (cd "$ROOT" && lockf ~/.cache/meiolol-zig.lock zig build shell -Doptimize=ReleaseSafe \
        -Dedition="$e" --prefix "zig-out/shell/$e")
    echo "$ROOT/zig-out/shell/$e/bin/meiolol-shell.exe"
}

# The page set measure runs on, from the UI run's mocks and spikes (data/team, ignored)
pages() {
    local out=${1:-$main/data/shell-pages} ui=$main/data/team/2026-10-24-ui
    rm -rf "$out" && mkdir -p "$out/icons/champ" "$out/zig-tree"
    cp "$ui"/mocks/icons/champ/*.png "$out/icons/champ/"
    sed 's|</body>|<script src="shell-demo.js"></script></body>|' "$ui/mocks/draft-tester.html" > "$out/draft.html"
    cp "$ROOT/deploy/shell-demo.js" "$out/"
    cp "$ui/mocks/champions.html" "$out/champions.html"
    find "$ui/spikes/zig-tree" -maxdepth 1 -type f \( -name '*.html' -o -name '*.css' \
        -o -name '*.js' -o -name '*.wasm' -o -name '*.bin' \) -exec cp {} "$out/zig-tree/" \;
    grep -q shell-demo.js "$out/draft.html" || { echo "shell.sh: no </body> in the draft mock" >&2; exit 1; }
    echo "$out: $(find "$out" -type f | wc -l | tr -d ' ') files, $(du -sk "$out" | cut -f1) KB"
}

# The test folder on the gpu-box, as a WSL path
remote_dir() {
    local d
    # shellcheck disable=SC2016 # expanded on the gpu-box
    d=$(ssh "$HOST" 'd=$(wslpath "$(/mnt/c/Windows/System32/cmd.exe /c "echo %LOCALAPPDATA%" 2> /dev/null | tr -d "\r")")/meiolol-shell-test && mkdir -p "$d" && echo "$d"')
    [[ $d == /mnt/* ]] || { echo "shell.sh: no Windows folder on $HOST ($d)" >&2; exit 1; }
    echo "$d"
}

# Runs EXE there with ARGS until it exits (or SECS pass, then kills it); WAIT is 1 to
# wait for it, 0 to leave it open
run_there() {
    local exe=$1 secs=$2 wait=$3
    shift 3
    local dir
    dir=$(remote_dir)
    if [[ ${IN_GAME:-0} != 1 ]] && ssh "$HOST" "$S/tasklist.exe < /dev/null | grep -q '^League of Legends'"; then
        echo "shell.sh: a League game is running on $HOST: not opening a window over it (IN_GAME=1)" >&2
        exit 1
    fi
    if ssh "$HOST" "$S/tasklist.exe < /dev/null | grep -i -q meiolol-shell"; then
        echo "shell.sh: meiolol-shell is already running on $HOST (deploy/shell.sh stop)" >&2
        exit 1
    fi
    rsync -t "$exe" "$HOST:$dir/meiolol-shell.exe"
    # ssh joins its arguments into one command line: quoted, so ARGS stay one argument
    ssh "$HOST" bash -s -- "$(printf '%q ' "$dir" "$secs" "$wait" "$*")" <<'REMOTE'
set -u
dir=$1 secs=$2 wait=$3 args=$4
S=/mnt/c/Windows/System32
task=meiolol-shell-test
running() { $S/tasklist.exe < /dev/null | grep -i -q meiolol-shell; }
cd "$dir" || exit 1
rm -f measure.json shell-selftest.txt shell.log ./*.png
win=$(wslpath -w "$dir/meiolol-shell.exe")
# Windows exes under WSL read stdin: < /dev/null, or they eat the rest of this heredoc
$S/schtasks.exe /create /tn $task /tr "\"$win\" $args" /sc once /st 23:59 /it /f < /dev/null > /dev/null
$S/schtasks.exe /run /tn $task < /dev/null > /dev/null
start=$SECONDS
if [[ $wait == 1 ]]; then
    sleep 2
    until ! running || (( SECONDS - start > secs )); do sleep 1; done
fi
$S/schtasks.exe /delete /tn $task /f < /dev/null > /dev/null
if [[ $wait == 1 ]] && running; then
    echo "still running after $((SECONDS - start)) s: killing" >&2
    $S/taskkill.exe /f /t /im meiolol-shell.exe < /dev/null > /dev/null
fi
echo "ran $((SECONDS - start)) s"
REMOTE
}

fetch() {
    local out=$1 dir
    dir=$(remote_dir)
    mkdir -p "$out"
    rsync -t "$HOST:$dir/shell.log" "$HOST:$dir/measure.json" "$HOST:$dir/*.png" \
        "$HOST:$dir/shell-selftest.txt" "$out/" 2> /dev/null || true
}

with_pages() {
    local p=$main/data/shell-pages dir
    [[ -s $p/draft.html ]] || pages "$p" > /dev/null
    dir=$(remote_dir)
    rsync -rt --delete "$p/" "$HOST:$dir/pages/"
    ssh "$HOST" "wslpath -w '$dir/pages'"
}

case ${1:-} in
    build) build "${2:-}" ;;
    pages) pages "${2:-}" ;;
    smoke)
        exe=${2:-$(build private | tail -1)}
        out=$(mktemp -d)
        for l in internal dll; do
            run_there "$exe" 45 1 --self-test --loader $l > /dev/null
            fetch "$out"
            line=$(cat "$out/shell-selftest.txt" 2> /dev/null || echo "fail no result")
            echo "smoke ($l loader): $line"
            [[ $line == ok* ]] || { cat "$out/shell.log" 2> /dev/null; exit 1; }
            rm -f "$out/shell-selftest.txt"
        done
        ;;
    measure)
        out=${2:?usage: deploy/shell.sh measure OUT [ARGS...]}
        shift 2
        exe=$(build private | tail -1)
        dir=$(with_pages | tr -d '\r')
        run_there "$exe" 260 1 --measure --demo --dir "$dir" --page draft.html \
            --also champions.html --also zig-tree/table.html "$@"
        fetch "$out"
        [[ -s $out/measure.json ]] || { echo "shell.sh: no measure.json (log in $out)" >&2; exit 1; }
        echo "results in $out"
        ;;
    run)
        shift
        exe=$(build private | tail -1)
        run_there "$exe" 0 0 "$@"
        ;;
    stop) ssh "$HOST" "$S/taskkill.exe /t /im meiolol-shell.exe < /dev/null" || true ;;
    -h | --help | *) usage_of "$0"; [[ ${1:-} == -h || ${1:-} == --help ]] ;;
esac
