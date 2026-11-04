#!/usr/bin/env bash
# meionotes, Jacob's notes on the live site (meiolol meionotes, src/api/meionotes.zig), from
# a session: C01's api.db over ssh, as meiolol-api; --dev the dev server's file with this
# checkout's binary
#   deploy/meionotes.sh list [--status open|fixed|kept|done|any] [--by page|component]
#   deploy/meionotes.sh show N | fixed N REPLY | kept N REPLY | done N [REPLY]
#   deploy/meionotes.sh reopen N [REPLY] | reply N TEXT | delete N
#   deploy/meionotes.sh --dev list
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ${1:-} == --dev ]]; then
    shift
    exec zig-out/bin/meiolol meionotes "$@" --db data/snap/dev-meionotes.db
fi
HOST=${MEIONOTES_HOST:-essex-vm}
args=$(printf '%q ' "$@")
# C01's sudo wants a password (vault); never printed, only piped to sudo -S. $args is
# quoted here for the remote shell
# shellcheck disable=SC2029
printf '%s\n' "$(vault get meiolol/essex-vm SUDO_PASSWORD)" |
    ssh "$HOST" "sudo -S -p '' runuser -u meiolol-api -- /usr/local/bin/meiolol meionotes $args --data /var/lib/meiolol-api"
