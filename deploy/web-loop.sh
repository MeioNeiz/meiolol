#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): every 15 min, build the site and upload it to
# the jomove server when the patch changed, the current patch's game count grew 20% since
# the last upload, or there are any new games and an hour passed. So early in a patch (few
# games) it pushes every 15 min, later hourly. A build takes well under a second. The
# meiolol-web ssh alias is user meiolol with a key limited to rsync into /var/www/meiolol
# (rrsync); nginx there serves meiolol.jomify.lol. Riot's verification string, if any,
# lives in riot.txt beside bin/.
# Lane curves are rebuilt hourly and when the patch changes, one file per site view (EUW
# and every region, by last 30 days and current patch; the EUW patch file is also the
# Your games service's); fresh site curves force an upload. The upload rules count EUW
# games on the current patch only.
# Daily, `meiolol eval` (docs/model.md) appends a line to data/eval-history.tsv (model
# accuracy vs data volume) and leaves its report in data/eval-latest.md. Read-only on the
# DB; in the background at low priority, so a slow run never delays uploads.
# Builds (`meiolol builds`, EUW and every region, current patch) the same way: daily and
# on a new patch, in the background; the next site build picks the files up.
# Every round, the private admin page (`meiolol admin`) goes to admin/ on the server,
# behind basic auth there; the site's rsync leaves that directory alone.
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
last_builds=0 builds_patch='' builds_pid=''
while true; do
    now=$(date +%s)
    # MEIOLOL_NO_EVAL (host.env): skipped on a box too small for it
    if [[ -z "${MEIOLOL_NO_EVAL:-}" ]] && (( now - last_eval >= 86400 )); then
        (nice -n 10 bin/meiolol eval --platform all --test-platform EUW1 \
            --history data/eval-history.tsv > data/eval-latest.md.new 2> data/eval.log \
            && mv data/eval-latest.md.new data/eval-latest.md) &
        last_eval=$now
    fi
    if [[ -n "$patch" ]] && { [[ -z "$builds_pid" ]] || ! kill -0 "$builds_pid" 2> /dev/null; } \
        && { (( now - last_builds >= 86400 )) || [[ "$patch" != "$builds_patch" ]]; }; then
        (nice -n 10 bin/meiolol builds --patch "$patch" \
            && nice -n 10 bin/meiolol builds --patch "$patch" --platform all) \
            > data/builds.log 2>&1 &
        builds_pid=$! last_builds=$now builds_patch=$patch
    fi
    if (( now - last_curves >= 3600 )) || [[ "$patch" != "$curves_patch" ]]; then
        # Fails harmlessly (logged) until there are timelines
        if c=$(bin/meiolol curves 2>&1); then fresh_curves=1; fi
        echo "$c"
        bin/meiolol curves --platform all 2>&1
        if [[ -n "$patch" ]]; then
            bin/meiolol curves --patch "$patch" 2>&1
            bin/meiolol curves --patch "$patch" --platform all 2>&1
        fi
        last_curves=$now curves_patch=$patch
        push_curves
    fi
    rm -rf data/site.new
    riot=()
    [[ -s riot.txt ]] && riot=(--riot-txt "$(<riot.txt)")
    if out=$(bin/meiolol site --contact "$contact" --out data/site.new "${riot[@]}" 2>&1); then
        # First patch line, EUW: "data/site.new/patch/: patch 16.20, 1054 games, ..."
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
            if rsync -a --delete-delay --delay-updates --exclude /admin/ data/site/ meiolol-web:./; then
                echo "$(date -u +%FT%TZ) uploaded"
                last_patch=$patch last_games=$games last_upload=$now fresh_curves=0
            fi
        fi
    else
        echo "$out"
    fi
    if nice -n 10 bin/meiolol admin --out data/admin.new \
        --disk "$(df -B1 --output=size,used,avail data | tail -n 1)" \
        --health "$(bin/health.sh)" 2>&1; then
        rm -rf data/admin && mv data/admin.new data/admin
        rsync -a --delete data/admin/ meiolol-web:admin/ || echo "$(date -u +%FT%TZ) admin upload FAILED"
    fi
    sleep 900
done
