#!/usr/bin/env bash
# The gpu-box's standing meiolol pieces, which no push deploys: the League watcher
# (lab-watch.sh), the raw archive pull (archive-pull.sh), the backup mirror
# (backup-mirror.sh, with the meiolol it runs `backup --mirror` with), their systemd user
# units, and the Windows side (deploy/windows, CRLF, in %USERPROFILE%\.meiolol). Scripts
# and units install from HEAD's committed copy and meiolol from a clean checkout of HEAD,
# never the working tree (jomify.sh's rule: 17 Oct, a hand copy ran 3 commits old).
# Installs are recorded in ~/ml/bin/installed ("meiolol SHA TIME"), which drift reads.
# Run-time pieces are elsewhere: lab-run.sh copies lab-gates/lab-usage into each run,
# snapshot.sh copies snapshot-gpu.sh for each make. docs/compute.md
#
#   deploy/gpu-box.sh drift       installed vs HEAD, per piece
#   deploy/gpu-box.sh install     every piece, then daemon-reload, the watcher restarted
#                                 (its runs live on: KillMode=process) and the timers on
set -euo pipefail

HOST=${GPU_HOST:-gpu-box}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
SCRIPTS=(lab-watch.sh archive-pull.sh backup-mirror.sh)
UNITS=(meiolol-lab-watch.service meiolol-archive-pull.service meiolol-archive-pull.timer
    meiolol-backup-mirror.service meiolol-backup-mirror.timer)
TIMERS=(meiolol-archive-pull.timer meiolol-backup-mirror.timer)
WATCH=meiolol-lab-watch
RECORD=ml/bin/installed
# What the mirror's meiolol is built from, for drift. Lab and GPU code isn't in it
MEIOLOL_PATHS=(src build.zig build.zig.zon ':(exclude)src/lab' ':(exclude)src/gpu')

head_hash() { git -C "$ROOT" show "HEAD:$1" | shasum -a 256 | cut -d' ' -f1; }
crlf_hash() { git -C "$ROOT" show "HEAD:$1" | sed 's/$/\r/' | shasum -a 256 | cut -d' ' -f1; }
windows() { git -C "$ROOT" ls-tree --name-only HEAD deploy/windows/; }
# %USERPROFILE%\.meiolol as a WSL path. cmd.exe reads stdin, so it gets /dev/null
# shellcheck disable=SC2016 # expands on the host
win_dir() {
    ssh "$HOST" 'cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /c "echo %USERPROFILE%" \
        < /dev/null | tr -d "\r\n" | xargs -0 wslpath'
}

drift() {
    local paths=() want=() have win f i
    win=$(win_dir)/.meiolol
    for f in "${SCRIPTS[@]}"; do paths+=("ml/bin/$f"); want+=("$(head_hash "deploy/$f")"); done
    for f in "${UNITS[@]}"; do
        paths+=(".config/systemd/user/$f")
        want+=("$(head_hash "deploy/systemd/$f")")
    done
    while read -r f; do
        paths+=("$win/${f##*/}")
        want+=("$(crlf_hash "$f")")
    done < <(windows)
    # One line per path, - when missing
    have=$(ssh "$HOST" "for p in $(printf "'%s' " "${paths[@]}"); do \
        if [ -f \"\$p\" ]; then sha256sum \"\$p\" | cut -d' ' -f1; else echo -; fi; done")
    i=0
    while IFS= read -r f; do
        if [[ "$f" == "${want[i]}" ]]; then echo "${paths[i]##*/}: same as HEAD"
        elif [[ "$f" == - ]]; then echo "${paths[i]##*/}: MISSING (deploy/gpu-box.sh install)"
        else echo "${paths[i]##*/}: DIFFERS from HEAD (deploy/gpu-box.sh install)"; fi
        i=$(( i + 1 ))
    done <<< "$have"
    local rev
    rev=$(ssh "$HOST" "awk '\$1 == \"meiolol\" { s = \$2 } END { print s }' $RECORD 2> /dev/null || true")
    if [[ -z "$rev" ]] || ! git -C "$ROOT" cat-file -e "$rev^{commit}" 2> /dev/null; then
        echo "meiolol: installed commit not recorded in ~/$RECORD"
    elif git -C "$ROOT" diff --quiet "$rev" HEAD -- "${MEIOLOL_PATHS[@]}"; then
        echo "meiolol: ${rev:0:7}, no change in its sources since"
    else
        echo "meiolol: ${rev:0:7}, HEAD changes its sources in" \
            "$(git -C "$ROOT" rev-list --count "$rev..HEAD" -- "${MEIOLOL_PATHS[@]}") commits"
    fi
}

install() {
    local rev tmp win f
    rev=$(git -C "$ROOT" rev-parse HEAD)
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064 # expand now
    trap "rm -rf '$tmp'" EXIT
    mkdir "$tmp/bin" "$tmp/units"
    for f in "${SCRIPTS[@]}"; do git -C "$ROOT" show "HEAD:deploy/$f" > "$tmp/bin/$f"; done
    chmod 755 "$tmp"/bin/*
    for f in "${UNITS[@]}"; do git -C "$ROOT" show "HEAD:deploy/systemd/$f" > "$tmp/units/$f"; done
    # shellcheck disable=SC2016 # the inner sh expands them
    "$ROOT/deploy/build-tree.sh" gpu-box "$rev" sh -c 'zig build backend -Doptimize=ReleaseSafe \
        -Dtarget=x86_64-linux-musl -Dcpu=x86_64_v3 --prefix zig-out/gpu-box \
        --cache-dir "$1/.zig-cache" && cp zig-out/gpu-box/bin/meiolol "$2/bin/meiolol.new"' \
        _ "$ROOT" "$tmp"
    ssh "$HOST" "mkdir -p ml/bin ml/runs .config/systemd/user"
    scp -q "$tmp"/bin/* "$HOST:ml/bin/"
    # The units' environment drop-ins on the host (*.d/) are kept
    scp -q "$tmp"/units/* "$HOST:.config/systemd/user/"
    ssh "$HOST" "mv ml/bin/meiolol.new ml/bin/meiolol \
        && echo 'meiolol $rev $(date -u +%FT%TZ)' >> $RECORD"
    # WSL can write there, so nothing there runs elevated: the archive mount (admin) is
    # installed once, by hand, by install-watchdog.ps1 (docs/compute.md)
    win=$(win_dir)/.meiolol
    ssh "$HOST" "mkdir -p '$win'"
    while read -r f; do
        git -C "$ROOT" show "HEAD:$f" | sed 's/$/\r/' | ssh "$HOST" "cat > '$win/${f##*/}'"
    done < <(windows)
    ssh "$HOST" "loginctl enable-linger \$USER; systemctl --user daemon-reload \
        && systemctl --user enable -q $WATCH ${TIMERS[*]} \
        && systemctl --user restart $WATCH \
        && systemctl --user start ${TIMERS[*]} \
        && systemctl --user is-active $WATCH ${TIMERS[*]}"
    echo "installed $(git -C "$ROOT" rev-parse --short HEAD) on $HOST"
}

case "${1:-}" in
    drift) drift ;;
    install) install ;;
    *) usage_of "$0"; exit 2 ;;
esac
