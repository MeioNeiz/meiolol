#!/usr/bin/env bash
# Deploys origin/main to the box and signals the web loop, which builds and uploads the
# site at once (deploy/box.sh web start). Run in the background by
# deploy/hooks/reference-transaction; log in .git/meiolol-deploy.log. Pushes during a
# deploy coalesce into one more run.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
state=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/meiolol-deploy
touch "$state.pending"
mkdir "$state.lock" 2>/dev/null || exit 0
while [[ -e "$state.pending" ]]; do
    rm -f "$state.pending"
    # Docs and research pushes change nothing on the box: skip the build and site round
    deployed=$(ssh "${MEIOLOL_HOST:-meiolol-cloud}" "tail -n 1 ml/meiolol/DEPLOYED" 2> /dev/null \
        | cut -d' ' -f1)
    if [[ -n "$deployed" ]] && git -C "$ROOT" cat-file -e "$deployed^{commit}" 2> /dev/null \
        && git -C "$ROOT" diff --quiet "$deployed" origin/main -- src deploy build.zig build.zig.zon; then
        echo "$(date -u +%FT%TZ) origin/main: nothing to deploy since ${deployed:0:7}"
        continue
    fi
    echo "$(date -u +%FT%TZ) deploying origin/main"
    REV=origin/main "$ROOT/deploy/box.sh" web start || echo "$(date -u +%FT%TZ) failed"
done
rmdir "$state.lock"
# A push that landed between the last check and rmdir
[[ -e "$state.pending" ]] && exec "$0"
exit 0
