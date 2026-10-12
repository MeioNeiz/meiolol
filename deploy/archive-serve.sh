#!/usr/bin/env bash
# On the box: forced command of the gpu-box's archive key in ~/.ssh/authorized_keys
# (docs/data-safety.md "Raw archive"), so that key can do only this. The gpu-box runs
# deploy/archive-pull.sh, which calls: export, list, send NAME, ack NAME, forgotten
set -euo pipefail
cd "$HOME/ml/meiolol"
out=data/archive-out
read -r cmd arg _ <<< "${SSH_ORIGINAL_COMMAND:-}"
name() { [[ "$arg" =~ ^raw-[0-9]+-[0-9]+\.db$ ]] || { echo "bad export name" >&2; exit 2; }; }
case "${cmd:-}" in
    export) exec nice -n 10 bin/meiolol raw-export --data data --out "$out" ;;
    list)
        shopt -s nullglob
        for f in "$out"/raw-*.db; do echo "$(basename "$f") $(stat -c %s "$f")"; done
        ;;
    send) name; exec cat "$out/$arg" ;;
    ack) name; exec nice -n 10 bin/meiolol raw-export --data data --out "$out" --ack "$arg" ;;
    forgotten)
        tmp=$(mktemp)
        bin/meiolol forget --data data --export "$tmp" > /dev/null 2>&1
        cat "$tmp"
        rm -f "$tmp"
        ;;
    status) exec bin/meiolol raw-export --data data --status ;;
    *) echo "archive-serve: export|list|send NAME|ack NAME|forgotten|status" >&2; exit 2 ;;
esac
