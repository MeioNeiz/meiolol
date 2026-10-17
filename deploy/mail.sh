#!/usr/bin/env bash
# Mail for @meio.lol: Cloudflare Email Routing sends every address to the Email Worker in
# deploy/mail-worker.js, which keeps each message in KV (namespace meio-mail). Needs the
# Cloudflare token: run as `vault run personal/cloudflare -- deploy/mail.sh ...`.
#
#   deploy/mail.sh deploy         KV namespace (once), the worker, the catch-all rule
#   deploy/mail.sh list           newest first: key | from | to | subject
#   deploy/mail.sh read KEY       headers and the text part (--raw: the whole .eml)
#   deploy/mail.sh delete KEY
set -euo pipefail

: "${CLOUDFLARE_API_TOKEN:?run under: vault run personal/cloudflare -- deploy/mail.sh}"
ACCT=${CLOUDFLARE_ACCOUNT_ID:?}
API=https://api.cloudflare.com/client/v4
DOMAIN=meio.lol
NAME=meio-mail
JS_MODULE=application/javascript+module
here=$(cd "$(dirname "$0")" && pwd)

cf() {
    local method=$1 path=$2
    shift 2
    curl -sS -X "$method" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" "$@" \
        "$API$path"
}

# Fails loudly on Cloudflare's {"success":false}
ok() {
    jq -e '.success' >/dev/null <<<"$1" || { jq -c '.errors' <<<"$1" >&2; exit 1; }
}

kv_id() {
    cf GET "/accounts/$ACCT/storage/kv/namespaces?per_page=100" \
        | jq -r --arg n "$NAME" '.result[] | select(.title == $n) | .id'
}

KV() { echo "/accounts/$ACCT/storage/kv/namespaces/$(kv_id)"; }

case ${1:-} in
deploy)
    ns=$(kv_id)
    if [[ -z "$ns" ]]; then
        r=$(cf POST "/accounts/$ACCT/storage/kv/namespaces" \
            -H 'Content-Type: application/json' -d "{\"title\":\"$NAME\"}")
        ok "$r"
        ns=$(jq -r '.result.id' <<<"$r")
    fi
    meta=$(jq -nc --arg ns "$ns" '{main_module: "worker.js",
        compatibility_date: "2026-10-01",
        bindings: [{type: "kv_namespace", name: "MAIL", namespace_id: $ns}]}')
    r=$(cf PUT "/accounts/$ACCT/workers/scripts/$NAME" \
        -F "metadata=$meta;type=application/json" \
        -F "worker.js=@$here/mail-worker.js;filename=worker.js;type=$JS_MODULE")
    ok "$r"
    zone=$(cf GET "/zones?name=$DOMAIN" | jq -r '.result[0].id')
    r=$(cf PUT "/zones/$zone/email/routing/rules/catch_all" \
        -H 'Content-Type: application/json' \
        -d "{\"enabled\":true,\"matchers\":[{\"type\":\"all\"}],
            \"actions\":[{\"type\":\"worker\",\"value\":[\"$NAME\"]}]}")
    ok "$r"
    echo "deployed: every @$DOMAIN address -> worker $NAME -> KV $ns"
    ;;
list)
    cf GET "$(KV)/keys?prefix=msg/&limit=1000" \
        | jq -r '.result | reverse[]
            | [.name, .metadata.from, .metadata.to, .metadata.subject] | join(" | ")'
    ;;
read)
    key=${2:?usage: deploy/mail.sh read KEY [--raw]}
    if [[ ${3:-} == --raw ]]; then
        cf GET "$(KV)/values/$(jq -rn --arg k "$key" '$k | @uri')"
        exit
    fi
    cf GET "$(KV)/values/$(jq -rn --arg k "$key" '$k | @uri')" | python3 -I -c '
import email, email.policy, sys
m = email.message_from_binary_file(sys.stdin.buffer, policy=email.policy.default)
for h in ("Date", "From", "To", "Cc", "Reply-To", "Subject"):
    if m[h]:
        print(f"{h}: {m[h]}")
print()
body = m.get_body(("plain", "html"))
print(body.get_content() if body else "(no text part)")
for part in m.iter_attachments():
    print(f"[attachment: {part.get_filename()} {part.get_content_type()}]")
'
    ;;
delete)
    key=${2:?usage: deploy/mail.sh delete KEY}
    ok "$(cf DELETE "$(KV)/values/$(jq -rn --arg k "$key" '$k | @uri')")"
    ;;
*)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
