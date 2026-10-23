#!/usr/bin/env bash
# The logins (accounts.db on the web server) to the gpu-box (systemd user timer
# meiolol-accounts-pull, every 6 h): a consistent copy over the forced-command key (host
# meiolol-accounts; the web server runs deploy/accounts-send.sh), checked by opening it,
# kept as DIR/accounts-DATE.db, the newest 14 days (privacy policy "Accounts": a deleted
# login leaves the backups within 14 days). Restore: docs/data-safety.md "Logins backup"
#   accounts-pull.sh DIR MEIOLOL
set -euo pipefail
dir=$1 bin=$2
keep=14
log() { echo "$(date -u +%FT%TZ) accounts pull: $*"; }

# Password hashes and emails: owner only
umask 077
mkdir -p "$dir"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ssh -nT -o BatchMode=yes -o ServerAliveInterval=30 meiolol-accounts > "$tmp/accounts.db"
if [[ $(head -c 15 "$tmp/accounts.db") != "SQLite format 3" ]]; then
    log "FAILED: not a SQLite file ($(wc -c < "$tmp/accounts.db") bytes)"
    exit 1
fi
# Opened from a copy (opening writes its journal mode), so the kept file is as sent. The
# owner always exists: none means a wrong or new database
mkdir "$tmp/check"
cp "$tmp/accounts.db" "$tmp/check/accounts.db"
n=$("$bin" account list --data "$tmp/check" | wc -l)
if ((n == 0)); then
    log "FAILED: no accounts in the copy"
    exit 1
fi
out=$dir/accounts-$(date -u +%F).db
mv "$tmp/accounts.db" "$out"
log "$out: $n accounts, $(wc -c < "$out") bytes"
find "$dir" -maxdepth 1 -name 'accounts-*.db' | sort | head -n -"$keep" | xargs -r rm --
