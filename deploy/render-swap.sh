#!/usr/bin/env bash
# Replaces the running renderer (meiolol-render@a or @b) without a gap: starts the other
# instance with the current binary, both listening on the port (SO_REUSEPORT) while it
# loads, and stops the old once the new one is serving. If the new one isn't ready within
# 15 minutes, the old one stays. Run detached on the box by deploy/box.sh web start;
# again if the binary changed meanwhile. Log in data/render.log
set -uo pipefail
cd "$(dirname "$0")/.." || exit

log() { echo "$(date -u +%FT%TZ) render-swap: $*" >> data/render.log; }

while true; do
    binary=$(stat -c %Y bin/meiolol)
    new=a
    systemctl --user -q is-active meiolol-render@a && new=b
    old=()
    # meiolol-render: the single unit before instances
    for u in meiolol-render meiolol-render@a meiolol-render@b; do
        [[ $u != "meiolol-render@$new" ]] && systemctl --user -q is-active "$u" && old+=("$u")
    done
    rm -f "data/render-$new.ready"
    systemctl --user enable -q "meiolol-render@$new"
    systemctl --user restart "meiolol-render@$new"
    log "started meiolol-render@$new beside ${old[*]:-nothing}"
    start=$SECONDS
    until [[ -e data/render-$new.ready ]] || (( SECONDS - start >= 900 )); do sleep 2; done
    if [[ ! -e data/render-$new.ready ]]; then
        systemctl --user disable -q --now "meiolol-render@$new"
        log "meiolol-render@$new not ready in 15 min: stopped it, kept ${old[*]:-nothing}"
        exit 1
    fi
    for u in "${old[@]}"; do systemctl --user disable -q --now "$u"; done
    log "meiolol-render@$new serving; stopped ${old[*]:-nothing}"
    [[ $(stat -c %Y bin/meiolol) == "$binary" ]] && exit 0
done
