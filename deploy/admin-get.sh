#!/usr/bin/env bash
# deploy/admin-get.sh URL|PATH [curl args]: GET a meio.lol /admin/ page or file as the
# meiolol-check account (role admin: sees /admin, not the owner's controls). The password
# never reaches argv, the screen or a transcript: vault group meiolol/local
# (MEIOLOL_CHECK_PASSWORD) over ssh stdin. Runs on C01, as the Mac can't reach meio.lol
# (Sophos). PATH is under /admin/ (`models/draft-model.json`)
set -euo pipefail
(( $# )) || { echo "usage: deploy/admin-get.sh URL|PATH [curl args]" >&2; exit 2; }
if [[ -z ${MEIOLOL_CHECK_PASSWORD:-} ]]; then
    [[ -z ${ADMIN_GET_VAULTED:-} ]] || { echo "admin-get: MEIOLOL_CHECK_PASSWORD not in meiolol/local" >&2; exit 2; }
    ADMIN_GET_VAULTED=1 exec vault run meiolol/local -- "$0" "$@"
fi
url=$1
shift
[[ "$url" == http* ]] || url=https://meio.lol/admin/${url#/}
# Quoted for the remote shell
args=$(printf '%q ' "$@" "$url")
# shellcheck disable=SC2016,SC2029
printf '%s\n' "$MEIOLOL_CHECK_PASSWORD" | ssh essex-vm "set -euo pipefail
jar=\$(mktemp)
trap 'curl -s -o /dev/null -b \"\$jar\" -H \"x-meiolol-action: 1\" -X POST https://meio.lol/auth/logout
    rm -f \"\$jar\"' EXIT
read -r pw
printf '{\"username\":\"meiolol-check\",\"password\":\"%s\"}' \"\$pw\" |
    curl -sS --fail -o /dev/null -c \"\$jar\" -H 'content-type: application/json' \\
        -H 'x-meiolol-action: 1' --data-binary @- https://meio.lol/auth/login
curl -sS --fail -b \"\$jar\" $args"
