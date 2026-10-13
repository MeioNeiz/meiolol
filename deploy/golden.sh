#!/usr/bin/env bash
# Golden numbers: reruns the reference models of docs/golden.tsv on the pinned snapshot
# (gpu-box, through lab-run) and checks each reproduces its published log loss to the
# last digit, so a tooling or numeric change that shifts results shows. Test cases rerun
# a look already taken, with a scratch --lab: no new look, nothing chosen on it.
#
#   deploy/golden.sh [--commit SHA] [CASE...]   default HEAD, every case
#
# Exit 0 when every case matches, 1 when one doesn't (a finding: report it, never edit the
# expected value), 2 on a run that failed to give a number
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH=$HOME/.local/bin:$PATH
# shellcheck disable=SC2088 # expands on the host
SNAP='~/ml/snaps/snap-20261012T2055Z'
COMMIT=HEAD
if [[ ${1:-} == --commit ]]; then
    COMMIT=$2
    shift 2
fi
COMMIT=$(git -C "$ROOT" rev-parse --short "$COMMIT")
want=("$@")

# One entry per started case (bash 3.2 on the Mac: no associative arrays)
names=() runs=() expected=() rows=() fields=()
while IFS=$'\t' read -r name cand args r f exp _; do
    [[ -z $name || $name == \#* ]] && continue
    if (( ${#want[@]} )) && [[ ! " ${want[*]} " == *" $name "* ]]; then continue; fi
    # shellcheck disable=SC2086 # args are words for meiolol-lab and bash on the host
    out=$("$ROOT/deploy/lab-run.sh" start gpu-box "golden-$name" --commit "$COMMIT" \
        --build-arg "-Dcand=src/lab/cand/$cand" --res cpu -- ${args//SNAP/$SNAP} 2>&1 < /dev/null) || {
        echo "$name: start failed: $out"
        exit 2
    }
    id=$(sed -n 's/^started \([^ ]*\) on .*/\1/p' <<< "$out")
    [[ -n $id ]] || { echo "$name: no run started: $out"; exit 2; }
    names+=("$name") runs+=("$id") expected+=("$exp") rows+=("$r") fields+=("$f")
    echo "$name: $id"
done < "$ROOT/docs/golden.tsv"

"$ROOT/deploy/lab-run.sh" wait "${runs[@]}" > /dev/null

bad=0
echo
echo "| case | run | expected | got | |"
echo "| --- | --- | --- | --- | --- |"
for i in "${!names[@]}"; do
    got=$("$ROOT/deploy/lab-run.sh" logs gpu-box "${runs[$i]}" 400 \
        | awk -F'|' -v r="${rows[$i]}" -v f="${fields[$i]}" 'index($0, r) == 1 { gsub(/ /, "", $f); v = $f } END { print v }')
    if [[ -z $got ]]; then
        verdict="NO NUMBER"
        (( bad < 2 )) && bad=2
    elif [[ $got == "${expected[$i]}" ]]; then
        verdict=ok
    else
        verdict=MISMATCH
        (( bad == 0 )) && bad=1
    fi
    echo "| ${names[$i]} | ${runs[$i]} | ${expected[$i]} | ${got:--} | $verdict |"
done
exit "$bad"
