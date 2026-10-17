#!/usr/bin/env bash
# deploy/admin-get.sh URL|PATH [curl args]: GET a meio.lol /admin/ page or file with the
# basic-auth login, which never reaches argv, the screen or a transcript (17 Oct: curl -u
# and curl's password prompt printed it three times). PATH is under /admin/
# (`models/draft-model.json`). The password comes from vault group meiolol/local
# (MEIOLOL_API_BASIC_AUTH); the script runs itself under `vault run` when it is unset
set -euo pipefail
(( $# )) || { echo "usage: deploy/admin-get.sh URL|PATH [curl args]" >&2; exit 2; }
if [[ -z ${MEIOLOL_API_BASIC_AUTH:-} ]]; then
    [[ -z ${ADMIN_GET_VAULTED:-} ]] || { echo "admin-get: MEIOLOL_API_BASIC_AUTH not in meiolol/local" >&2; exit 2; }
    ADMIN_GET_VAULTED=1 exec vault run meiolol/local -- "$0" "$@"
fi
url=$1
shift
[[ "$url" == http* ]] || url=https://meio.lol/admin/${url#/}
# curl reads the login from its config on stdin (-K -), not from its arguments
printf 'user = "meiolol:%s"\n' "$MEIOLOL_API_BASIC_AUTH" | curl -sS --fail -K - "$@" "$url"
