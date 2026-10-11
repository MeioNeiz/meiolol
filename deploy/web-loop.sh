#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): every 15 min, build the site and upload it to
# the jomove server when the current patch's game count grew 20% since the last upload,
# the patch changed, or a day passed. So early in a patch (few games) it pushes often,
# later about daily. A build takes well under a second. The meiolol-web ssh alias is user
# meiolol with a key limited to rsync into /var/www/meiolol (rrsync); nginx there serves
# meiolol.jomify.lol. Riot's verification string, if any, lives in riot.txt beside bin/.
set -u
contact=$1
cd "$(dirname "$0")/.." || exit 1
last_patch='' last_games=0 last_upload=0
while true; do
    rm -rf data/site.new
    riot=()
    [[ -s riot.txt ]] && riot=(--riot-txt "$(<riot.txt)")
    if out=$(bin/meiolol site --contact "$contact" --out data/site.new "${riot[@]}" 2>&1); then
        # Log line: "data/site.new: patch 16.20, 1054 games, 173 champion pages"
        read -r patch games < <(sed -nE 's/.*: patch ([^,]+), ([0-9]+) games.*/\1 \2/p' \
            <<< "$out")
        now=$(date +%s)
        if [[ "$patch" != "$last_patch" ]] || (( games * 5 >= last_games * 6 )) \
            || (( now - last_upload >= 86400 )); then
            echo "$out"
            rm -rf data/site.old
            [ -d data/site ] && mv data/site data/site.old
            mv data/site.new data/site
            if rsync -a --delete-delay --delay-updates data/site/ meiolol-web:./; then
                echo "$(date -u +%FT%TZ) uploaded"
                last_patch=$patch last_games=$games last_upload=$now
            fi
        fi
    else
        echo "$out"
    fi
    sleep 900
done
