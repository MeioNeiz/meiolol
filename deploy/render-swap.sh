#!/usr/bin/env bash
# Replaces the running renderer (meiolol-render@a or @b) without a gap: starts the other
# instance with the current binary, both listening on the port (SO_REUSEPORT) while it
# loads, and stops the old once the new one is serving. The new one reads data/views.bin
# in seconds. When a deploy changed the file's format (`meiolol site --views-format`
# differs from the file's: a part's types or sources), it first waits up to 3 h for the
# web loop's round to write one in the new format, the old renderer serving meanwhile,
# rather than load from the database beside it (4 min on a quiet box, over an hour on a
# busy one, 14 Oct); that round loads only the parts the deploy changed. Either way it
# then waits up to 30 min for that round's upload: the new binary's pages link the
# front-end files (style.css, *.js) the upload ships, and swapping first served new
# pages with the old files for the core build's 25-110 s (20 Oct). If the new one
# dies, or isn't ready within 60 minutes, the old one stays. Then its data's version goes
# into jomify's nginx cache key (cache-version.sh). Run detached on the box by
# deploy/box.sh web start; again if the binary changed meanwhile. Log in data/render.log
set -uo pipefail
cd "$(dirname "$0")/.." || exit

log() { echo "$(date -u +%FT%TZ) render-swap: $*" >> data/render.log; }
. bin/box-lib.sh

views_fits() {
    [[ -s data/views.bin ]] \
        && [[ $(od -An -t u8 -j 8 -N 8 data/views.bin | tr -d ' ') == "$(bin/meiolol site --views-format)" ]]
}

# The web loop's round for `sha` uploaded the site, or its build or upload failed
uploaded() {
    awk -F'\t' -v s="$1" '$2 == s && ($3 == "upload" || ($3 == "site" && $4 == "failed")) {
        f = 1 } END { exit !f }' data/deploys.tsv 2> /dev/null
}

while true; do
    binary=$(stat -c %Y bin/meiolol)
    sha=$(deployed_sha)
    if [[ -s data/views.bin ]] && ! views_fits; then
        log "data/views.bin is another format: waiting for the web loop's"
        deploy_event "$sha" swap waiting "views file in another format: waiting for the web loop's write"
        start=$SECONDS
        until views_fits || (( SECONDS - start >= 3 * 3600 )); do sleep 30; done
        if ! views_fits; then
            log "no views file in this format after 3 h: loading from the database"
            deploy_event "$sha" swap info "no views file in this format after 3 h: loading from the database"
        fi
    fi
    # Off, the web loop runs no round to wait for. 30 min: a curves pass running at the
    # deploy holds its round back. A deploy close behind gets the round instead (183
    # deploys to 20 Oct: each of the 10 with no upload had another within 8 min), so its
    # sha starts the wait again
    if systemctl --user -q is-active meiolol-web && ! uploaded "$sha"; then
        deploy_event "$sha" swap waiting "for the web loop's upload of the front-end files"
        start=$SECONDS
        until uploaded "$sha" || [[ $(deployed_sha) != "$sha" ]] \
            || (( SECONDS - start >= 1800 )); do sleep 5; done
        [[ $(deployed_sha) != "$sha" ]] && continue
        uploaded "$sha" || deploy_event "$sha" swap info "no upload after 30 min: swapping anyway"
    fi
    new=a
    systemctl --user -q is-active meiolol-render@a && new=b
    old=()
    # meiolol-render: the single unit before instances
    for u in meiolol-render meiolol-render@a meiolol-render@b; do
        [[ $u != "meiolol-render@$new" ]] && systemctl --user -q is-active "$u" && old+=("$u")
    done
    rm -f "data/render-$new.ready"
    systemctl --user enable -q "meiolol-render@$new"
    systemctl --user restart "meiolol-render@$new"
    log "started meiolol-render@$new beside ${old[*]:-nothing}"
    deploy_event "$sha" swap start "meiolol-render@$new beside ${old[*]:-nothing}"
    start=$SECONDS
    until [[ -e data/render-$new.ready ]] || (( SECONDS - start >= 3600 )) \
        || ! systemctl --user -q is-active "meiolol-render@$new"; do sleep 2; done
    if [[ ! -e data/render-$new.ready ]]; then
        systemctl --user disable -q --now "meiolol-render@$new"
        log "meiolol-render@$new not ready after $(( (SECONDS - start) / 60 )) min: stopped it, kept ${old[*]:-nothing}"
        deploy_event "$sha" swap failed "meiolol-render@$new not ready after $(( (SECONDS - start) / 60 )) min: kept ${old[*]:-nothing}"
        exit 1
    fi
    for u in "${old[@]}"; do systemctl --user disable -q --now "$u"; done
    log "meiolol-render@$new serving; stopped ${old[*]:-nothing}"
    deploy_event "$sha" swap ok "meiolol-render@$new serving; stopped ${old[*]:-nothing}"
    # Only now, with the old one gone: the new data's version into jomify's cache key
    systemctl --user start meiolol-cache-version
    [[ $(stat -c %Y bin/meiolol) == "$binary" ]] && exit 0
done
