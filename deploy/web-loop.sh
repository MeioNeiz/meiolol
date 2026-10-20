#!/usr/bin/env bash
# Runs on the box (deploy/box.sh web start): hourly rounds. Each reads EUW's newest patch
# and its game count (`meiolol site --patch-games`, a count query: under a second), then
# builds the static core and uploads it to the jomify server when the patch changed, a
# deploy asked, curves are fresh, or there are new games and `interval` passed: 6 h, or
# 1 h for a patch's first day (data/patch-<patch>.seen). Only then: until 18 Oct every
# round built it (17-265 s, mostly waiting on the disk) to read those two numbers, and a
# build changes only the home page (index.html), which the upload ships. Heavy work runs
# one job at a time, the loop's first
# (curves, views file), then at most one daily job per round, which the loop waits for:
# on 14-15 Oct several at once held the disk at its 70 MB/s cap and a curves pass took
# 45-60 min every hour (research/questions/box-io-priority.md). The build is
# `--static core`: the home
# page, robots.txt, riot.txt, the root sitemap and the front-end files (~30 files, two
# views loaded); meiolol-render serves every other page and file. After each upload,
# `meiolol site --views` loads every view from the database into data/views.bin and
# touches data/render.reload: the renderer reads that file in seconds, so the
# database work happens once, here (docs/hosting.md "Rendering on request"). The
# meiolol-web ssh alias is user meiolol with a key limited to rsync into /var/www/meiolol
# (rrsync); nginx there serves meio.lol. Riot's verification string, if any,
# lives in riot.txt beside bin/.
# Lane curves are rebuilt every `interval` and when the patch changes, one file per site view (EUW
# and every region, by last 30 days and current patch; the EUW patch file is also the
# Your games service's), all four in one pass over the timelines (`meiolol curves
# --site`); fresh site curves force an upload. The upload rules count EUW
# games on the current patch only.
# Daily, `meiolol eval` (docs/model.md) appends a line to data/eval-history.tsv (model
# accuracy vs data volume) and leaves its report in data/eval-latest.md. Read-only on the
# DB. One at a time with the admin page's Run eval (src/admin_api.zig): both flock
# data/eval.lock. Builds (`meiolol builds`, EUW and every region, current patch) the same
# way: daily and on a new patch; the next site build picks the files up.
# Daily, `meiolol lean` (every region, last 30 days; docs/model.md "Early and late
# champions") the same way: data/lean.tsv, the champion pages' early or late line.
# Daily, the admin Draft tester's models refit on every played game into data/tester/:
# `meiolol draft-model` (the shipped draft model, seconds after its scan) and `meiolol
# lane-model` (team2's lane outcomes, every timeline read once; 0.9 GB, ~2 min of CPU on
# the Mac for 800k games), each file with a .gz copy, written beside it and swapped in
# whole. Each round copies it into the admin upload at admin/models/, where the tester
# reads it before the lab's pick (admin-draft.js modelFile; docs/model.md "Draft model
# file").
# Daily, `meiolol your-example` (read-only, background) leaves an anonymised player's
# games per role in data/your-example.json, which meiolol-render serves at the same path
# from its next load, for your.html's and the home page's example. A failed run removes
# the file, so a stale example (perhaps a player forgotten since) never ships; the pages
# then offer none until the next success.
# Every round, the private admin page (`meiolol admin`) goes to admin/ on the server,
# behind basic auth there; the site's rsync leaves that directory alone. data/desktop
# (the Windows app's files and zip, desktop_files) goes with it to admin/desktop/. Daily, a dbstat
# scan (system sqlite3, read-only) leaves space by table and index in data/storage.tsv
# for it.
# The daily jobs' timers start from the files each leaves, and curves' from their files,
# so a restart doesn't run them all again. Batch work runs under ionice -c 3, which the
# disk honours only under mq-deadline or bfq (not `none`).
# A deploy (deploy/box.sh web start) sends SIGUSR1 rather than restarting, unless this
# script, its unit or the contact changed (data/web-loop.sum). Either way the next round
# (at once) builds, uploads and writes the views file with the new binary before any
# curves pass; a daily job already running carries on beside it. That write keeps the
# parts of the old file the new binary would make the same way (`--reuse`: same types
# and sources, src/site/root.zig partKeys) and loads only the rest, so a deploy that
# changed one part waits for that part alone; the next upload's write refreshes every
# part (data/views.full: the last such write). A views write running when a deploy
# changes the format finishes first: its parts the deploy left alone keep their keys, so
# the deploy's --reuse write takes them from it. Stopping it (until 17 Oct) threw that
# work away: two deploys that day cost a 10 and a 72 min write, and the swap waited 1 h 43
# `deploy/box.sh web rebuild` (data/views.full-request, then SIGUSR1) makes the next
# round a forced one without --reuse: every part fresh, Daily Draft and Learn included.
# A forced round's steps (site build, upload, views file, reload) go to data/deploys.tsv
# for the admin page's Deploys tab, under the commit deployed when the round began.
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

# The newest two patches' curves files go to the Your games service on the web server
# (not the public site; docs/your-games.md); by version, as the previous patch's is
# written again after the current one's (prev_patch). meiolol-exchange: rrsync into its
# exchange dir; a new file restarts the service there
push_curves() {
    local files
    files=$(printf '%s\n' data/export/curves-*.bin | grep -v '\*' | sort -V | tail -n 2)
    [[ -n "$files" ]] || return 0
    rm -rf data/curves-push && mkdir -p data/curves-push
    # Hard links, not a copy (226 MB a pass): curves replaces its files by rename, so a
    # link keeps the version pushed
    # shellcheck disable=SC2086
    ln $files data/curves-push/
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

# The Windows app, admin/desktop/ (behind the login until the public release, plan J7,
# J19): the deployed exe (box.sh sync), the renderer's data/stats.bin (EUW, current
# patch: what meio.lol serves) and recent-curves.bin, each with a .gz for nginx's
# gzip_static, and update.json listing them (name, sha256, bytes) for the app's own
# update check (src/desktop/update.zig), which nginx lets in with the key in
# desktop.token (docs/hosting.md). The zip people download is the exe and that key as
# update.key: the app fetches its data on first start and keeps it and itself current.
# All made again when an input changed, the curves' .gz only when they did
desktop_files() {
    local d=data/desktop.new inputs
    [[ -f bin/meiolol-desktop.exe && -f data/export/recent-curves.bin && -n "$patch" ]] \
        || return 0
    [[ -s desktop.token ]] || (umask 077 && openssl rand -hex 32 > desktop.token)
    rm -rf "$d" && mkdir -p "$d/meiolol"
    if ! curl -sf --max-time 120 -o "$d/stats.bin" \
        "http://$(hostname -I | cut -d' ' -f1):8091/data/stats.bin"; then
        echo "$(date -u +%FT%TZ) desktop files: no stats.bin from the renderer, old ones kept"
        rm -rf "$d"
        return 1
    fi
    # The curves by size and time, not content: 80 MB to read every round
    inputs=$(sha256sum "$d/stats.bin" bin/meiolol-desktop.exe desktop.token | cut -d' ' -f1 \
        && stat -c '%s %Y' data/export/recent-curves.bin && echo "$patch")
    if [[ -f data/desktop/update.json \
        && "$inputs" == "$(cat data/desktop.inputs 2> /dev/null)" ]]; then
        rm -rf "$d"
        return 0
    fi
    cp -p bin/meiolol-desktop.exe "$d/"
    ln data/export/recent-curves.bin "$d/"
    if [[ data/desktop/recent-curves.bin -ef data/export/recent-curves.bin \
        && data/desktop/recent-curves.bin.gz -nt data/export/recent-curves.bin ]]; then
        ln data/desktop/recent-curves.bin.gz "$d/"
    fi
    cp bin/meiolol-desktop.exe "$d/meiolol/"
    cp desktop.token "$d/meiolol/update.key"
    if ! batch python3 - "$d" "$patch" <<'EOF'
import datetime, gzip, hashlib, json, os, shutil, sys, zipfile
d, patch = sys.argv[1:]
files = []
for name in ("stats.bin", "recent-curves.bin", "meiolol-desktop.exe"):
    path = os.path.join(d, name)
    if not os.path.exists(path + ".gz"):
        with open(path, "rb") as src, gzip.open(path + ".gz", "wb", compresslevel=6) as dst:
            shutil.copyfileobj(src, dst, 1 << 20)
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    files.append({"name": name, "sha256": h.hexdigest(), "bytes": os.path.getsize(path)})
zip_path = os.path.join(d, "meiolol-desktop.zip")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for f in sorted(os.listdir(os.path.join(d, "meiolol"))):
        z.write(os.path.join(d, "meiolol", f), "meiolol/" + f)
built = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
with open(os.path.join(d, "update.json"), "w") as f:
    json.dump({"patch": patch, "built": built, "files": files}, f)
with open(os.path.join(d, "info.json"), "w") as f:
    json.dump({"patch": patch, "built": built, "bytes": os.path.getsize(zip_path)}, f)
EOF
    then
        echo "$(date -u +%FT%TZ) desktop files FAILED, old ones kept"
        rm -rf "$d"
        return 1
    fi
    rm -rf "$d/meiolol" data/desktop.old
    [[ -d data/desktop ]] && mv data/desktop data/desktop.old
    mv "$d" data/desktop && rm -rf data/desktop.old
    echo "$inputs" > data/desktop.inputs
    echo "$(date -u +%FT%TZ) desktop files: zip $(stat -c %s data/desktop/meiolol-desktop.zip)" \
        "bytes, patch $patch"
}

last_patch='' last_games=0
patch='' curves_patch='' last_curves=0 fresh_curves=0
builds_patch='' daily_pid=''
# The patch before the current one once it changes: its curves again, complete, for the
# site's patch day (patch.html), one daily job
prev_patch='' prev_curves_patch=''
# A start (deploy, reboot) uploads and writes the views file in its first round
force=1
mtime() { stat -c %Y "$1" 2> /dev/null || echo 0; }
# eval.log is truncated as a run starts, the other logs written as each runs
last_eval=$(mtime data/eval.log) last_example=$(mtime data/your-example.log)
last_builds=$(mtime data/builds.log) last_lean=$(mtime data/lean.log)
last_tester=$(mtime data/tester.log)
last_upload=$(mtime data/views.full)
# 1 h for the first day of a patch, else 6 h
interval_for() {
    [[ -n "$1" ]] || { echo 3600; return; }
    [[ -e data/patch-$1.seen ]] || touch "data/patch-$1.seen"
    if (( $(date +%s) - $(mtime "data/patch-$1.seen") < 86400 )); then echo 3600; else echo 21600; fi
}
# The rounds read the patch from the database, but the check below needs it first:
# without it a restart's first round redoes the curves (35-50 min) though they are
# current, so start from the newest of those files (by version: prev_patch's is
# written later)
patch=$(printf '%s\n' data/export/curves-*.bin | grep -v '\*' | sort -V | tail -n 1 \
    | sed -E 's#.*/curves-(.*)\.bin$#\1#')
# A restart (deploy, reboot) keeps the curves timer while the site's four curves files
# are in this binary's format: rebuilding them on a busy box took 35-50 min, with patch
# matchup pages 404 meanwhile (14 Oct). A format bump fails the check, so it still
# rebuilds first (u32 version after the 8-byte magic)
format=$(bin/meiolol curves --format-version 2> /dev/null)
[[ -n "$patch" && -s data/export/builds-$patch.json ]] && builds_patch=$patch
if [[ -n "$patch" && -n "$format" ]]; then
    fresh=1 oldest=$(date +%s)
    for f in data/export/{,all-}recent-curves.bin data/export/{,all-}curves-"$patch".bin; do
        if [[ -s $f ]] && [[ $(od -An -t u4 -j 8 -N 4 "$f" | tr -d ' ') == "$format" ]]; then
            (( $(stat -c %Y "$f") < oldest )) && oldest=$(stat -c %Y "$f")
        else
            fresh=0
        fi
    done
    if (( fresh )); then
        last_curves=$oldest curves_patch=$patch
        echo "$(date -u +%FT%TZ) curves in format $format from $(date -u -d "@$oldest" +%FT%TZ): kept"
    fi
fi
batch() { nice -n 10 ionice -c 3 "$@"; }
. bin/box-lib.sh
# A forced round's deploy event (round_sha set): STEP STATUS [DETAIL]
round_event() {
    [[ -n "$round_sha" ]] || return 0
    deploy_event "$round_sha" "$@"
}
# The views write's parts: each view's load line marks a part it took from the old file
# "... kept" (src/site/root.zig loadParts); a part never kept was loaded again
views_parts() {
    local p kept='' loaded=''
    for p in "stats and champions" filters people "daily and learn"; do
        if grep -q "$p kept" data/views.log; then kept+=${kept:+, }$p; else loaded+=${loaded:+, }$p; fi
    done
    echo "loaded again: ${loaded:-none}; kept: ${kept:-none}"
}
round_sha=''
# `meiolol site --views data/views.bin` with these flags, in the background so a
# deploy's signal (force=1) lands during the wait; the write always finishes, and the
# deploy's round follows at once. Never two at a time, so the older format can't land
# after the newer
views_write() {
    local format pid status noted=0
    format=$(bin/meiolol site --views-format)
    # Not through batch: a function run with & is a subshell, so $! would be that, not the
    # write; nice and ionice exec, so $! is the write itself
    nice -n 10 ionice -c 3 bin/meiolol site --views data/views.bin "$@" > data/views.log 2>&1 &
    pid=$!
    while true; do
        wait "$pid"
        status=$?
        kill -0 "$pid" 2> /dev/null || return "$status"
        if (( ! noted )) && [[ $(bin/meiolol site --views-format 2> /dev/null) != "$format" ]]; then
            noted=1
            echo "$(date -u +%FT%TZ) views file: a deploy changed its format; finishing" \
                "this write first, the deploy's reuses its unchanged parts"
        fi
    done
}
last_storage=$(mtime data/storage.tsv)
# The first due daily job, in the background (daily_pid); 1 when none is due. Builds
# first on a new patch: the site's build pages wait on them
run_daily() {
    local now=$1
    # One left running by a deploy's round
    [[ -n "$daily_pid" ]] && kill -0 "$daily_pid" 2> /dev/null && return 1
    if [[ -n "$patch" ]] && { [[ "$patch" != "$builds_patch" ]] || (( now - last_builds >= 86400 )); }; then
        last_builds=$now builds_patch=$patch
        # EUW's and every region's files from one read of the timelines (two passes until
        # 18 Oct, the second 15 min)
        batch bin/meiolol builds --patch "$patch" --site > data/builds.log 2>&1 &
    elif [[ -n "$prev_patch" && "$prev_patch" != "$prev_curves_patch" ]]; then
        prev_curves_patch=$prev_patch
        (batch bin/meiolol curves --patch "$prev_patch" \
            && batch bin/meiolol curves --patch "$prev_patch" --platform all) > data/prev-curves.log 2>&1 &
    # MEIOLOL_NO_EVAL (host.env): skipped on a box too small for it
    elif [[ -z "${MEIOLOL_NO_EVAL:-}" ]] && (( now - last_eval >= 86400 )); then
        last_eval=$now
        (flock -n 9 || exit 0
            batch bin/meiolol eval --platform all \
                --history data/eval-history.tsv > data/eval-latest.md.new 2> data/eval.log \
                && mv data/eval-latest.md.new data/eval-latest.md) 9> data/eval.lock &
    elif (( now - last_example >= 86400 )); then
        last_example=$now
        (if batch bin/meiolol your-example --out data/your-example.json.new \
            > data/your-example.log 2>&1; then
            mv data/your-example.json.new data/your-example.json
        else
            rm -f data/your-example.json data/your-example.json.new
        fi) &
    elif (( now - last_lean >= 86400 )); then
        last_lean=$now
        batch bin/meiolol lean > data/lean.log 2>&1 &
    elif (( now - last_tester >= 86400 )); then
        last_tester=$now
        (rm -rf data/tester.new
        if batch bin/meiolol draft-model --out data/tester.new > data/tester.log 2>&1 \
            && batch bin/meiolol lane-model --out data/tester.new >> data/tester.log 2>&1 \
            && batch gzip -kf data/tester.new/*.json; then
            rm -rf data/tester.old
            [[ -d data/tester ]] && mv data/tester data/tester.old
            mv data/tester.new data/tester && rm -rf data/tester.old
        fi) &
    # Space by table and index, for the admin page: reads every page of every database
    elif (( now - last_storage >= 82800 )); then
        last_storage=$now
        storage_scan &
    else
        return 1
    fi
    daily_pid=$!
}

while true; do
    now=$(date +%s)
    forced=$force force=0
    # deploy/box.sh web rebuild: a forced round that writes every views part fresh
    full=0
    if (( forced )) && [[ -e data/views.full-request ]]; then
        full=1
        rm -f data/views.full-request
    fi
    round_sha=''
    if (( forced )); then
        round_sha=$(deployed_sha)
        round_event round start "site build, upload and views file with the new binary$( (( full )) && echo ', every part fresh (web rebuild)')"
    fi
    # Fails (logged) until there are games; the patch then stays as it was
    if peek=$(bin/meiolol site --patch-games 2>&1) && [[ $peek =~ ^([^ ]+)\ ([0-9]+)$ ]]; then
        patch=${BASH_REMATCH[1]} games=${BASH_REMATCH[2]}
    else
        echo "$(date -u +%FT%TZ) patch and games: $peek"
        games=0
    fi
    interval=$(interval_for "$patch")
    # Digests of the timelines stored since the last round, for this round's curves and
    # daily jobs (a game without one is read in full, same output)
    batch bin/meiolol digest 2>&1 || true
    # A deploy's or start's round leaves a due pass to the next round, so the views file
    # comes first; a new patch or curves format can't wait
    if [[ "$patch" != "$curves_patch" ]] || { (( ! forced )) && (( now - last_curves >= interval )); }; then
        # Fails harmlessly (logged) until there are timelines
        if batch bin/meiolol curves --site ${patch:+--patch "$patch"} 2>&1; then fresh_curves=1; fi
        [[ -n "$curves_patch" && -n "$patch" && "$patch" != "$curves_patch" ]] && prev_patch=$curves_patch
        last_curves=$now curves_patch=$patch
        push_curves
    fi
    # The core build's and the views file's, so rendered pages match the uploaded ones
    site_args=(--contact "$contact" --origin https://meio.lol)
    [[ -s riot.txt ]] && site_args+=(--riot-txt "$(<riot.txt)")
    now=$(date +%s)
    if [[ -n "$patch" ]] && { [[ "$patch" != "$last_patch" ]] || (( fresh_curves || forced )) \
        || (( games > last_games && now - last_upload >= interval )); }; then
        rm -rf data/site.new
        site_start=$SECONDS
        if ! out=$(bin/meiolol site "${site_args[@]}" --out data/site.new --static core 2>&1); then
            echo "$out"
            round_event site failed "$(tail -n 1 <<< "$out")"
        else
            site_s=$(( SECONDS - site_start ))
            round_event site ok "core build ${site_s}s"
            echo "$out"
            t=$SECONDS
            changed=$(rsync -rlpD --checksum --delete --stats data/site.new/ data/site/ \
                | sed -nE 's/^Number of regular files transferred: ([0-9,]+)/\1/p')
            copy_s=$(( SECONDS - t )) t=$SECONDS
            if ! stats=$(rsync -az --delete-delay --delay-updates --exclude /admin/ --stats \
                data/site/ meiolol-web:./); then
                round_event upload failed "rsync to the web server failed"
            else
                sent=$(sed -nE 's/^Total bytes sent: ([0-9,]+)/\1/p' <<< "$stats")
                echo "$(date -u +%FT%TZ) upload: site ${site_s}s, copy ${copy_s}s" \
                    "(${changed:-?} files changed), send $(( SECONDS - t ))s (${sent:-?} bytes)"
                echo "$(date -u +%FT%TZ) uploaded"
                round_event upload ok "${changed:-?} files changed, sent ${sent:-?} bytes"
                # For meiolol-render: every view, which it reads on the touch. A deploy's
                # or start's round keeps the old file's current parts and leaves the
                # refresh of the rest to the next upload (last_upload unchanged)
                t=$SECONDS
                reuse=()
                (( forced && ! full )) && reuse=(--reuse)
                round_event views start "every view into data/views.bin${reuse:+, current parts kept}"
                if views_write "${reuse[@]}" "${site_args[@]}"; then
                    echo "$(date -u +%FT%TZ) views file $(( SECONDS - t ))s" \
                        "($(stat -c %s data/views.bin) bytes${reuse:+, current parts kept})"
                    round_event views ok "$(( SECONDS - t ))s, $(views_parts)"
                    (( forced && ! full )) || { touch data/views.full; last_upload=$now; }
                    touch data/render.reload
                    round_event reload ok "renderer told to read the new views file"
                else
                    echo "$(date -u +%FT%TZ) views file FAILED after $(( SECONDS - t ))s:" \
                        "$(tail -n 1 data/views.log)"
                    round_event views failed "after $(( SECONDS - t ))s: $(tail -n 1 data/views.log)"
                    touch data/render.reload
                    round_event reload ok "renderer told to reload (from the database)"
                fi
                last_patch=$patch last_games=$games fresh_curves=0
            fi
        fi
    fi
    desktop_files || true
    if nice -n 10 bin/meiolol admin --out data/admin.new \
        --disk "$(df -B1 --output=size,used,avail data | tail -n 1)" \
        --health "$(bin/health.sh)" 2>&1; then
        # Times kept, so the upload sends the tester's files only when the daily job changed them
        [[ -d data/tester ]] && cp -pR data/tester data/admin.new/models
        # Linked, not copied (~50 MB)
        [[ -d data/desktop ]] && cp -al data/desktop data/admin.new/desktop
        rm -rf data/admin && mv data/admin.new data/admin
        rsync -a --delete data/admin/ meiolol-web:admin/ || echo "$(date -u +%FT%TZ) admin upload FAILED"
    fi
    run_daily "$(date +%s)" || true
    # Hourly; SIGUSR1 interrupts the wait, and one during the round skips it. A daily job
    # longer than the hour holds the next round back rather than run beside it
    if (( ! force )); then
        sleep 3600 &
        wait $!
        kill $! 2> /dev/null
    fi
    if (( ! force )) && [[ -n "$daily_pid" ]] && kill -0 "$daily_pid" 2> /dev/null; then
        wait "$daily_pid"
    fi
done
