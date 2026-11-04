#!/usr/bin/env bash
# One memory-heavy run on the Mac at a time, for every session: a truth run on
# cubes-20261104b takes ~16 GB in its first minute, of the Mac's 24 GB; three at once
# (4 Nov 22:15) swapped 25 of 27 GB, load 75, the Mac unusable. Its own gate, apart from
# the build slots (deploy/slots.sh), so builds go on beside the one heavy run.
# Killing this script kills the run, so no run outlives the session that started it.
#   deploy/heavy.sh CMD [ARG...]   wait for the gate, then run CMD
#   deploy/heavy.sh status         the run holding it and any waiting
set -u
here=$(cd "$(dirname "$0")" && pwd)
export MEIOLOL_SLOTS_DIR=${MEIOLOL_HEAVY_DIR:-$HOME/.cache/meiolol-heavy}
export MEIOLOL_SLOTS=1
# shellcheck source=deploy/slots.sh
. "$here/slots.sh"
case ${1-} in
    status) slots_status ;;
    "") echo "usage: deploy/heavy.sh CMD [ARG...] | status" >&2; exit 2 ;;
    *)
        child=""
        cleanup() {
            [ -z "$child" ] || kill "$child" 2> /dev/null
            slots_release
        }
        trap cleanup EXIT
        trap 'exit 130' INT TERM HUP
        slots_enqueue 1
        said=""
        until slots_take; do
            [ -n "$said" ] || { echo "heavy: waiting for the run in deploy/heavy.sh status" >&2; said=1; }
            sleep 2
        done
        "$@" &
        child=$!
        wait "$child"
        code=$?
        child=""
        exit "$code"
        ;;
esac
