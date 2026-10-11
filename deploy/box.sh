#!/usr/bin/env bash
# Run the meiolol backend on the gpu-box PC (see ~/personal/gpu-box). The binary is
# cross-compiled here (static, musl) and copied over; data lives only on the box in
# ~/ml/meiolol/data.
set -euo pipefail

HOST=${GPU_HOST_ALIAS:-gpu-box}
DIR=ml/meiolol
SESSION=meiolol-crawl
WEB=meiolol-web
ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Builds a clean checkout of REV (default HEAD), never the working tree: other sessions
# keep uncommitted work there. The box logs each deploy in DEPLOYED
sync() {
    local rev tree
    rev=$(git -C "$ROOT" rev-parse "${REV:-HEAD}")
    tree=$(mktemp -d)
    git -C "$ROOT" worktree add -q --detach "$tree" "$rev"
    trap "git -C '$ROOT' worktree remove --force '$tree'" EXIT
    (cd "$tree" && zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSafe \
        --prefix zig-out/box)
    ssh "$HOST" "mkdir -p $DIR/bin $DIR/data"
    scp -q "$tree/zig-out/box/bin/meiolol" "$HOST:$DIR/bin/meiolol.new"
    scp -q "$tree/deploy/web-loop.sh" "$HOST:$DIR/bin/web-loop.sh.new"
    ssh "$HOST" "cd $DIR && mv bin/meiolol.new bin/meiolol && mv bin/web-loop.sh.new bin/web-loop.sh \
        && echo \"$rev $(date -u +%FT%TZ)\" >> DEPLOYED"
    echo "deployed $rev"
    if [[ -f "$ROOT/.env" ]]; then
        ssh "$HOST" "umask 077 && cat > $DIR/.env" < "$ROOT/.env"
    fi
}

case "${1:-}" in
    sync) sync ;;
    start)
        # Extra arguments go to `meiolol crawl` (eg --reserve 20)
        shift
        sync
        # Restart on crashes, but stop on exit 3 (key rejected) rather than hammer Riot
        ssh "$HOST" "cd $DIR && tmux new -d -s $SESSION \
            'while true; do bin/meiolol crawl $* >> data/crawl.log 2>&1; \
             [ \$? -eq 3 ] && echo KEY REJECTED >> data/crawl.log && break; \
             sleep 60; done'"
        echo "started $SESSION on $HOST"
        ;;
    stop) ssh "$HOST" "tmux kill-session -t $SESSION" ;;
    status)
        ssh "$HOST" "tmux has-session -t $SESSION 2>/dev/null && echo running \
            || echo stopped; cd $DIR && bin/meiolol status; \
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
                    && { tmux kill-session -t $WEB 2>/dev/null || true; } \
                    && tmux new -d -s $WEB 'bin/web-loop.sh $contact >> data/web.log 2>&1'"
                echo "started $WEB on $HOST"
                ;;
            stop) ssh "$HOST" "tmux kill-session -t $WEB" ;;
            status)
                ssh "$HOST" "tmux has-session -t $WEB 2>/dev/null && echo running || echo stopped; \
                    tail -n 3 $DIR/data/web.log"
                ;;
            *) echo "usage: deploy/box.sh web start [contact]|stop|status"; exit 2 ;;
        esac
        ;;
    *) echo "usage: deploy/box.sh sync|start|stop|status|logs [n]|run <meiolol args>|site <contact>|web start [contact]|stop|status"
       exit 2 ;;
esac
