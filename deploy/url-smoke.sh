#!/usr/bin/env bash
# deploy/url-smoke.sh: every old URL in deploy/nginx/redirect-samples.tsv through C01's
# nginx, as visitors reach it, expecting its new Location (docs/plan/urls.md). Prints the
# misses; exit 1 on any. 302 until URL4 turns them 301: STATUS=301 then
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC2016,SC2029
ssh essex-vm "STATUS=${STATUS:-302} bash -c '
bad=0
while IFS=\$(printf \"\\t\") read -r old want; do
    got=\$(curl -s -o /dev/null -w \"%{http_code} %header{location}\" -H \"Host: meio.lol\" \"http://127.0.0.1:8080\$old\")
    [[ \$got == \"\$STATUS \$want\" ]] || { echo \"\$old: \$got, want \$STATUS \$want\"; bad=1; }
done
exit \$bad'" < deploy/nginx/redirect-samples.tsv
