#!/usr/bin/env bash
# Gives every page a copy in jomify's nginx cache under the current data version, so
# nginx has one to serve while the box is down or restarting: each version starts the
# cache cold (deploy/cache-version.sh), and a page not requested since has nothing to
# fall back on. Requests every page and file the renderer serves (/admin/api/pages.txt)
# through nginx, the site's most visited first (data/cache-warm-top.txt, from jomify's
# traffic.json), over the private network. Pages render from memory in milliseconds, so
# one at a time, paced: a little CPU and no disk, which the crawler needs. Stops when
# the version changes (that one's run starts over). meiolol-cache-warm.service,
# restarted by cache-version.sh after each version. Log in data/render.log
set -uo pipefail
cd "$(dirname "$0")/.." || exit

RATE=${MEIOLOL_WARM_RATE:-20/s}
CHUNK=200
log() { echo "$(date -u +%FT%TZ) cache-warm: $*" >> data/render.log; }

version=$(cat data/cache-version 2> /dev/null)
[[ $version =~ ^[0-9a-f]{16}$ ]] || exit 0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# The token on stdin, not in argv where ps shows it
if ! printf 'header = "X-Meiolol-Admin: %s"\n' "$(cat admin.token)" \
    | curl -sf --max-time 60 -K - -o "$tmp/pages" \
        "http://$(hostname -I | cut -d' ' -f1):8091/admin/api/pages.txt"; then
    log "no page list from the renderer"
    exit 1
fi
# Plain paths only: the top ones come from visitors' requests, and each goes into a curl
# config line
cat data/cache-warm-top.txt "$tmp/pages" 2> /dev/null | grep -E '^/[A-Za-z0-9._/-]*$' \
    | awk '!seen[$0]++' > "$tmp/urls"
total=$(wc -l < "$tmp/urls")
split -l "$CHUNK" "$tmp/urls" "$tmp/chunk."
start=$SECONDS
touch "$tmp/status"
for c in "$tmp"/chunk.*; do
    if [[ $(cat data/cache-version 2> /dev/null) != "$version" ]]; then
        log "version $version replaced after $(wc -l < "$tmp/status") of $total: stopped"
        exit 0
    fi
    # Unlogged by jomify's nginx (this user agent), so traffic.json counts visitors only
    sed 's|.*|url = "https://meio.lol&"\noutput = /dev/null|' "$c" \
        | curl -s -K - --rate "$RATE" --max-time 30 --resolve meio.lol:443:10.0.0.214 \
            -A meiolol-cache-warm -H 'Accept-Encoding: gzip' \
            -w '%{http_code} %header{x-meiolol-render}\n' >> "$tmp/status"
done
summary=$(awk '{n[$1 ($2 == "" ? "" : "/" $2)]++} END {for (k in n) printf "%s %d, ", k, n[k]}' \
    "$tmp/status")
log "version $version: $total paths in $((SECONDS - start)) s (${summary%, })"
