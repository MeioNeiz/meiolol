#!/usr/bin/env bash
# Run the meiolol backend on the box: the Oracle Cloud ARM server (ssh alias
# meiolol-cloud; docs/hosting.md). The binary is cross-compiled here (static, musl) and
# copied over; data lives only on the box in ~/ml/meiolol/data. Every loop is a systemd
# user service (deploy/systemd/, lingering), so it starts on boot and restarts on a crash.
# MEIOLOL_HOST points it elsewhere (the old gpu-box); the binary matches the host's CPU.
set -euo pipefail

HOST=${MEIOLOL_HOST:-meiolol-cloud}
DIR=ml/meiolol
# MEIOLOL_ROOT: the repo when this runs from on-push.sh's snapshot of deploy/
ROOT=${MEIOLOL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
HERE=$(cd "$(dirname "$0")" && pwd)
# 15 Oct: a hung connect held the deploy lock for 3 h 25 min. Keepalives end a dead link
# within a minute; sshd answers them while a long remote command runs
ssh_opts=(-o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4)
ssh() { command ssh "${ssh_opts[@]}" "$@"; }
scp() { command scp "${ssh_opts[@]}" "$@"; }
export RSYNC_RSH="ssh ${ssh_opts[*]}"
# sync sets it when the box already had this build's binary, scripts and units
unchanged=0

# Builds a clean checkout of REV (default HEAD) in deploy/build-tree.sh's tree, never the
# working tree: other sessions keep uncommitted work there. The binary and scripts are
# staged so the tree is free again before the copy. The box logs each deploy in DEPLOYED.
# Nothing is copied when the box has every file already: a change to src/lab code the
# backend doesn't use, or to Mac-side scripts (16 of 137 deploys to 17 Oct)
sync() {
    local rev tree target
    rev=$(git -C "$ROOT" rev-parse "${REV:-HEAD}")
    target=$(ssh "$HOST" uname -m)-linux-musl
    tree=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now: tree is local to sync
    trap "rm -rf '$tree'" EXIT
    "$HERE/build-tree.sh" box "$rev" sh -c 'zig build backend -Dtarget="$1" \
        -Doptimize=ReleaseSafe --prefix zig-out/box --cache-dir "$2/.zig-cache" \
        && mkdir "$3/zig-out" && cp -R zig-out/box "$3/zig-out/" && cp -R deploy "$3/"' \
        _ "$target" "$ROOT" "$tree"
    # check-deploy.sh (zig build ci) reads both lists: each committed, every unit that runs
    # in ~/ml/meiolol listed, every script a unit or listed script runs listed
    local scripts="web-loop.sh health.sh health-loop.sh backup-loop.sh backup-serve.sh render-swap.sh archive-serve.sh cache-version.sh cache-warm.sh box-lib.sh" s
    local units="meiolol-crawl.service meiolol-web.service meiolol-render@.service meiolol-health.service meiolol-backup.service meiolol-cache-version.service meiolol-cache-version.path meiolol-cache-warm.service" u
    local files=("$tree/zig-out/box/bin/meiolol") on_box=("$DIR/bin/meiolol") want=() i
    local have stamp
    for s in $scripts; do files+=("$tree/deploy/$s"); on_box+=("$DIR/bin/$s"); done
    for u in $units; do files+=("$tree/deploy/systemd/$u"); on_box+=(".config/systemd/user/$u"); done
    for i in "${!files[@]}"; do
        want+=("$(shasum -a 256 < "${files[i]}" | cut -d' ' -f1)  ${on_box[i]}")
    done
    stamp="$rev $(date -u +%FT%TZ)"
    have=$(ssh "$HOST" "sha256sum ${on_box[*]} 2> /dev/null || true")
    if [[ "$have" == "$(printf '%s\n' "${want[@]}")" ]]; then
        ssh "$HOST" "echo '$stamp' >> $DIR/DEPLOYED"
        unchanged=1
        echo "deployed $rev: unchanged on the box (binary, scripts, units), nothing copied"
    else
        ssh "$HOST" "mkdir -p $DIR/bin/new $DIR/data .config/systemd/user"
        scp -q "${files[@]}" "$HOST:$DIR/bin/new/"
        ssh "$HOST" "cd $DIR && mv bin/new/meiolol bin/meiolol \
            && for s in $scripts; do mv bin/new/\$s bin/\$s; done \
            && mv bin/new/*.service bin/new/*.path \$HOME/.config/systemd/user/ \
            && systemctl --user daemon-reload \
            && echo '$stamp' >> DEPLOYED"
        echo "deployed $rev"
    fi
    if [[ -f "$ROOT/.env" ]]; then
        ssh "$HOST" "umask 077 && cat > $DIR/.env" < "$ROOT/.env"
    fi
}

# Draft model accuracy as data grows: the daily `meiolol eval` (web-loop.sh) scores held-out
# games and appends a line to data/eval-history.tsv. eval.log is truncated when a run
# starts and eval-latest.md replaced when it succeeds, so their mtimes time the last run
model() {
    local rows=$1 out state started finished
    out=$(ssh "$HOST" "cd $DIR/data && bash -s" <<'EOF'
if pgrep -f '^bin/meiolol eval' > /dev/null; then s=running; else s=idle; fi
echo "$s $(stat -c %Y eval.log 2>/dev/null || echo 0) $(stat -c %Y eval-latest.md 2>/dev/null || echo 0)"
cat eval-history.tsv 2>/dev/null
EOF
    )
    read -r state started finished <<< "$(head -n 1 <<< "$out")"
    local at='+%a %d %b %H:%M'
    echo "Draft model, daily eval on held-out games (docs/model.md), $(date +%H:%M:%S)"
    if [[ "$state" == running ]]; then
        echo "eval running for $(( ($(date +%s) - started) / 60 )) min, since $(date -r "$started" "$at")"
    elif (( finished >= started && started > 0 )); then
        echo "last eval $(date -r "$started" "$at") ($(( (finished - started) / 60 )) min)," \
            "next about $(date -r $((started + 86400)) "$at")"
    else
        echo "last eval, started $(date -r "$started" "$at"), failed: data/eval.log on the box"
    fi
    tail -n +2 <<< "$out" | awk -v rows="$rows" '
        BEGIN {
            FS = "\t"
            split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", bar, " ")
            split("base current eb joint", key, " ")
            split("base current shrunk joint", name, " ")
        }
        NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
        {
            n++
            date[n] = $col["date"]; games[n] = $col["games"]; tests[n] = $col["test"]
            coin[n] = $col["ll_coin"]
            for (k = 1; k <= 4; k++) {
                auc[n, k] = $col["auc_" key[k]]
                ll[n, k] = $col["ll_" key[k]]
            }
        }
        END {
            if (n == 0) { print "no eval history yet"; exit }
            from = n > 60 ? n - 59 : 1
            lo = 1; hi = 0
            for (i = from; i <= n; i++) for (k = 1; k <= 4; k++) {
                if (auc[i, k] < lo) lo = auc[i, k]
                if (auc[i, k] > hi) hi = auc[i, k]
            }
            printf "\nAUC over the last %d runs (%.3f to %.3f; 0.5 is a coin flip)\n", n - from + 1, lo, hi
            for (k = 1; k <= 4; k++) {
                line = ""
                for (i = from; i <= n; i++)
                    line = line bar[hi > lo ? 1 + int((auc[i, k] - lo) / (hi - lo) * 7.999) : 1]
                printf "%-8s %s  %.4f\n", name[k], line, auc[n, k]
            }
            printf "\n%-10s %8s %6s %8s %8s %8s %8s  %s\n", "date", "games", "test",
                "base", "current", "shrunk", "joint", "best log loss (vs coin)"
            for (i = n > rows ? n - rows + 1 : 1; i <= n; i++) {
                best = 1
                for (k = 2; k <= 4; k++) if (ll[i, k] < ll[i, best]) best = k
                printf "%-10s %8d %6d %8.4f %8.4f %8.4f %8.4f  %.5f %s (%+.4f)\n", date[i],
                    games[i], tests[i], auc[i, 1], auc[i, 2], auc[i, 3], auc[i, 4],
                    ll[i, best], name[best], ll[i, best] - coin[i]
            }
        }'
}

case "${1:-}" in
    sync) sync ;;
    start)
        # Extra arguments go to `meiolol crawl` (kept in crawl.args on the box); none keeps
        # the box's crawl.args, or on a new box --proxy on the private address: the Your
        # games service on the web server makes its Riot calls through the crawler
        # (docs/your-games.md). The crawler stops on exit 3 (key rejected) rather than
        # hammer Riot
        shift
        sync
        if (( $# )); then
            ssh "$HOST" "cd $DIR && echo '$*' > crawl.args"
        else
            ssh "$HOST" "cd $DIR && [ -s crawl.args ] || echo '--proxy 10.0.0.3:8092' > crawl.args"
        fi
        ssh "$HOST" "systemctl --user enable -q meiolol-crawl && systemctl --user restart meiolol-crawl"
        echo "started meiolol-crawl on $HOST"
        ;;
    restart)
        # The deployed binary with the box's crawl.args, no build: a deploy restarts the
        # crawler only when src/riot or src/store changed (on-push.sh)
        ssh "$HOST" "systemctl --user restart meiolol-crawl && systemctl --user is-active meiolol-crawl"
        ;;
    wait-deployed)
        # deploy/box.sh wait-deployed [REV] [--live] [--timeout S]: until REV (default
        # origin/main) is on the box (DEPLOYED), or with --live until a site round that
        # includes it has told the renderer to reload. A push the deploy skipped (no
        # change in src, deploy or build files) counts as there. Exit 0 there, 1 the
        # round's views write failed, 3 timeout (default 900 s; --live 5400 s)
        rev=origin/main live=0 timeout=''
        for a in "${@:2}"; do
            case $a in
                --live) live=1 ;;
                --timeout=*) timeout=${a#--timeout=} ;;
                --timeout) timeout=next ;;
                *) if [[ $timeout == next ]]; then timeout=$a; else rev=$a; fi ;;
            esac
        done
        [[ -n $timeout && $timeout != next ]] || timeout=$(( live ? 5400 : 900 ))
        sha=$(git -C "$ROOT" rev-parse "$rev^{commit}")
        end=$(( SECONDS + timeout ))
        while (( SECONDS < end )); do
            got=$(ssh "$HOST" "cd $DIR && tail -n 20 DEPLOYED; echo ---; \
                grep -P '\t(deploy\tskipped|reload\t)' data/deploys.tsv | tail -n 50" 2> /dev/null) \
                || { sleep 10; continue; }
            if grep -q "^$sha.*deploy.skipped" <<< "$(cut -f2- <<< "${got#*---}")"; then
                echo "${sha:0:7}: nothing to deploy (no change in src, deploy or build files)"
                exit 0
            fi
            if (( ! live )); then
                if grep -q "^$sha " <<< "${got%%---*}"; then echo "${sha:0:7} on $HOST"; exit 0; fi
            else
                while IFS=$'\t' read -r _ round step _ detail; do
                    [[ $step == reload ]] || continue
                    git -C "$ROOT" merge-base --is-ancestor "$sha" "$round" 2> /dev/null || continue
                    echo "${sha:0:7} live in round ${round:0:7}: $detail"
                    grep -q 'database' <<< "$detail" && exit 1
                    exit 0
                done <<< "${got#*---}"
            fi
            sleep 10
        done
        echo "${sha:0:7}: not there after ${timeout}s"
        exit 3
        ;;
    job)
        # Long work on the box that outlives the ssh session (17 Oct: two hand-run jobs died
        # with a dropped ssh): deploy/box.sh job run NAME 'CMD' runs CMD (bash, in
        # ml/meiolol) as user unit meiolol-job-NAME, output in data/job-NAME.log and its
        # exit status in data/job-NAME.rc; `job status NAME`; `job wait NAME [S]` until it
        # ends (default 3600 s), exit its status, 3 timeout
        name=${3:-}
        [[ $name =~ ^[a-z0-9-]+$ ]] || { echo "usage: deploy/box.sh job run NAME 'CMD'|status NAME|wait NAME [S]"; exit 2; }
        unit=meiolol-job-$name log=data/job-$name.log rc=data/job-$name.rc
        status_job="cd $DIR; if systemctl --user -q is-active $unit; then echo '$unit running'; \
            elif [ -f $rc ]; then echo \"$unit ended, exit \$(cat $rc)\"; else echo '$unit not run'; fi; \
            tail -n 5 $log 2> /dev/null"
        case "${2:-}" in
            run)
                [[ -n "${4:-}" ]] || { echo "usage: deploy/box.sh job run NAME 'CMD'"; exit 2; }
                # A subshell, so an exit in CMD still leaves its status
                body=$(printf '( %s\n) > %s 2>&1; echo $? > %s' "$4" "$log" "$rc")
                ssh "$HOST" "cd $DIR && if systemctl --user -q is-active $unit; then \
                    echo '$unit already running'; exit 1; fi; rm -f $rc \
                    && systemd-run --user -q --collect --unit $unit --working-directory=\$HOME/$DIR \
                        /bin/bash -c $(printf %q "$body") && echo 'started $unit ($log)'"
                ;;
            status) ssh "$HOST" "$status_job" ;;
            wait)
                limit=${4:-3600}
                ssh "$HOST" "for i in \$(seq $(( (limit + 4) / 5 ))); do \
                    systemctl --user -q is-active $unit || break; sleep 5; done; $status_job; \
                    cd; systemctl --user -q is-active $unit && exit 3; exit \$(cat $DIR/$rc 2> /dev/null || echo 1)"
                ;;
            *) echo "usage: deploy/box.sh job run NAME 'CMD'|status NAME|wait NAME [S]"; exit 2 ;;
        esac
        ;;
    stop) ssh "$HOST" "systemctl --user disable -q --now meiolol-crawl" ;;
    status)
        ssh "$HOST" "systemctl --user is-active meiolol-crawl; cd $DIR && bin/meiolol status; \
            tail -n 3 data/crawl.log 2>/dev/null; du -sh data 2>/dev/null"
        ;;
    logs) ssh "$HOST" "tail -n ${2:-40} $DIR/data/crawl.log" ;;
    model)
        # deploy/box.sh model [ROWS] [-f]: -f redraws every minute until ctrl-c
        rows=15 follow=0
        for a in "${@:2}"; do
            if [[ "$a" == -f ]]; then follow=1; else rows=$a; fi
        done
        if (( follow )); then
            while true; do
                view=$(model "$rows" 2>&1)
                clear
                echo "$view"
                sleep 60
            done
        fi
        model "$rows"
        ;;
    site)
        # Generate the website on the box (the data is there) and copy it to data/site
        [[ -n "${2:-}" ]] || { echo "usage: deploy/box.sh site <contact email> [meiolol site args]"; exit 2; }
        contact=$2; shift 2
        sync
        ssh "$HOST" "cd $DIR && rm -rf data/site && bin/meiolol site --contact '$contact' $*"
        mkdir -p "$ROOT/data"
        rsync -a --delete "$HOST:$DIR/data/site/" "$ROOT/data/site/"
        echo "site in $ROOT/data/site"
        ;;
    run) shift; ssh "$HOST" "cd $DIR && bin/meiolol $*" ;;
    snapshot)
        # The tables `meiolol site` reads, with the curves, builds and Daily Draft files,
        # copied to data/snap here for local site work (`meiolol site --data data/snap`).
        # PUUIDs become p1, p2, ... (consistent across tables, so pool and learning
        # still group by player); no raw or timeline docs, so Learn has no damage split
        # and no practice drafts
        ssh "$HOST" "cd $DIR/data && rm -rf snap && mkdir snap && cd snap \
            && sqlite3 -readonly ../meiolol.db '.schema --nosys' | sqlite3 meiolol.db \
            && sqlite3 -readonly ../raw.db '.schema --nosys' | sqlite3 raw.db \
            && sqlite3 -readonly ../timeline.db '.schema --nosys' | sqlite3 timeline.db \
            && nice sqlite3 meiolol.db" <<'SQL'
ATTACH 'file:../meiolol.db?mode=ro' AS live;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
BEGIN;
CREATE TEMP TABLE ids (puuid TEXT PRIMARY KEY, n INTEGER NOT NULL) WITHOUT ROWID;
INSERT INTO ids SELECT puuid, row_number() OVER () FROM (
    SELECT puuid FROM live.participants WHERE puuid IS NOT NULL
    UNION SELECT puuid FROM live.mastery);
INSERT INTO champions SELECT * FROM live.champions;
INSERT INTO matches SELECT * FROM live.matches;
INSERT INTO bans SELECT * FROM live.bans;
INSERT INTO drafts SELECT * FROM live.drafts;
INSERT INTO participants SELECT * FROM live.participants;
UPDATE participants SET puuid = (SELECT 'p' || n FROM ids WHERE ids.puuid = participants.puuid);
INSERT INTO mastery (puuid, platform, fetched_at, champions, data)
    SELECT 'p' || n, platform, fetched_at, champions, data FROM live.mastery JOIN ids USING (puuid);
INSERT INTO players (puuid, matches_checked_at, source)
    SELECT 'p' || n, matches_checked_at, source FROM live.players JOIN ids USING (puuid)
    WHERE matches_checked_at IS NOT NULL;
COMMIT;
SQL
        ssh "$HOST" "cd $DIR/data && mkdir -p snap/export && cp -p export/*curves*.bin \
            export/*builds*.json snap/export/ && cp -rp daily snap/"
        mkdir -p "$ROOT/data/snap"
        rsync -az --delete "$HOST:$DIR/data/snap/" "$ROOT/data/snap/"
        ssh "$HOST" "rm -rf $DIR/data/snap"
        du -sh "$ROOT/data/snap"
        ;;
    preview)
        # HEAD plus the working tree's edits under src/site (`preview src/site src/pool.zig`
        # names other paths) rendered on the box with live data, EUW views only, into
        # data/preview, then served at
        # http://localhost:8081: `meiolol-preview serve` runs detached on the box (unit
        # meiolol-preview) behind a background ssh tunnel, and this returns once the URL
        # answers. Never touches the live site. A new preview replaces the old one. Not
        # the whole working tree: other sessions' uncommitted work once migrated the live
        # DB from a preview.
        # `preview static`: copy src/site/static/ over the last preview, no build (css
        # and js edits; reload the page). `preview stop`: tunnel and server
        tunnel="8081:127.0.0.1:8081 $HOST"
        stop_preview() {
            pkill -f "ssh -fN -o ExitOnForwardFailure=yes -L $tunnel" || true
            ssh "$HOST" "systemctl --user stop meiolol-preview 2> /dev/null; true"
        }
        if [[ "${2:-}" == stop ]]; then
            stop_preview
            echo "preview stopped"
            exit 0
        fi
        if [[ "${2:-}" == static ]]; then
            # The .gz twins go: serve would send those first
            rsync -a --delete "$ROOT/src/site/static/" "$HOST:$DIR/data/preview.static/"
            ssh "$HOST" "cd $DIR/data && for s in preview.static/*.css preview.static/*.js; do \
                f=\${s#preview.static/}; find preview -name \"\$f.gz\" -delete; \
                find preview -name \"\$f\" -exec cp \"\$s\" {} \\;; done"
            echo "copied src/site/static into the preview"
            exit 0
        fi
        paths=("${@:2}")
        (( ${#paths[@]} )) || paths=(src/site)
        target=$(ssh "$HOST" uname -m)-linux-musl
        tree=$(mktemp -d)
        git -C "$ROOT" worktree add -q --detach "$tree" HEAD
        # shellcheck disable=SC2064 # expand now
        trap "git -C '$ROOT' worktree remove --force '$tree'" EXIT
        git -C "$ROOT" diff --binary HEAD -- "${paths[@]}" | git -C "$tree" apply --allow-empty
        git -C "$ROOT" ls-files -z --others --exclude-standard -- "${paths[@]}" \
            | (cd "$ROOT" && xargs -0 -I{} rsync -R {} "$tree/")
        (cd "$tree" && zig build backend -Dtarget="$target" -Doptimize=ReleaseSafe \
            --prefix zig-out/preview --cache-dir "$ROOT/.zig-cache")
        stop_preview
        scp -q "$tree/zig-out/preview/bin/meiolol" "$HOST:$DIR/bin/meiolol-preview"
        ssh "$HOST" "cd $DIR && rm -rf data/preview \
            && time bin/meiolol-preview site --contact \"\$(cat contact)\" --euw-only \
                --out data/preview > data/preview.log 2>&1 || { tail data/preview.log; exit 1; }"
        ssh "$HOST" "systemd-run --user -q --collect --unit meiolol-preview \
            --working-directory=\$HOME/$DIR \$HOME/$DIR/bin/meiolol-preview serve \
            --out data/preview --port 8081"
        # Without the ssh() options: stop_preview's pkill matches this command line
        command ssh -fN -o ExitOnForwardFailure=yes -L $tunnel
        for _ in $(seq 30); do
            if curl -sf -o /dev/null http://localhost:8081/; then
                echo "preview at http://localhost:8081 (deploy/box.sh preview stop)"
                exit 0
            fi
            sleep 1
        done
        echo "preview not answering after 30 s"
        ssh "$HOST" "journalctl --user -u meiolol-preview -n 10 --no-pager"
        exit 1
        ;;
    web)
        # Site build and upload to the jomify server (deploy/web-loop.sh), and the
        # renderer for the pages the static build leaves out (meiolol-render@a|b: each
        # new binary starts the idle one and stops the old once it serves, render-swap.sh)
        case "${2:-}" in
            start)
                # The contact email is remembered on the box. A running loop whose
                # script, unit and contact are unchanged (data/web-loop.sum) gets SIGUSR1:
                # build and upload now with the new binary. Anything else restarts it
                contact=${3:-$(ssh "$HOST" "cat $DIR/contact 2>/dev/null" || true)}
                [[ -n "$contact" ]] || { echo "usage: deploy/box.sh web start <contact email>"; exit 2; }
                sync
                if (( unchanged )) && [[ -z "${3:-}" ]] \
                    && ssh "$HOST" "systemctl --user -q is-active meiolol-web"; then
                    echo "meiolol-web keeps running on $HOST: nothing it runs changed"
                    exit 0
                fi
                ssh "$HOST" "cd $DIR && { [ \"\$(cat contact 2>/dev/null)\" = '$contact' ] \
                        || echo '$contact' > contact; } \
                    && systemctl --user enable -q meiolol-web \
                    && systemctl --user enable -q --now meiolol-cache-version.path \
                    && if systemctl --user -q is-active meiolol-web \
                        && sha256sum --status -c data/web-loop.sum 2> /dev/null; then \
                        systemctl --user kill -s USR1 --kill-whom=main meiolol-web \
                        && echo 'signalled meiolol-web on $HOST'; \
                    else systemctl --user restart meiolol-web \
                        && echo 'restarted meiolol-web on $HOST'; fi \
                    && if systemctl --user -q is-active meiolol-render-swap; then \
                        echo 'meiolol-render swap already running: it picks up the new binary'; \
                    else systemd-run --user -q --collect --unit meiolol-render-swap \
                        --working-directory=\$HOME/$DIR \$HOME/$DIR/bin/render-swap.sh \
                        && echo 'swapping meiolol-render on $HOST (data/render.log)'; fi"
                ;;
            rebuild)
                # The next round at once, writing every views part fresh (Daily Draft and
                # Learn included) rather than a deploy's --reuse, which keeps them: a
                # puzzle file changed by hand goes live this way (~20 min more)
                ssh "$HOST" "cd $DIR && touch data/views.full-request \
                    && systemctl --user kill -s USR1 --kill-whom=main meiolol-web"
                echo "meiolol-web: full round requested (data/web.log; deploy/box.sh wait-deployed --live)"
                ;;
            stop)
                ssh "$HOST" "systemctl --user disable -q --now meiolol-web meiolol-render@a \
                    meiolol-render@b meiolol-cache-version.path"
                ;;
            status)
                ssh "$HOST" "systemctl --user is-active meiolol-web meiolol-render@a \
                    meiolol-render@b; \
                    tail -n 3 $DIR/data/web.log; tail -n 2 $DIR/data/render.log"
                ;;
            *) echo "usage: deploy/box.sh web start [contact]|rebuild|stop|status"; exit 2 ;;
        esac
        ;;
    backup | health)
        # Daily backups (deploy/backup-loop.sh), health checks with ntfy pushes
        # (deploy/health-loop.sh). docs/data-safety.md
        name=meiolol-$1 log=data/$1.log
        case "${2:-}" in
            start)
                sync
                ssh "$HOST" "systemctl --user enable -q $name && systemctl --user restart $name"
                echo "started $name on $HOST"
                ;;
            stop) ssh "$HOST" "systemctl --user disable -q --now $name" ;;
            status)
                ssh "$HOST" "systemctl --user is-active $name; tail -n 3 $DIR/$log"
                ;;
            check) ssh "$HOST" "$DIR/bin/health.sh" && echo ok ;;
            *) echo "usage: deploy/box.sh backup|health start|stop|status, health check"; exit 2 ;;
        esac
        ;;
    watch)
        # Mac side: launchd runs deploy/mac-watch.sh every 30 min
        plist=net.jacob.meiolol-watch.plist
        case "${2:-}" in
            install)
                # The mirror's meiolol (backup --mirror), apart from zig-out, which other
                # sessions rebuild
                (cd "$ROOT" && zig build backend -Doptimize=ReleaseSafe --prefix "$HOME/.cache/meiolol-watch")
                launchctl bootout "gui/$(id -u)/${plist%.plist}" 2> /dev/null || true
                cp "$ROOT/deploy/$plist" ~/Library/LaunchAgents/
                launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/$plist
                echo "installed $plist"
                ;;
            uninstall)
                launchctl bootout "gui/$(id -u)/${plist%.plist}" || true
                rm -f ~/Library/LaunchAgents/$plist
                ;;
            *) echo "usage: deploy/box.sh watch install|uninstall"; exit 2 ;;
        esac
        ;;
    *) echo "usage: deploy/box.sh sync|start [crawl args]|restart|stop|status|wait-deployed [rev] [--live] [--timeout S]|job run|status|wait NAME|logs [n]|model [rows] [-f]|run <meiolol args>|snapshot|preview [static|stop]|site <contact>|web start [contact]|rebuild|stop|status|backup|health start|stop|status|health check|watch install|uninstall"
       exit 2 ;;
esac
