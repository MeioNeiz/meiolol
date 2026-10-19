#!/usr/bin/env bash
# Puts the version of the data the renderer serves (its --ready file) in jomify's nginx
# cache key, so a swap or reload shows at once rather than after the 10 min cache; pages
# cached under an older version are never read again and expire (inactive=30d). Run by
# meiolol-cache-version.path when a renderer writes its ready file, and by render-swap.sh
# once the old renderer has stopped: while two serve (mid-swap) it does nothing, as the
# old one could still fill the new key. ssh alias meiolol-cache: user meiolol on jomify,
# a key whose forced command is deploy/cache-version-receive.sh (docs/hosting.md
# "Rendering on request"). Log in data/render.log
set -uo pipefail
cd "$(dirname "$0")/.." || exit

log() { echo "$(date -u +%FT%TZ) cache-version: $*" >> data/render.log; }
. bin/box-lib.sh

serving=()
for i in a b; do systemctl --user -q is-active "meiolol-render@$i" && serving+=("$i"); done
(( ${#serving[@]} == 1 )) || exit 0
version=$(cat "data/render-${serving[0]}.ready" 2> /dev/null)
[[ $version =~ ^[0-9a-f]{16}$ ]] || exit 0
[[ $version == "$(cat data/cache-version 2> /dev/null)" ]] && exit 0
# It answers with the site's most visited paths, which cache-warm.sh requests first
if top=$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 meiolol-cache <<< "$version"); then
    echo "$version" > data/cache-version
    log "nginx cache key now $version (meiolol-render@${serving[0]})"
    deploy_event "$(deployed_sha)" cache ok "nginx cache key $version (meiolol-render@${serving[0]})"
    [[ -n $top ]] && printf '%s\n' "$top" > data/cache-warm-top.txt
    # A run under way finishes, then runs again for this version
    systemctl --user start --no-block meiolol-cache-warm
else
    log "sending $version to jomify FAILED: retrying in a minute"
    deploy_event "$(deployed_sha)" cache failed "sending $version to jomify failed: retrying in a minute"
    exit 1
fi
