#!/usr/bin/env bash
# Keeps a copy of every page in jomify's nginx cache for it to serve while the box is
# down or restarting. Copies under the current data version (deploy/cache-version.sh)
# are only what visitors asked for since it changed, often every few minutes during
# deploys; this fills "<uri>|any" instead (X-Meiolol-Warm: 1, honoured from the box
# only: always fetched anew and stored whatever the version), which nginx's @render_any
# serves when there is no current copy. Requests every page and file the renderer serves
# (/admin/api/pages.txt) through nginx, the site's most visited first
# (data/cache-warm-top.txt, from jomify's traffic.json), over the private network.
# Pages render from memory in milliseconds, so one at a time, paced: a little CPU and no
# disk, which the crawler needs. Again while the version changed during a run.
# meiolol-cache-warm.service, started by cache-version.sh. Log in data/render.log
set -uo pipefail
cd "$(dirname "$0")/.." || exit

RATE=${MEIOLOL_WARM_RATE:-20/s}
log() { echo "$(date -u +%FT%TZ) cache-warm: $*" >> data/render.log; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
while true; do
    version=$(cat data/cache-version 2> /dev/null)
    [[ $version =~ ^[0-9a-f]{16}$ ]] || exit 0
    # The token on stdin, not in argv where ps shows it
    if ! printf 'header = "X-Meiolol-Admin: %s"\n' "$(cat admin.token)" \
        | curl -sf --max-time 60 -K - -o "$tmp/pages" \
            "http://$(hostname -I | cut -d' ' -f1):8091/admin/api/pages.txt"; then
        log "no page list from the renderer"
        exit 1
    fi
    # Plain paths only: the top ones come from visitors' requests, and each goes into a
    # curl config line
    cat data/cache-warm-top.txt "$tmp/pages" 2> /dev/null | grep -E '^/[A-Za-z0-9._/-]*$' \
        | awk '!seen[$0]++' > "$tmp/urls"
    start=$SECONDS
    # Unlogged by jomify's nginx (this user agent), so traffic.json counts visitors only
    sed 's|.*|url = "https://meio.lol&"\noutput = /dev/null|' "$tmp/urls" \
        | curl -s -K - --rate "$RATE" --max-time 30 --resolve meio.lol:443:10.0.0.214 \
            -A meiolol-cache-warm -H 'X-Meiolol-Warm: 1' -H 'Accept-Encoding: gzip' \
            -w '%{http_code} %header{x-meiolol-render}\n' > "$tmp/status"
    summary=$(awk '{n[$1 ($2 == "" ? "" : "/" $2)]++} END {for (k in n) printf "%s %d, ", k, n[k]}' \
        "$tmp/status")
    log "$(wc -l < "$tmp/urls") paths of version $version in $((SECONDS - start)) s (${summary%, })"
    [[ $(cat data/cache-version 2> /dev/null) == "$version" ]] && exit 0
done
