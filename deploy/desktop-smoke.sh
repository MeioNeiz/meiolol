#!/usr/bin/env bash
# Windows smoke start (docs/plan/libraries.md "Desktop release checks"): the exe and its
# data files go to the gpu-box's %LOCALAPPDATA%\meiolol-smoke (never Programs\meiolol,
# the real install) and run there with --self-test (src/desktop/selftest.zig: the files
# load, a lane card builds for each role, no window), from WSL through interop. Light:
# one process of a few seconds; rsync skips files already there. Data defaults to the
# shots' pinned inputs (deploy/desktop-shots.sh pin).
#   deploy/desktop-smoke.sh EXE [STATS CURVES]
set -euo pipefail

HOST=${MEIOLOL_GPU_HOST:-gpu-box}
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=deploy/lib.sh
. "$HERE/lib.sh"
main=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")

[[ $# -eq 1 || $# -eq 3 ]] || { usage_of "$0"; exit 2; }
exe=$1
stats=${2:-$main/data/desktop-shots/inputs/stats.bin}
curves=${3:-$main/data/desktop-shots/inputs/curves.bin}
for f in "$exe" "$stats" "$curves"; do
    [[ -s $f ]] || { echo "desktop-smoke: no file at $f" >&2; exit 1; }
done

# shellcheck disable=SC2016 # expanded on the gpu-box
dir=$(ssh "$HOST" 'd=$(wslpath "$(/mnt/c/Windows/System32/cmd.exe /c "echo %LOCALAPPDATA%" 2> /dev/null | tr -d "\r")")/meiolol-smoke && mkdir -p "$d" && echo "$d"')
[[ $dir == /mnt/* ]] || { echo "desktop-smoke: no Windows folder on $HOST ($dir)" >&2; exit 1; }
# Names the app looks for (datafiles.zig)
rsync -t "$exe" "$HOST:$dir/meiolol-desktop.exe"
rsync -t "$stats" "$HOST:$dir/stats-smoke.bin"
rsync -t "$curves" "$HOST:$dir/recent-curves.bin"
if ssh "$HOST" "cd '$dir' && timeout 120 ./meiolol-desktop.exe --self-test"; then
    echo "desktop-smoke: $(basename "$exe") started on $HOST's Windows and read its files"
else
    echo "desktop-smoke: the self-test failed on $HOST (exit $?)" >&2
    exit 1
fi
