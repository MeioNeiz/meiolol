#!/usr/bin/env bash
# Deploys origin/main to the box and restarts the web loop, which uploads the site at
# once. Run in the background by deploy/hooks/reference-transaction; log in
# .git/meiolol-deploy.log. Pushes during a deploy coalesce into one more run.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
state=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)/meiolol-deploy
touch "$state.pending"
mkdir "$state.lock" 2>/dev/null || exit 0
while [[ -e "$state.pending" ]]; do
    rm -f "$state.pending"
    echo "$(date -u +%FT%TZ) deploying origin/main"
    REV=origin/main "$ROOT/deploy/box.sh" web start || echo "$(date -u +%FT%TZ) failed"
done
rmdir "$state.lock"
# A push that landed between the last check and rmdir
[[ -e "$state.pending" ]] && exec "$0"
exit 0
