#!/usr/bin/env bash
# The pre-push ci of one commit (deploy/hooks/pre-push): on the box when it can
# (remote-build.sh --host box: capped beside production, off the Mac's slots), with
# `zig build ci-mac` (the macOS-only compiles the box skips) on the Mac beside it, 1 slot.
# The Mac's own ci (3 slots, build tree "ci") only when the box didn't build it (exit
# 75: off, unreachable, no tools, disk short, its build busy 15 min, lost mid-build); a
# ci that fails on the box fails, never retried here. ui.wasm size baselines
# (.git/meiolol-wasm-sizes) go to the box before and come back after.
# docs/hosting.md "Builds on the box".
#   deploy/ci-run.sh SHA            exit: ci's
#   deploy/ci-run.sh off|on|status  box ci off or on, for every session
# MEIOLOL_CI_HOST=mac|box per call; MEIOLOL_CI_EVENTS=1 (pre-push) notes a fallback in
# the admin page's Deploys tab. Tests (deploy/flow-test.sh) stub the three builds:
# MEIOLOL_CI_BOX, MEIOLOL_CI_MAC, MEIOLOL_CI_MACONLY, each a command taking SHA
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
. "$root/deploy/lib.sh"
off=${MEIOLOL_CI_OFF:-$HOME/.cache/meiolol-ci/box-off}
host=${BOX_HOST:-essex-vm}
common=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir) || exit 1
sizes=$common/meiolol-wasm-sizes
box_sizes=meiolol-ci/repo.git/meiolol-wasm-sizes

case ${1-} in
    off) mkdir -p "$(dirname "$off")" && touch "$off" && echo "ci-run: box ci off: pre-push ci on the Mac"; exit 0 ;;
    on) rm -f "$off" && echo "ci-run: box ci on"; exit 0 ;;
    status)
        if [[ -f $off ]]; then echo "box ci off since $(date -r "$off" '+%d %b %H:%M')"; else echo "box ci on"; fi
        exit 0
        ;;
    '' | -*) usage_of "$0" >&2; exit 2 ;;
esac
sha=$(git -C "$root" rev-parse --verify -q "$1^{commit}") || { echo "ci-run: no commit $1" >&2; exit 2; }

box() {
    if [[ -n ${MEIOLOL_CI_BOX-} ]]; then "$MEIOLOL_CI_BOX" "$sha"; return; fi
    "$root/deploy/remote-build.sh" --host box --commit "$sha" ci
}
mac() {
    if [[ -n ${MEIOLOL_CI_MAC-} ]]; then "$MEIOLOL_CI_MAC" "$sha"; return; fi
    "$root/deploy/slots.sh" ci "$root/deploy/build-tree.sh" ci "$sha" \
        zig build ci --cache-dir "$common/meiolol-build/ci.cache"
}
maconly() {
    if [[ -n ${MEIOLOL_CI_MACONLY-} ]]; then "$MEIOLOL_CI_MACONLY" "$sha"; return; fi
    "$root/deploy/slots.sh" 1 "$root/deploy/build-tree.sh" ci "$sha" \
        zig build ci-mac --cache-dir "$common/meiolol-build/ci.cache"
}
fallback() {
    echo "ci-run: $1: ci on the Mac"
    [[ ${MEIOLOL_CI_EVENTS-} == 1 ]] && "$root/deploy/deploy-events.sh" add "$sha" ci info "$1: ci on the Mac"
    mac
}

case ${MEIOLOL_CI_HOST-} in
    mac) fallback "MEIOLOL_CI_HOST=mac"; exit $? ;;
    box | '') ;;
    *) echo "ci-run: MEIOLOL_CI_HOST is mac or box" >&2; exit 2 ;;
esac
[[ -f $off ]] && { fallback "box ci off (deploy/ci-run.sh on)"; exit $?; }

[[ -n ${MEIOLOL_CI_BOX-} ]] \
    || rsync -a --ignore-existing --timeout=10 "$sizes/" "$host:$box_sizes/" 2> /dev/null \
    || echo "ci-run: size baselines not sent to the box (unreachable?)"
log=$(mktemp)
maconly > "$log" 2>&1 &
mpid=$!
trap 'kill "$mpid" 2> /dev/null; rm -f "$log"' EXIT
trap 'exit 130' INT TERM HUP
echo "ci-run: ci on the box, ci-mac here beside it"
box
code=$?
wait "$mpid"
mcode=$?
sed 's/^/ci-mac: /' "$log"
if (( code == 75 )); then
    fallback "the box didn't build it"
    code=$?
elif (( code == 0 )) && [[ -z ${MEIOLOL_CI_BOX-} ]]; then
    rsync -a --ignore-existing --timeout=10 "$host:$box_sizes/" "$sizes/" 2> /dev/null \
        || echo "ci-run: size baselines not fetched from the box"
fi
(( mcode == 0 )) || echo "ci-run: ci-mac failed"
(( code == 0 && mcode == 0 ))
