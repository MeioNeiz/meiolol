#!/usr/bin/env bash
# Fuzzing the backend's untrusted input (`zig build backend-fuzz`: Riot match and
# timeline JSON, stored compact timelines and digests, raw packs, API requests and the
# Your games report) on a clean checkout of REV (default HEAD: commit first, the
# working tree is never read). Before a crawler, storage or API change; slower than ci,
# so not in it. Exits 1 when a fuzz test crashes, fails or doesn't build:
# `zig build --fuzz` exits 0 on all three, so its log decides.
#   deploy/backend-fuzz.sh [REV] [--fuzz N] [--test NAME] [-j N]
#       N inputs per fuzz test (default 200K, 1 to 30 min each on the Mac); --test:
#       only fuzz tests whose name has NAME (repeatable); -j: zig jobs (default 2, the
#       Mac is shared). The crashing input lands in the tree's .zig-cache/f/crash
# One `zig build --fuzz` per test: given a binary's several fuzz tests at once, it
# searched (and reported) only one of them
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HERE=$ROOT/deploy
# shellcheck source=deploy/lib.sh
. "$HERE/lib.sh"

fuzz=200K jobs=2 rev=
tests=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --fuzz) fuzz=$2; shift ;;
        --test) tests+=("$2"); shift ;;
        -j) jobs=$2; shift ;;
        -h | --help) usage_of "$0"; exit 0 ;;
        *) rev=$1 ;;
    esac
    shift
done
rev=$(git -C "$ROOT" rev-parse "${rev:-HEAD}")
names=()
while IFS= read -r name; do
    if [ ${#tests[@]} -eq 0 ]; then
        names+=("$name")
    else
        for t in "${tests[@]}"; do
            [[ $name == *"$t"* ]] && { names+=("$name"); break; }
        done
    fi
done < <(git -C "$ROOT" grep -h -o 'test "fuzz:[^"]*"' "$rev" -- src/riot src/api src/store \
    | sed 's/^test "//; s/"$//')
[ ${#names[@]} -gt 0 ] || { echo "backend-fuzz: no fuzz test matches"; exit 1; }
log=$(mktemp)
trap 'rm -f "$log"' EXIT

echo "backend-fuzz ${rev:0:7}: ${#names[@]} fuzz tests, $fuzz inputs each"
bad=0
for name in "${names[@]}"; do
    # The tree's own cache keeps its corpus between runs; two fuzzers on one corpus
    # stop with "in use by another fuzzer", and build-tree.sh's lock keeps it to one
    "$HERE/build-tree.sh" backend-fuzz "$rev" \
        nice -n 10 zig build backend-fuzz --fuzz="$fuzz" -j"$jobs" -Dtest-filter="$name" \
        > "$log" 2>&1 || true
    if grep -q "terminated with signal\|failed command\|exited with code" "$log" \
        || ! grep -q "Fuzz test:" "$log"; then
        cat "$log"
        echo "backend-fuzz: FAILED $name"
        bad=1
    else
        echo "ok $name: $(grep -o 'Runs: .*' "$log" | head -1)"
    fi
done
[ $bad = 0 ] || exit 1
echo "backend-fuzz: no crash"
