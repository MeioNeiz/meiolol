#!/usr/bin/env bash
# Runs on the box (deploy/box.sh backup start): once a day at ~04:00 UTC, swap forgotten
# PUUIDs with the Your games service, then `meiolol backup` into $MEIOLOL_BACKUPS (set in
# host.env; default ~/ml/meiolol/backups, as backup-serve.sh's),
# then drop what a mirror has acked (deploy/backup-serve.sh prune). docs/data-safety.md.
set -u
cd "$(dirname "$0")/.." || exit 1
export MEIOLOL_BACKUPS=${MEIOLOL_BACKUPS:-$HOME/ml/meiolol/backups}
while true; do
    # Complete lists both ways (docs/your-games.md); the meiolol-exchange ssh alias is the
    # rrsync user on the web server. Skipped until the service is deployed
    if rsync -q meiolol-exchange:forgotten.txt data/exchange-forgotten.txt 2> /dev/null; then
        bin/meiolol forget --data data --list data/exchange-forgotten.txt \
            --backups "$MEIOLOL_BACKUPS" --export data/box-forgotten.txt \
            && rsync -q data/box-forgotten.txt meiolol-exchange:box-forgotten.txt \
            || echo "$(date -u +%FT%TZ) forgotten exchange FAILED"
    fi
    # A deploy or restart restarts this loop: no second heavy run beside the crawler
    if [[ ! -f "$MEIOLOL_BACKUPS/state/state-$(date -u +%F).db" ]]; then
        bin/meiolol backup --data data || echo "$(date -u +%FT%TZ) backup FAILED"
    fi
    # Files a mirror (the Mac, the gpu-box: deploy/backup-mirror.sh) holds leave the box
    bin/backup-serve.sh prune || echo "$(date -u +%FT%TZ) backup prune FAILED"
    sleep $(( $(date -u -d 'tomorrow 04:00' +%s) - $(date +%s) ))
done
