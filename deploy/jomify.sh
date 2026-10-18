#!/usr/bin/env bash
# The jomify web server's meiolol pieces, which the box's push deploy doesn't touch and
# were installed by hand (17 Oct: meiolol-traffic ran a copy 3 commits old, and two by-hand
# scp's broke on zsh word splitting of "ssh -i ..." in a variable). Host alias jomify
# (~/.ssh/config); jomove, an unrelated house-moving app, shares the server, so this
# touches only meiolol's files. Scripts install from HEAD's committed copy, never the
# working tree.
#
#   deploy/jomify.sh drift                 installed vs HEAD, per piece
#   deploy/jomify.sh install traffic|cache-version|training-receive
#   deploy/jomify.sh install api [REV]     Your games API binary (docs/your-games.md)
#
# api: built from a clean checkout of REV (default HEAD) for x86_64 musl, the old binary
# kept as /usr/local/bin/meiolol.bak-pre-<short rev>, meiolol-api restarted and watched
# 30 s; one that is not up and steady by then is rolled back. Installs are recorded in
# /usr/local/share/meiolol/installed ("api SHA TIME"), which drift reads
set -euo pipefail

HOST=${JOMIFY_HOST:-jomify}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RECORD=/usr/local/share/meiolol/installed
PIECES=(traffic cache-version training-receive)
# A piece's repo file (macOS bash 3.2: no associative arrays); installed as
# /usr/local/bin/meiolol-PIECE
src() {
    case $1 in
        traffic) echo deploy/traffic.sh ;;
        cache-version) echo deploy/cache-version-receive.sh ;;
        training-receive) echo deploy/training-receive.sh ;;
    esac
}
UNITS=(meiolol-traffic.service meiolol-traffic.timer)
# What the API binary is built from, for drift: a change elsewhere doesn't change it
API_PATHS=(src/api src/core)

remote_hash() { ssh "$HOST" "sha256sum $1 2> /dev/null | cut -d' ' -f1"; }
head_hash() { git -C "$ROOT" show "HEAD:$1" | shasum -a 256 | cut -d' ' -f1; }

drift() {
    local p f
    for p in "${PIECES[@]}"; do
        if [[ "$(remote_hash "/usr/local/bin/meiolol-$p")" == "$(head_hash "$(src "$p")")" ]]; then
            echo "$p: same as HEAD"
        else
            echo "$p: DIFFERS from HEAD's $(src "$p") (deploy/jomify.sh install $p)"
        fi
    done
    for f in "${UNITS[@]}"; do
        if [[ "$(remote_hash "/etc/systemd/system/$f")" == "$(head_hash "deploy/systemd/$f")" ]]; then
            echo "$f: same as HEAD"
        else
            echo "$f: DIFFERS from HEAD's deploy/systemd/$f (install by hand, then daemon-reload)"
        fi
    done
    local api
    api=$(ssh "$HOST" "awk '\$1 == \"api\" { s = \$2 } END { print s }' $RECORD 2> /dev/null || true")
    if [[ -z "$api" ]] || ! git -C "$ROOT" cat-file -e "$api^{commit}" 2> /dev/null; then
        echo "api: installed commit not recorded in $RECORD"
    elif git -C "$ROOT" diff --quiet "$api" HEAD -- "${API_PATHS[@]}"; then
        echo "api: ${api:0:7}, no change in ${API_PATHS[*]} since"
    else
        echo "api: ${api:0:7}, HEAD changes ${API_PATHS[*]} in $(git -C "$ROOT" rev-list --count "$api..HEAD" -- "${API_PATHS[@]}") commits (deploy/jomify.sh install api):"
        git -C "$ROOT" log --format='  %h %s' "$api..HEAD" -- "${API_PATHS[@]}" | cut -c1-110
    fi
}

install_script() {
    local p=$1 tmp
    tmp=$(mktemp)
    git -C "$ROOT" show "HEAD:$(src "$p")" > "$tmp"
    scp -q "$tmp" "$HOST:/tmp/meiolol-$p.new"
    rm -f "$tmp"
    ssh "$HOST" "sudo install -m 755 /tmp/meiolol-$p.new /usr/local/bin/meiolol-$p && rm /tmp/meiolol-$p.new"
    echo "$p: installed $(src "$p") at $(git -C "$ROOT" rev-parse --short HEAD) as /usr/local/bin/meiolol-$p"
}

install_api() {
    local rev short out
    rev=$(git -C "$ROOT" rev-parse "${1:-HEAD}^{commit}")
    short=${rev:0:7}
    out=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now
    trap "rm -rf '$out'" EXIT
    "$ROOT/deploy/build-tree.sh" jomify "$rev" sh -c 'zig build backend -Dtarget=x86_64-linux-musl \
        -Doptimize=ReleaseSafe --prefix zig-out/jomify --cache-dir "$1/.zig-cache" \
        && cp zig-out/jomify/bin/meiolol "$2/meiolol"' _ "$ROOT" "$out"
    scp -q "$out/meiolol" "$HOST:/tmp/meiolol-api.new"
    ssh "$HOST" "bash -s" "$rev" "$short" "$RECORD" <<'EOF'
set -u
rev=$1 short=$2 record=$3
bin=/usr/local/bin/meiolol bak=/usr/local/bin/meiolol.bak-pre-$short
sudo cp -p "$bin" "$bak"
sudo install -m 755 /tmp/meiolol-api.new "$bin" && rm /tmp/meiolol-api.new
restarts() { systemctl show -p NRestarts --value meiolol-api; }
steady() {
    local n i
    sudo systemctl restart meiolol-api
    n=$(restarts)
    for i in $(seq 30); do
        sleep 1
        [[ $(restarts) == "$n" ]] || return 1
    done
    systemctl -q is-active meiolol-api
}
if steady; then
    sudo mkdir -p "$(dirname "$record")"
    echo "api $rev $(date -u +%FT%TZ)" | sudo tee -a "$record" > /dev/null
    echo "api: $short installed and steady for 30 s; old binary kept as $bak"
    exit 0
fi
echo "api: $short not steady after restart, rolling back"
sudo journalctl -u meiolol-api -n 8 --no-pager
sudo install -m 755 "$bak" "$bin"
sudo systemctl restart meiolol-api
exit 1
EOF
}

case "${1:-}" in
    drift) drift ;;
    install)
        case "${2:-}" in
            traffic | cache-version | training-receive) install_script "$2" ;;
            api) install_api "${3:-}" ;;
            *) echo "usage: deploy/jomify.sh install traffic|cache-version|training-receive|api [REV]"; exit 2 ;;
        esac
        ;;
    *) echo "usage: deploy/jomify.sh drift|install PIECE"; exit 2 ;;
esac
