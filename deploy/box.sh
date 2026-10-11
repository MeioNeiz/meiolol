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
        --prefix zig-out/box)
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
        # (docs/your-games.md). The service stops on exit 3 (key rejected) rather than
        # hammer Riot
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
    web)
        # Site build and upload to the jomove server: deploy/web-loop.sh
        case "${2:-}" in
            start)
                # (Re)starts; the contact email is remembered on the box
                contact=${3:-$(ssh "$HOST" "cat $DIR/contact 2>/dev/null" || true)}
                [[ -n "$contact" ]] || { echo "usage: deploy/box.sh web start <contact email>"; exit 2; }
                sync
                ssh "$HOST" "cd $DIR && echo '$contact' > contact \
                    && systemctl --user enable -q meiolol-web && systemctl --user restart meiolol-web"
                echo "started meiolol-web on $HOST"
                ;;
            stop) ssh "$HOST" "systemctl --user disable -q --now meiolol-web" ;;
            status)
                ssh "$HOST" "systemctl --user is-active meiolol-web; tail -n 3 $DIR/data/web.log"
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
    *) echo "usage: deploy/box.sh sync|start|stop|status|logs [n]|run <meiolol args>|site <contact>|web start [contact]|stop|status|backup|health start|stop|status|health check|watch install|uninstall"
       exit 2 ;;
esac
