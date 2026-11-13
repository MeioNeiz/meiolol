#!/usr/bin/env bash
# Runs on the box (deploy/box.sh backup start): once a day at ~04:00 UTC, swap forgotten
# PUUIDs with the Your games service, then `meiolol backup` into $MEIOLOL_BACKUPS (set in
# host.env; default ~/ml/meiolol/backups, as backup-serve.sh's),
# then drop what a mirror has acked (deploy/backup-serve.sh prune). docs/data-safety.md.
set -u
cd "$(dirname "$0")/.." || exit 1
export MEIOLOL_BACKUPS=${MEIOLOL_BACKUPS:-$HOME/ml/meiolol/backups}
# Complete lists both ways (docs/your-games.md); the meiolol-exchange ssh alias is the
# rrsync user on the web server. Skipped until the service is deployed
# A failed day file scrub after the export (health.sh reports it) still sends the list
if rsync -q meiolol-exchange:forgotten.txt data/exchange-forgotten.txt 2> /dev/null; then
    rm -f data/box-forgotten.txt
    bin/meiolol forget --data data --list data/exchange-forgotten.txt \
        --backups "$MEIOLOL_BACKUPS" --export data/box-forgotten.txt \
        || echo "$(date -u +%FT%TZ) forget FAILED"
    [[ -f data/box-forgotten.txt ]] \
        && rsync -q data/box-forgotten.txt meiolol-exchange:box-forgotten.txt \
        || echo "$(date -u +%FT%TZ) forgotten exchange FAILED"
fi
# A restart runs this again: no second heavy run beside the crawler
if [[ ! -f "$MEIOLOL_BACKUPS/state/state-$(date -u +%F).db" ]]; then
    # One heavy reader of the data disk at a time (docs/hosting.md "Heavy lock"); after an
    # hour's wait, beside the holder
    (exec 7> data/heavy.lock
        if flock -w 3600 7; then
            echo "backup, since $(date -u +%FT%TZ)" > data/heavy.who
        else
            echo "$(date -u +%FT%TZ) heavy lock held an hour by $(cat data/heavy.who):" \
                "backup beside it"
        fi
        bin/meiolol backup --data data) || echo "$(date -u +%FT%TZ) backup FAILED"
fi
# Files a mirror (the Mac, the gpu-box: deploy/backup-mirror.sh) holds leave the box
bin/backup-serve.sh prune || echo "$(date -u +%FT%TZ) backup prune FAILED"
sleep $(( $(date -u -d 'tomorrow 04:00' +%s) - $(date +%s) ))
# Deploys don't restart the loop and bash keeps the script it parsed: the deployed one
exec bin/backup-loop.sh
