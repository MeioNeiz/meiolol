#!/usr/bin/env bash
# VM6 (docs/plan/vm.md): meiolol moves from the Oracle box and jomify to C01. Waits for
# the VM3 chain's verdict (C01 ~/vm-chain/results.md) and goes on on "no downgrade" or
# "go" (slower under 2x) with vm.meio.lol serving static and rendered pages. Then: the
# box's units stopped and masked (a bulk push's deploy can't start its crawler beside
# C01's), the last copy pass and its check, jomify's API data copied (deploy/vm-web.sh
# data; jomify itself left as it is, Jacob 27 Oct), C01's loops started (crawler last),
# meio.lol and www to the tunnel, the Mac's scripts pointed at essex-vm. Push mode stays
# bulk: Jacob sets fast. Each done step leaves data/vm-cutover/<step>, so a rerun goes on
# from where it stopped; log in data/vm-cutover/log. Rollback:
# data/vm-cutover/dns-before.json back, the box's units unmasked, enabled and started (the
# data since the switch copied back first if C01 crawled).
#   deploy/vm-cutover.sh      run on the Mac: nohup, or a session's background task
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
S=$ROOT/data/vm-cutover
mkdir -p "$S"
ZONE=c7fe0d79a5f19acbce3a3884cf4a89f3
TUNNEL=1c7e296d-91e9-4538-8598-10833de3b9b0
BOX_UNITS="meiolol-crawl meiolol-web meiolol-render@a meiolol-render@b meiolol-backup \
meiolol-health meiolol-cache-version.path"
log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$S/log"; }
# A toast on the Mac (as mac-watch.sh), and the note of the session that started this
notify() {
    wz notify --for 3600 "meiolol VM6" "$1" 2> /dev/null || true
    cc-note needs --now "$1" 2> /dev/null || true
}
die() { log "STOPPED: $*"; notify "VM6 cut-over stopped: $* ($S/log)"; exit 1; }
step() {
    [[ -e $S/$1 ]] && return 0
    log "step $1"
    "$1" || die "step $1 failed"
    touch "$S/$1"
}
cf() {
    local method=$1 path=$2 body=${3:-}
    vault run personal/cloudflare -- sh -c 'curl -s -X "$1" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
        ${3:+--data "$3"} "https://api.cloudflare.com/client/v4$2"' _ "$method" "$path" "$body"
}

verdict() {
    local v
    until v=$(ssh -o ConnectTimeout=10 essex-vm 'tail -n 1 ~/vm-chain/results.md' 2> /dev/null) \
        && [[ $v == VERDICT* ]]; do
        (( SECONDS > 12 * 3600 )) && { log "no verdict after 12 h"; return 1; }
        sleep 60
    done
    log "$v"
    [[ $v == "VERDICT: no downgrade" || $v == "VERDICT: go,"* ]]
}

# Static pages, the admin login and rendered pages (the chain's page list, its renderer)
# through the tunnel
precheck() {
    local p code want
    while read -r p want; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://vm.meio.lol$p")
        log "vm.meio.lol$p: $code"
        [[ $code == "$want" ]] || return 1
    done < <(printf '/ 200\n/admin/ 302\n'
        ssh essex-vm "grep -E '^/[A-Za-z0-9._/-]*\$' ~/vm-chain/pages | shuf -n 8" \
            | sed 's/$/ 200/')
}

freeze_box() {
    # shellcheck disable=SC2086 # unit list is words
    ssh meiolol-cloud "systemctl --user disable -q --now $BOX_UNITS; \
        systemctl --user mask -q $BOX_UNITS \
        && systemctl --user is-active $BOX_UNITS | sort | uniq -c"
}

# A new inode, so the chain's bash, if still running, keeps reading its own copy. The
# chain's renderer stops first: the pass rewrites the databases in place
final_copy() {
    scp -q deploy/vm-chain.sh essex-vm:vm-chain/deploy/vm-chain.sh.new \
        && ssh essex-vm 'systemctl --user stop meiolol-render@a meiolol-render@b \
            && rm -f ~/ml/meiolol/data/render-?.ready \
            && mv vm-chain/deploy/vm-chain.sh.new vm-chain/deploy/vm-chain.sh \
            && bash vm-chain/deploy/vm-chain.sh final'
}

# Read only on jomify, its API still running: a copy caught mid-write fails vm-web.sh's
# quick_check and is taken again
jomify_data() {
    local try
    for try in 1 2 3; do
        deploy/vm-web.sh data && return 0
        log "vm-web.sh data failed, try $try"
        sleep 20
    done
    return 1
}

c01_config() {
    ssh essex-vm 'cd ~/ml/meiolol && sed -i "s/10\.0\.0\.3:8092/127.0.0.1:8092/" crawl.args \
        && echo "MEIOLOL_BACKUPS=$HOME/ml/meiolol/backups" > host.env \
        && rm -f data/render-?.ready \
        && grep -o -- "--proxy [^ ]*" crawl.args'
}

c01_start() {
    local rev
    rev=$(git rev-parse origin/main)
    export MEIOLOL_HOST=essex-vm REV=$rev
    deploy/box.sh web start && deploy/box.sh backup start && deploy/box.sh health start \
        && deploy/box.sh start || return 1
    # The renderer serving before visitors arrive: C01's nginx has no copies to fall back on
    ssh essex-vm 'until ls ~/ml/meiolol/data/render-?.ready > /dev/null 2>&1 \
        || (( SECONDS > 900 )); do sleep 5; done; ls ~/ml/meiolol/data/render-?.ready'
}

dns() {
    local name id body r
    cf GET "/zones/$ZONE/dns_records?per_page=100" > "$S/dns-before.json"
    for name in meio.lol www.meio.lol; do
        id=$(jq -r --arg n "$name" '.result[] | select(.name == $n and (.type == "A" or
            .type == "CNAME")) | .id' "$S/dns-before.json")
        [[ -n $id ]] || return 1
        body=$(jq -nc --arg n "$name" --arg c "$TUNNEL.cfargotunnel.com" \
            '{type: "CNAME", name: $n, content: $c, proxied: true, ttl: 1,
              comment: "meiolol C01 tunnel (docs/plan/vm.md VM6)"}')
        r=$(cf PUT "/zones/$ZONE/dns_records/$id" "$body")
        log "$name: $(jq -c '{success, errors}' <<< "$r")"
        if [[ $(jq -r .success <<< "$r") != true ]]; then
            cf DELETE "/zones/$ZONE/dns_records/$id" > /dev/null
            r=$(cf POST "/zones/$ZONE/dns_records" "$body")
            log "$name, delete and create: $(jq -c '{success, errors}' <<< "$r")"
        fi
        [[ $(jq -r .success <<< "$r") == true ]] || return 1
    done
}

verify() {
    local code
    for _ in $(seq 30); do
        code=$(curl -s -o /dev/null -w '%{http_code} %header{cf-ray}' --max-time 20 \
            https://meio.lol/)
        [[ $code == 200\ ?* ]] && { log "meio.lol through Cloudflare: $code"; return 0; }
        sleep 10
    done
    log "meio.lol: $code"
    return 1
}

# The Mac's scripts at essex-vm, the training upload at C01's meiolol user; then
# the queued bulk batch deploys to C01
mac_switch() {
    local f t=$SECONDS files=(deploy/box.sh deploy/desktop-release.sh deploy/dev.sh
        deploy/deploy-events.sh deploy/mac-watch.sh deploy/on-push.sh deploy/lab-push.sh)
    # Another session's uncommitted hunks there would be swept into this commit
    until git diff --quiet HEAD -- "${files[@]}"; do
        (( SECONDS - t > 1800 )) && { log "still dirty after 30 min:" \
            "$(git diff --name-only HEAD -- "${files[@]}" | paste -sd' ' -)"; return 1; }
        sleep 60
    done
    for f in "${files[@]:0:6}"; do
        sed -i '' 's/\${MEIOLOL_HOST:-meiolol-cloud}/${MEIOLOL_HOST:-essex-vm}/' "$f"
    done
    sed -i '' 's/^WEB=meiolol@193\.123\.180\.81$/WEB=meiolol@100.95.95.44/' deploy/lab-push.sh
    grep -q 'meiolol-cloud}' deploy/box.sh && return 1
    deploy/commit.sh -m "Backend host is C01 (essex-vm): the Mac's scripts and the training upload" \
        -- "${files[@]}" || return 1
    deploy/push.sh "$(git log -1 --format=%H -- deploy/lab-push.sh)"
}

# Its mirrors and archive pulls reach C01 only over Tailscale; until it has it they fail
# and log, nothing else. The gpu-box may be off: then left for a rerun
gpu_box() {
    ssh -o ConnectTimeout=20 gpu-box 'f=~/.ssh/config; cp "$f" "$f.bak-vm6" && awk "
        /^Host / { h = \$2 }
        h ~ /^meiolol-(archive|backup)\$/ && \$1 == \"HostName\" { \$0 = \"  HostName 100.95.95.44\" }
        h ~ /^meiolol-(archive|backup)\$/ && \$1 == \"User\" { \$0 = \"  User jacob\" }
        h == \"meiolol-accounts\" && \$1 == \"HostName\" { \$0 = \"  HostName 100.95.95.44\" }
        { print }" "$f.bak-vm6" > "$f" && systemctl --user start meiolol-archive-pull.timer'
}

step verdict
step precheck
step freeze_box
step final_copy
step jomify_data
step c01_config
step c01_start
step dns
step verify
step mac_switch
left=''
if [[ ! -e $S/gpu_box ]]; then
    if gpu_box; then touch "$S/gpu_box"; else left='; gpu-box off: rerun deploy/vm-cutover.sh'; fi
fi
log "VM6 done$left. Watch a day of crawl, a web round, a backup mirrored, a cache-warm run"
notify "VM6 cut-over done: meio.lol is on C01$left ($S/log)"
