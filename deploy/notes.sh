#!/usr/bin/env bash
# Jacob's notes on the live site (meiolol notes, src/api/notes.zig) from a session: C01's
# api.db over ssh, as meiolol-api; --dev the dev server's file with this checkout's binary
#   deploy/notes.sh list [--status open|fixed|kept|done|any] [--by page|component]
#   deploy/notes.sh show N | fixed N REPLY | kept N REPLY | done N [REPLY]
#   deploy/notes.sh reopen N [REPLY] | reply N TEXT
#   deploy/notes.sh --dev list
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ${1:-} == --dev ]]; then
    shift
    exec zig-out/bin/meiolol notes "$@" --db data/snap/dev-notes.db
fi
HOST=${NOTES_HOST:-essex-vm}
args=$(printf '%q ' "$@")
# C01's sudo wants a password (vault); never printed, only piped to sudo -S. $args is
# quoted here for the remote shell
# shellcheck disable=SC2029
printf '%s\n' "$(vault get meiolol/essex-vm SUDO_PASSWORD)" |
    ssh "$HOST" "sudo -S -p '' runuser -u meiolol-api -- /usr/local/bin/meiolol notes $args --data /var/lib/meiolol-api"
