#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): daily, build the site, swap it in only
# when the build succeeds, and upload it to the jomove server. The meiolol-web ssh alias
# is user meiolol with a key limited to rsync into /var/www/meiolol (rrsync); nginx
# there serves meiolol.jomify.lol.
set -u
contact=$1
cd "$(dirname "$0")/.."
while true; do
    rm -rf data/site.new
    if bin/meiolol site --contact "$contact" --out data/site.new; then
        rm -rf data/site.old
        [ -d data/site ] && mv data/site data/site.old
        mv data/site.new data/site
        rsync -a --delete-delay --delay-updates data/site/ meiolol-web:./ \
            && echo "$(date -u +%FT%TZ) uploaded"
    fi
    sleep 86400
done
