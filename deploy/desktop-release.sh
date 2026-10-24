#!/usr/bin/env bash
# The desktop app's release: the only way a new meiolol-desktop.exe reaches players
# (pushes to main leave it alone, deploy/box.sh). On a clean checkout of REV (default
# HEAD; it must be on origin/main, so ci passed): the release checks, `zig build
# desktop-check` (core and app tests under ThreadSanitizer) and `zig build desktop-fuzz
# --fuzz=N` (the parsers for what the app downloads, one fuzz test at a time: given a
# binary's several, `zig build --fuzz` searched only one), then both editions in ReleaseSafe
# (docs/plan/app.md "Two editions"), numbered with the release (unix seconds: the app
# never installs an older one); the public one holds no private module
# (deploy/check-edition.sh), the window looks as approved (deploy/desktop-shots.sh) and
# each edition starts on the gpu-box's Windows (deploy/desktop-smoke.sh). Both are signed
# with the release key from vault meiolol/desktop (src/desktop/sign.zig): the private
# one goes to the box's release/, whose next web round lists it in update.signed
# (web-loop.sh desktop_files, hourly; installed apps take it within 3 h of that), the
# public one to release/public/, kept but served nowhere until the public channel.
#   deploy/desktop-release.sh [REV] [--fuzz N]  N inputs per fuzz test, default 200K
#                                               (1 to 5 min each on the Mac)
#     --dry-run                                 checks and builds only: nothing signed
#                                               or copied, the exes left in a temp dir
#     --no-smoke                                skip the Windows start (gpu-box down)
#   deploy/desktop-release.sh status            the box's release and the past ones
set -euo pipefail

HOST=${MEIOLOL_HOST:-meiolol-cloud}
DIR=ml/meiolol
ROOT=$(cd "$(dirname "$0")/.." && pwd)
HERE=$ROOT/deploy
# shellcheck source=deploy/lib.sh
. "$HERE/lib.sh"

fuzz=200K rev='' dry=0 smoke=1
while [[ $# -gt 0 ]]; do
    case $1 in
        status)
            ssh "$HOST" "cd $DIR/release 2> /dev/null && cat meiolol-desktop.json RELEASES" \
                || echo "no release on the box yet"
            exit 0
            ;;
        --fuzz) fuzz=$2; shift ;;
        --dry-run) dry=1 ;;
        --no-smoke) smoke=0 ;;
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
((dry)) || trap 'rm -rf "$out"' EXIT
# Every fuzz test in the desktop binaries (core, app, net); one in none of them fails below
git -C "$ROOT" grep -h -o 'test "fuzz:[^"]*"' "$rev" -- src/core src/desktop src/lcu src/net \
    src/lanecard.zig | sed 's/^test "//; s/"$//' | sort -u > "$out/fuzz-tests"

echo "desktop release $version from ${rev:0:7}: checks, fuzzing $fuzz inputs, build"
# Fuzzing in the release tree's own cache: its corpus there is the release's, and two
# fuzzers on one corpus stop with "in use by another fuzzer". `zig build --fuzz` exits 0
# when a fuzz test crashes (21 Oct: a crash was released that way), so its log decides
"$HERE/build-tree.sh" desktop "$rev" sh -c 'set -e
    cache="$1/.zig-cache"
    zig build desktop-check --cache-dir "$cache"
    while IFS= read -r name; do
        zig build desktop-fuzz --fuzz="$2" -Dtest-filter="$name" > "$4/fuzz.log" 2>&1 || true
        if grep -q "terminated with signal\|failed command\|exited with code" "$4/fuzz.log" \
            || ! grep -q "Fuzz test:" "$4/fuzz.log"; then
            cat "$4/fuzz.log"
            echo "desktop-release: fuzzing $name failed (above), nothing released"
            exit 1
        fi
        echo "fuzz ok $name: $(grep -o "Runs: .*" "$4/fuzz.log" | head -1)"
    done < "$4/fuzz-tests"
    for e in private public; do
        zig build desktop -Doptimize=ReleaseSafe -Dedition=$e -Ddesktop-version="$3" \
            --prefix "$4/$e" --cache-dir "$cache"
    done
    deploy/check-edition.sh "$4/public/bin/meiolol-desktop.exe" "$4/private/bin/meiolol-desktop.exe"
    deploy/desktop-shots.sh check || {
        echo "desktop-release: the window changed (above): look, then deploy/desktop-shots.sh approve"
        exit 1
    }
    if [ "$5" = 1 ]; then
        for e in private public; do deploy/desktop-smoke.sh "$4/$e/bin/meiolol-desktop.exe"; done
    fi
    zig build backend --prefix "$4/tool" --cache-dir "$cache"' _ "$ROOT" "$fuzz" "$version" "$out" "$smoke"

if ((dry)); then
    echo "dry run: both editions built and checked in $out/{private,public}; nothing signed or copied"
    exit 0
fi
for e in private public; do
    vault run meiolol/desktop -- "$out/tool/bin/meiolol" desktop-sign exe --key-env DESKTOP_RELEASE_KEY \
        --version "$version" "$out/$e/bin/meiolol-desktop.exe" > "$out/$e/meiolol-desktop.json"
done
exe=$out/private/bin/meiolol-desktop.exe

# The exe first: web-loop.sh skips a round whose json doesn't match it
ssh "$HOST" "mkdir -p $DIR/release/new $DIR/release/public"
scp -q "$out/public/bin/meiolol-desktop.exe" "$out/public/meiolol-desktop.json" "$HOST:$DIR/release/public/"
scp -q "$exe" "$out/private/meiolol-desktop.json" "$HOST:$DIR/release/new/"
ssh "$HOST" "cd $DIR/release && mv new/meiolol-desktop.exe . && mv new/meiolol-desktop.json . \
    && echo '$version ${rev:0:7} $(date -u +%FT%TZ) $(wc -c < "$exe" | tr -d ' ') bytes' >> RELEASES"
echo "released $version (${rev:0:7}): the next web round publishes it (deploy/box.sh web status)"
