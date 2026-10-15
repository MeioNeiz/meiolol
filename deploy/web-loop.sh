#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): every 15 min, build the site and upload it to
# the jomove server when the patch changed, the current patch's game count grew 20% since
# the last upload, or there are any new games and an hour passed. So early in a patch (few
# games) it pushes every 15 min, later hourly. The build is `--static core`: the home
# page, robots.txt, riot.txt, the root sitemap and the front-end files (~30 files, two
# views loaded); meiolol-render serves every other page and file. After each upload,
# `meiolol site --views` loads every view from the database into data/views.bin and
# touches data/render.reload: the renderer reads that file in seconds, so the
# database work happens once, here (docs/hosting.md "Rendering on request"). The
# meiolol-web ssh alias is user meiolol with a key limited to rsync into /var/www/meiolol
# (rrsync); nginx there serves meiolol.jomify.lol. Riot's verification string, if any,
# lives in riot.txt beside bin/.
# Lane curves are rebuilt hourly and when the patch changes, one file per site view (EUW
# and every region, by last 30 days and current patch; the EUW patch file is also the
# Your games service's), all four in one pass over the timelines (`meiolol curves
# --site`); fresh site curves force an upload. The upload rules count EUW
# games on the current patch only.
# Daily, `meiolol eval` (docs/model.md) appends a line to data/eval-history.tsv (model
# accuracy vs data volume) and leaves its report in data/eval-latest.md. Read-only on the
# DB; in the background at low priority, so a slow run never delays uploads. One at a
# time with the admin page's Run eval (src/admin_api.zig): both flock data/eval.lock.
# Builds (`meiolol builds`, EUW and every region, current patch) the same way: daily and
# on a new patch, in the background; the next site build picks the files up.
# Daily, `meiolol lean` (every region, last 30 days; docs/model.md "Early and late
# champions") the same way: data/lean.tsv, the champion pages' early or late line.
# Daily, `meiolol your-example` (read-only, background) leaves one anonymised player's
# games in data/your-example.json, which meiolol-render serves at the same path from its
# next load, for your.html's and the home page's example. A failed run removes the file,
# so a stale example (perhaps a player forgotten since) never ships; the pages then offer
# none until the next success.
# Every round, the private admin page (`meiolol admin`) goes to admin/ on the server,
# behind basic auth there; the site's rsync leaves that directory alone. Daily, a dbstat
# scan (system sqlite3, read-only) leaves space by table and index in data/storage.tsv
# for it.
# The daily jobs (eval, your-example, builds, lean) queue on data/batch.lock, one at a
# time: together they and a renderer load held the disk at 90% pressure for hours (14
# Oct). Their timers start from the files each leaves, so a restart doesn't run them
# all again.
# A deploy (deploy/box.sh web start) sends SIGUSR1 rather than restarting, unless this
# script, its unit or the contact changed (data/web-loop.sum): the loop then builds and
# uploads the site at once with the new binary, keeping its curves, eval and builds
# timers. A restart reruns all of those, minutes on the box.
# Upload: the new build is copied into data/site by checksum without times, so only
# files whose content changed get a new mtime, and the upload's quick check sends just
# those. --delete removes what the build no longer writes; nginx then hands those paths
# to meiolol-render.
set -u
contact=$1
cd "$(dirname "$0")/.." || exit 1
sha256sum bin/web-loop.sh "$HOME/.config/systemd/user/meiolol-web.service" contact \
    > data/web-loop.sum
force=0
trap 'force=1' USR1

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

# Bytes and cells of every table and index (dbstat, aggregate: seconds per database),
# read-only and idle priority so the crawler never waits on it
storage_scan() {
    local db
    printf 'db\tname\tkind\tbytes\tcells\n' > data/storage.tsv.new
    for db in meiolol raw timeline; do
        nice -n 19 ionice -c 3 sqlite3 -readonly -cmd '.timeout 5000' -separator $'\t' \
            "data/$db.db" "SELECT '$db', s.name, coalesce(m.type, 'table'), s.pgsize, s.ncell
                FROM dbstat('main', 1) s LEFT JOIN sqlite_master m ON m.name = s.name
                ORDER BY 4 DESC" >> data/storage.tsv.new 2> data/storage.log || return 1
    done
    mv data/storage.tsv.new data/storage.tsv
}

last_patch='' last_games=0 last_upload=0
patch='' curves_patch='' last_curves=0 fresh_curves=0 last_eval=0 last_example=0
last_builds=0 builds_patch='' builds_pid='' storage_pid='' last_lean=0 lean_pid=''
mtime() { stat -c %Y "$1" 2> /dev/null || echo 0; }
# eval.log is truncated as a run starts, the other logs written as each runs
last_eval=$(mtime data/eval.log) last_example=$(mtime data/your-example.log)
last_builds=$(mtime data/builds.log) last_lean=$(mtime data/lean.log)
# The patch otherwise comes from the round's site build, after curves: without it a
# restart's first curves pass reads every patch (~50 min) and leaves curves-<patch>.bin
# alone, so start from the newest of those
patch=$(ls -t data/export/curves-*.bin 2> /dev/null | head -n 1 | sed -E 's#.*/curves-(.*)\.bin$#\1#')
# A restart (deploy, reboot) skips the first curves pass while the site's four curves
# files are under an hour old and in this binary's format: rebuilding them on a busy box
# took 35-50 min, with patch matchup pages 404 meanwhile (14 Oct). A format bump fails
# the check, so it still rebuilds first (u32 version after the 8-byte magic)
format=$(bin/meiolol curves --format-version 2> /dev/null)
[[ -n "$patch" && -s data/export/builds-$patch.json ]] && builds_patch=$patch
if [[ -n "$patch" && -n "$format" ]]; then
    fresh=1 oldest=$(date +%s)
    for f in data/export/{,all-}recent-curves.bin data/export/{,all-}curves-"$patch".bin; do
        if [[ -s $f ]] && (( $(date +%s) - $(stat -c %Y "$f") < 3600 )) \
            && [[ $(od -An -t u4 -j 8 -N 4 "$f" | tr -d ' ') == "$format" ]]; then
            (( $(stat -c %Y "$f") < oldest )) && oldest=$(stat -c %Y "$f")
        else
            fresh=0
        fi
    done
    if (( fresh )); then
        last_curves=$oldest curves_patch=$patch fresh_curves=1
        echo "$(date -u +%FT%TZ) curves under an hour old and format $format: first pass skipped"
    fi
fi
while true; do
    now=$(date +%s)
    # MEIOLOL_NO_EVAL (host.env): skipped on a box too small for it
    if [[ -z "${MEIOLOL_NO_EVAL:-}" ]] && (( now - last_eval >= 86400 )); then
        (flock -n 9 || exit 0
            flock 8
            nice -n 10 bin/meiolol eval --platform all \
                --history data/eval-history.tsv > data/eval-latest.md.new 2> data/eval.log \
                && mv data/eval-latest.md.new data/eval-latest.md) 9> data/eval.lock 8> data/batch.lock &
        last_eval=$now
    fi
    # Space by table and index, for the admin page; the file's age, not a timer, so a
    # restart does not rescan
    if [[ ! -f data/storage.tsv || -n $(find data/storage.tsv -mmin +1380) ]] \
        && { [[ -z "$storage_pid" ]] || ! kill -0 "$storage_pid" 2> /dev/null; }; then
        storage_scan &
        storage_pid=$!
    fi
    if (( now - last_example >= 86400 )); then
        (flock 8
        if nice -n 10 bin/meiolol your-example --out data/your-example.json.new \
            > data/your-example.log 2>&1; then
            mv data/your-example.json.new data/your-example.json
        else
            rm -f data/your-example.json data/your-example.json.new
        fi) 8> data/batch.lock &
        last_example=$now
    fi
    if [[ -n "$patch" ]] && { [[ -z "$builds_pid" ]] || ! kill -0 "$builds_pid" 2> /dev/null; } \
        && { (( now - last_builds >= 86400 )) || [[ "$patch" != "$builds_patch" ]]; }; then
        (flock 8
            nice -n 10 bin/meiolol builds --patch "$patch" \
            && nice -n 10 bin/meiolol builds --patch "$patch" --platform all) \
            > data/builds.log 2>&1 8> data/batch.lock &
        builds_pid=$! last_builds=$now builds_patch=$patch
    fi
    if (( now - last_lean >= 86400 )) \
        && { [[ -z "$lean_pid" ]] || ! kill -0 "$lean_pid" 2> /dev/null; }; then
        flock data/batch.lock nice -n 10 bin/meiolol lean > data/lean.log 2>&1 &
        lean_pid=$! last_lean=$now
    fi
    if (( now - last_curves >= 3600 )) || [[ "$patch" != "$curves_patch" ]]; then
        # Fails harmlessly (logged) until there are timelines
        if bin/meiolol curves --site ${patch:+--patch "$patch"} 2>&1; then fresh_curves=1; fi
        last_curves=$now curves_patch=$patch
        push_curves
    fi
    forced=$force force=0
    rm -rf data/site.new
    # The core build's and the views file's, so rendered pages match the uploaded ones
    site_args=(--contact "$contact" --origin https://meiolol.jomify.lol)
    [[ -s riot.txt ]] && site_args+=(--riot-txt "$(<riot.txt)")
    site_start=$SECONDS
    if out=$(bin/meiolol site "${site_args[@]}" --out data/site.new --static core 2>&1); then
        site_s=$(( SECONDS - site_start ))
        # First patch line, EUW: "data/site.new/patch/: patch 16.20, 1054 games, ..."
        read -r patch games < <(sed -nE 's/.*: patch ([^,]+), ([0-9]+) games.*/\1 \2/p' \
            <<< "$out")
        now=$(date +%s)
        if [[ "$patch" != "$last_patch" ]] || (( games * 5 >= last_games * 6 )) \
            || (( games > last_games && now - last_upload >= 3600 )) \
            || (( fresh_curves || forced )); then
            echo "$out"
            t=$SECONDS
            changed=$(rsync -rlpD --checksum --delete --stats data/site.new/ data/site/ \
                | sed -nE 's/^Number of regular files transferred: ([0-9,]+)/\1/p')
            copy_s=$(( SECONDS - t )) t=$SECONDS
            if stats=$(rsync -az --delete-delay --delay-updates --exclude /admin/ --stats \
                data/site/ meiolol-web:./); then
                sent=$(sed -nE 's/^Total bytes sent: ([0-9,]+)/\1/p' <<< "$stats")
                echo "$(date -u +%FT%TZ) upload: site ${site_s}s, copy ${copy_s}s" \
                    "(${changed:-?} files changed), send $(( SECONDS - t ))s (${sent:-?} bytes)"
                echo "$(date -u +%FT%TZ) uploaded"
                # For meiolol-render: every view, which it reads on the touch
                t=$SECONDS
                if bin/meiolol site --views data/views.bin "${site_args[@]}" \
                    > data/views.log 2>&1; then
                    echo "$(date -u +%FT%TZ) views file $(( SECONDS - t ))s" \
                        "($(stat -c %s data/views.bin) bytes)"
                else
                    echo "$(date -u +%FT%TZ) views file FAILED after $(( SECONDS - t ))s:" \
                        "$(tail -n 1 data/views.log)"
                fi
                touch data/render.reload
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
    # SIGUSR1 interrupts the wait; one during the round skips it
    if (( ! force )); then
        sleep 900 &
        wait $!
        kill $! 2> /dev/null
    fi
done
