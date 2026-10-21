#!/usr/bin/env bash
# The desktop app's release: the only way a new meiolol-desktop.exe reaches players
# (pushes to main leave it alone, deploy/box.sh). On a clean checkout of REV (default
# HEAD; it must be on origin/main, so ci passed): the release checks, `zig build
# desktop-check` (core and app tests under ThreadSanitizer) and `zig build desktop-fuzz
# --fuzz=N` (the parsers for what the app downloads), then the exe in ReleaseSafe,
# numbered with the release (unix seconds: the app never installs an older one), signed
# with the release key from vault meiolol/desktop (src/desktop/sign.zig) and copied to
# the box's release/. The next web round lists it in update.signed (web-loop.sh
# desktop_files, hourly); installed apps take it within 3 h of that.
#   deploy/desktop-release.sh [REV] [--fuzz N]  N inputs per fuzz test, default 500K
#                                               (~10 min on the Mac)
#   deploy/desktop-release.sh status            the box's release and the past ones
set -euo pipefail

HOST=${MEIOLOL_HOST:-meiolol-cloud}
DIR=ml/meiolol
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HERE=$ROOT/deploy
# shellcheck source=deploy/lib.sh
. "$HERE/lib.sh"

fuzz=500K rev=
while [[ $# -gt 0 ]]; do
    case $1 in
        status)
            ssh "$HOST" "cd $DIR/release 2> /dev/null && cat meiolol-desktop.json RELEASES" \
                || echo "no release on the box yet"
            exit 0
            ;;
        --fuzz) fuzz=$2; shift ;;
        -h | --help) usage_of "$0"; exit 0 ;;
        *) rev=$1 ;;
    esac
    shift
done

git -C "$ROOT" fetch -q origin main
rev=$(git -C "$ROOT" rev-parse "${rev:-HEAD}")
git -C "$ROOT" merge-base --is-ancestor "$rev" origin/main \
    || { echo "desktop-release: ${rev:0:7} is not on origin/main: push it first"; exit 1; }
version=$(date -u +%s)
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

echo "desktop release $version from ${rev:0:7}: checks, fuzzing $fuzz inputs, build"
"$HERE/build-tree.sh" desktop "$rev" sh -c 'cache="$1/.zig-cache"
    zig build desktop-check --cache-dir "$cache" \
    && zig build desktop-fuzz --fuzz="$2" --cache-dir "$cache" \
    && zig build desktop -Doptimize=ReleaseSafe -Ddesktop-version="$3" --prefix "$4/desktop" \
        --cache-dir "$cache" \
    && zig build backend --prefix "$4/tool" --cache-dir "$cache"' _ "$ROOT" "$fuzz" "$version" "$out"

exe=$out/desktop/bin/meiolol-desktop.exe
vault run meiolol/desktop -- "$out/tool/bin/meiolol" desktop-sign exe \
    --key-env DESKTOP_RELEASE_KEY --version "$version" "$exe" > "$out/meiolol-desktop.json"

# The exe first: web-loop.sh skips a round whose json doesn't match it
ssh "$HOST" "mkdir -p $DIR/release/new"
scp -q "$exe" "$out/meiolol-desktop.json" "$HOST:$DIR/release/new/"
ssh "$HOST" "cd $DIR/release && mv new/meiolol-desktop.exe . && mv new/meiolol-desktop.json . \
    && echo '$version ${rev:0:7} $(date -u +%FT%TZ) $(wc -c < "$exe" | tr -d ' ') bytes' >> RELEASES"
echo "released $version (${rev:0:7}): the next web round publishes it (deploy/box.sh web status)"
