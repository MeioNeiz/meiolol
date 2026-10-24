#!/usr/bin/env bash
# The desktop window's shots against an approved set (docs/plan/libraries.md "Desktop
# release checks"): `zig build desktop-shot --compare` renders every state from pinned
# inputs and compares pixel for pixel, so a UI change nobody looked at stops a release
# (deploy/desktop-release.sh runs `check`). A changed shot gets NAME.diff.png beside it
# in last/ (changes red on the dimmed new shot); look, then approve. Everything lives in
# the main checkout's data/desktop-shots (gitignored, ~15 MB): inputs/ (stats.bin,
# curves.bin, icons/, champ-facts.tsv), approved/, last/ (the latest check's renders).
# Renders the tree it runs in, ReleaseSafe as both approve and check (float rounding
# may differ by mode).
#   deploy/desktop-shots.sh check [NAME]        render (NAME: only shots containing it)
#                                               and compare; exit 1 on any difference
#   deploy/desktop-shots.sh approve             last/'s shots become the approved ones
#   deploy/desktop-shots.sh pin STATS CURVES [ICONS [FACTS]]
#                                               new inputs: every shot changes, so check
#                                               and approve after
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=deploy/lib.sh
. "$HERE/lib.sh"
# The main checkout's data, also from a build tree (.git/meiolol-build/NAME)
main=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
shots=$main/data/desktop-shots

case ${1:-} in
    check)
        [[ -f $shots/inputs/stats.bin ]] \
            || { echo "desktop-shots: no inputs: deploy/desktop-shots.sh pin first" >&2; exit 1; }
        [[ -d $shots/approved ]] \
            || { echo "desktop-shots: nothing approved yet: check, look at last/, approve" >&2; }
        rm -rf "$shots/last"
        mkdir -p "$shots/last" "$shots/approved"
        only=()
        [[ -z ${2:-} ]] || only=(--only "$2")
        extra=()
        [[ ! -d $shots/inputs/icons ]] || extra=(--icons "$shots/inputs/icons")
        [[ ! -f $shots/inputs/champ-facts.tsv ]] \
            || extra+=(--facts "$shots/inputs/champ-facts.tsv")
        rc=0
        zig build desktop-shot -Doptimize=ReleaseSafe -- --stats "$shots/inputs/stats.bin" \
            --curves "$shots/inputs/curves.bin" ${extra[@]+"${extra[@]}"} \
            --out "$shots/last" --compare "$shots/approved" ${only[@]+"${only[@]}"} \
            > "$shots/last/check.log" 2>&1 || rc=$?
        grep -E 'NEW|CHANGED|differ|error|panic' "$shots/last/check.log" | sed "s#$shots/last/##" || true
        if ((rc != 0)); then
            echo "desktop-shots: shots differ or the render failed (above, last/check.log): look in $shots/last" >&2
            exit 1
        fi
        echo "desktop-shots: $(find "$shots/last" -name '*.png' | wc -l | tr -d ' ') shots match the approved ones"
        ;;
    approve)
        [[ -d $shots/last ]] || { echo "desktop-shots: no last/: check first" >&2; exit 1; }
        mkdir -p "$shots/approved"
        n=0
        for f in "$shots"/last/*.png; do
            [[ $f == *.diff.png ]] && continue
            cp "$f" "$shots/approved/"
            n=$((n + 1))
        done
        echo "desktop-shots: approved $n shots"
        ;;
    pin)
        [[ $# -ge 3 ]] || { usage_of "$0"; exit 2; }
        mkdir -p "$shots/inputs"
        cp "$2" "$shots/inputs/stats.bin"
        cp "$3" "$shots/inputs/curves.bin"
        if [[ -n ${4:-} ]]; then
            rm -rf "$shots/inputs/icons"
            cp -R "$4" "$shots/inputs/icons"
        fi
        [[ -z ${5:-} ]] || cp "$5" "$shots/inputs/champ-facts.tsv"
        echo "desktop-shots: inputs pinned; check, look at last/, approve"
        ;;
    *) usage_of "$0"; exit 2 ;;
esac
