#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): every 15 min, build the site and upload it to
# the jomove server when the patch changed, the current patch's game count grew 20% since
# the last upload, or there are any new games and an hour passed. So early in a patch (few
# games) it pushes every 15 min, later hourly. A build takes well under a second. The
# meiolol-web ssh alias is user meiolol with a key limited to rsync into /var/www/meiolol
# (rrsync); nginx there serves meiolol.jomify.lol. Riot's verification string, if any,
# lives in riot.txt beside bin/.
# Lane curves are rebuilt hourly and when the patch changes: the site's (`meiolol curves`,
# every patch of the last 30 days; EUW, and every region for the site's all/ view) and
# the current patch's for the Your games service; fresh site curves force an upload. The
# upload rules count EUW games only.
# Daily, `meiolol eval` (docs/model.md) appends a line to data/eval-history.tsv (model
# accuracy vs data volume) and leaves its report in data/eval-latest.md. Read-only on the
# DB; in the background at low priority, so a slow run never delays uploads.
set -u
contact=$1
cd "$(dirname "$0")/.." || exit 1

# The newest two curves files go to the Your games service on the web server (not the
# public site; docs/your-games.md). meiolol-exchange: rrsync into its exchange dir; a
# new file restarts the service there
push_curves() {
    local files
    files=$(ls -t data/export/curves-*.bin 2> /dev/null | head -2)
    [[ -n "$files" ]] || return 0
    rm -rf data/curves-push && mkdir -p data/curves-push
    # shellcheck disable=SC2086
    cp -p $files data/curves-push/
    rsync -a --delete data/curves-push/ meiolol-exchange:curves/ \
        || echo "$(date -u +%FT%TZ) curves push to the service FAILED"
}

last_patch='' last_games=0 last_upload=0
patch='' curves_patch='' last_curves=0 fresh_curves=0 last_eval=0
while true; do
    now=$(date +%s)
    if (( now - last_eval >= 86400 )); then
        (nice -n 10 bin/meiolol eval --platform all --test-platform EUW1 \
            --history data/eval-history.tsv > data/eval-latest.md.new 2> data/eval.log \
            && mv data/eval-latest.md.new data/eval-latest.md) &
        last_eval=$now
    fi
    if (( now - last_curves >= 3600 )) || [[ "$patch" != "$curves_patch" ]]; then
        # Fails harmlessly (logged) until there are timelines
        if c=$(bin/meiolol curves 2>&1); then fresh_curves=1; fi
        echo "$c"
        bin/meiolol curves --platform all 2>&1
        [[ -n "$patch" ]] && bin/meiolol curves --patch "$patch" 2>&1
        last_curves=$now curves_patch=$patch
        push_curves
    fi
    rm -rf data/site.new
    riot=()
    [[ -s riot.txt ]] && riot=(--riot-txt "$(<riot.txt)")
    if out=$(bin/meiolol site --contact "$contact" --out data/site.new "${riot[@]}" 2>&1); then
        # First log line, EUW: "data/site.new: patch 16.20, 1054 games, 173 champion pages"
        read -r patch games < <(sed -nE 's/.*: patch ([^,]+), ([0-9]+) games.*/\1 \2/p' \
            <<< "$out")
        now=$(date +%s)
        if [[ "$patch" != "$last_patch" ]] || (( games * 5 >= last_games * 6 )) \
            || (( games > last_games && now - last_upload >= 3600 )) \
            || (( fresh_curves )); then
            echo "$out"
            rm -rf data/site.old
            [ -d data/site ] && mv data/site data/site.old
            mv data/site.new data/site
            if rsync -a --delete-delay --delay-updates data/site/ meiolol-web:./; then
                echo "$(date -u +%FT%TZ) uploaded"
                last_patch=$patch last_games=$games last_upload=$now fresh_curves=0
            fi
        fi
    else
        echo "$out"
    fi
    sleep 900
done
