#!/usr/bin/env bash
# Run the meiolol backend on the box: the Oracle Cloud ARM server (ssh alias
# meiolol-cloud; docs/hosting.md). The binary is cross-compiled here (static, musl) and
# copied over; data lives only on the box in ~/ml/meiolol/data. Every loop is a systemd
# user service (deploy/systemd/, lingering), so it starts on boot and restarts on a crash.
# MEIOLOL_HOST points it elsewhere (the old gpu-box); the binary matches the host's CPU.
set -euo pipefail

HOST=${MEIOLOL_HOST:-meiolol-cloud}
DIR=ml/meiolol
ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Builds a clean checkout of REV (default HEAD), never the working tree: other sessions
# keep uncommitted work there. The box logs each deploy in DEPLOYED
sync() {
    local rev tree target
    rev=$(git -C "$ROOT" rev-parse "${REV:-HEAD}")
    target=$(ssh "$HOST" uname -m)-linux-musl
    tree=$(mktemp -d)
    git -C "$ROOT" worktree add -q --detach "$tree" "$rev"
    # shellcheck disable=SC2064 # expand now: tree is local to sync
    trap "git -C '$ROOT' worktree remove --force '$tree'" EXIT
    (cd "$tree" && zig build -Dtarget="$target" -Doptimize=ReleaseSafe \
        --prefix zig-out/box --cache-dir "$ROOT/.zig-cache")
    ssh "$HOST" "mkdir -p $DIR/bin $DIR/data .config/systemd/user"
    scp -q "$tree/zig-out/box/bin/meiolol" "$HOST:$DIR/bin/meiolol.new"
    local scripts="web-loop.sh health.sh health-loop.sh backup-loop.sh" s
    for s in $scripts; do scp -q "$tree/deploy/$s" "$HOST:$DIR/bin/$s.new"; done
    scp -q "$tree"/deploy/systemd/*.service "$HOST:.config/systemd/user/"
    ssh "$HOST" "cd $DIR && mv bin/meiolol.new bin/meiolol \
        && for s in $scripts; do mv bin/\$s.new bin/\$s; done \
        && systemctl --user daemon-reload \
        && echo \"$rev $(date -u +%FT%TZ)\" >> DEPLOYED"
    echo "deployed $rev"
    if [[ -f "$ROOT/.env" ]]; then
        ssh "$HOST" "umask 077 && cat > $DIR/.env" < "$ROOT/.env"
    fi
}

case "${1:-}" in
    sync) sync ;;
    start)
        # Extra arguments go to `meiolol crawl` (kept in crawl.args on the box). Default
        # --reserve 20: the Your games service on the web server shares the key
        # (docs/your-games.md); it applies only while the service is calling. The
        # service stops on exit 3 (key rejected) rather than hammer Riot
        shift
        (( $# )) || set -- --reserve 20
        sync
        ssh "$HOST" "cd $DIR && echo '$*' > crawl.args \
            && systemctl --user enable -q meiolol-crawl && systemctl --user restart meiolol-crawl"
        echo "started meiolol-crawl on $HOST"
        ;;
    stop) ssh "$HOST" "systemctl --user disable -q --now meiolol-crawl" ;;
    status)
        ssh "$HOST" "systemctl --user is-active meiolol-crawl; cd $DIR && bin/meiolol status; \
            tail -n 3 data/crawl.log 2>/dev/null; du -sh data 2>/dev/null"
        ;;
    logs) ssh "$HOST" "tail -n ${2:-40} $DIR/data/crawl.log" ;;
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
        # The working tree (uncommitted edits included, other sessions' too) rendered on
        # the box with live data, EUW views only, into data/preview, then served at
        # http://localhost:8081: `meiolol-preview serve` runs detached on the box (unit
        # meiolol-preview) behind a background ssh tunnel, and this returns once the URL
        # answers. Never touches the live site. A new preview replaces the old one.
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
        target=$(ssh "$HOST" uname -m)-linux-musl
        (cd "$ROOT" && zig build -Dtarget="$target" -Doptimize=ReleaseSafe \
            --prefix zig-out/preview)
        stop_preview
        scp -q "$ROOT/zig-out/preview/bin/meiolol" "$HOST:$DIR/bin/meiolol-preview"
        ssh "$HOST" "cd $DIR && rm -rf data/preview \
            && time bin/meiolol-preview site --contact \"\$(cat contact)\" --euw-only \
                --out data/preview > data/preview.log 2>&1 || { tail data/preview.log; exit 1; }"
        ssh "$HOST" "systemd-run --user -q --collect --unit meiolol-preview \
            --working-directory=\$HOME/$DIR \$HOME/$DIR/bin/meiolol-preview serve \
            --out data/preview --port 8081"
        ssh -fN -o ExitOnForwardFailure=yes -L $tunnel
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
        # Site build and upload to the jomove server (deploy/web-loop.sh), and the
        # renderer for the pages the static build leaves out (meiolol-render, restarted
        # with each new binary: thin pages not in nginx's cache fail while it loads)
        case "${2:-}" in
            start)
                # The contact email is remembered on the box. A running loop whose
                # script, unit and contact are unchanged (data/web-loop.sum) gets SIGUSR1:
                # build and upload now with the new binary. Anything else restarts it
                contact=${3:-$(ssh "$HOST" "cat $DIR/contact 2>/dev/null" || true)}
                [[ -n "$contact" ]] || { echo "usage: deploy/box.sh web start <contact email>"; exit 2; }
                sync
                ssh "$HOST" "cd $DIR && { [ \"\$(cat contact 2>/dev/null)\" = '$contact' ] \
                        || echo '$contact' > contact; } \
                    && systemctl --user enable -q meiolol-web \
                    && if systemctl --user -q is-active meiolol-web \
                        && sha256sum --status -c data/web-loop.sum 2> /dev/null; then \
                        systemctl --user kill -s USR1 --kill-whom=main meiolol-web \
                        && echo 'signalled meiolol-web on $HOST'; \
                    else systemctl --user restart meiolol-web \
                        && echo 'restarted meiolol-web on $HOST'; fi \
                    && systemctl --user enable -q meiolol-render \
                    && systemctl --user restart meiolol-render \
                    && echo 'restarted meiolol-render on $HOST'"
                ;;
            stop) ssh "$HOST" "systemctl --user disable -q --now meiolol-web meiolol-render" ;;
            status)
                ssh "$HOST" "systemctl --user is-active meiolol-web meiolol-render; \
                    tail -n 3 $DIR/data/web.log; tail -n 2 $DIR/data/render.log"
                ;;
            *) echo "usage: deploy/box.sh web start [contact]|stop|status"; exit 2 ;;
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
    *) echo "usage: deploy/box.sh sync|start|stop|status|logs [n]|run <meiolol args>|snapshot|preview [static|stop]|site <contact>|web start [contact]|stop|status|backup|health start|stop|status|health check|watch install|uninstall"
       exit 2 ;;
esac
