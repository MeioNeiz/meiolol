#!/usr/bin/env bash
# The gpu-box's standing meiolol pieces, which no push deploys: the League watcher
# (lab-watch.sh), the raw archive pull (archive-pull.sh), the backup mirror
# (backup-mirror.sh, with the meiolol it runs `backup --mirror` with), their systemd user
# units, and the Windows side (deploy/windows, CRLF, in %USERPROFILE%\.meiolol). Scripts
# and units install from HEAD's committed copy and meiolol from a clean checkout of HEAD,
# never the working tree (jomify.sh's rule: 17 Oct, a hand copy ran 3 commits old).
# Installs are recorded in ~/ml/bin/installed ("meiolol SHA TIME"), which drift reads.
# WSL's /etc gets deploy/wsl (the lab disk's writeback and queue limits) as root, through
# wsl.exe -u root, as does apt for the tools ci needs there (deploy/remote-build.sh):
# zstd, shellcheck, jq; node from nodejs.org into ~/.local. Run-time pieces are elsewhere: lab-run.sh copies lab-gates
# and lab-usage into each run, snapshot.sh copies snapshot-gpu.sh for each make,
# remote-build.sh sends build-job.sh with each build. docs/compute.md
#
#   deploy/gpu-box.sh drift       installed vs HEAD, per piece
#   deploy/gpu-box.sh install     every piece, then daemon-reload, the watcher restarted
#                                 (its runs live on: KillMode=process) and the timers on
set -euo pipefail

HOST=${GPU_HOST:-gpu-box}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
SCRIPTS=(lab-watch.sh archive-pull.sh backup-mirror.sh accounts-pull.sh)
UNITS=(meiolol-lab-watch.service meiolol-archive-pull.service meiolol-archive-pull.timer
    meiolol-backup-mirror.service meiolol-backup-mirror.timer meiolol-accounts-pull.service
    meiolol-accounts-pull.timer)
TIMERS=(meiolol-archive-pull.timer meiolol-backup-mirror.timer meiolol-accounts-pull.timer)
ETC=(sysctl.d/60-meiolol-disk.conf udev/rules.d/60-meiolol-disk.rules)
# Root without a PATH: commands by full path
WSL_ROOT="/mnt/c/Windows/System32/wsl.exe -u root -e"
WATCH=meiolol-lab-watch
# Commands ci needs on the gpu-box: apt's zstd, shellcheck and jq, and node, which
# Ubuntu ships too old (18: `node --check` fails on ES modules), from nodejs.org
CI_TOOLS="zstd shellcheck jq node"
NODE_VERSION=v24.22.2
NODE=node-$NODE_VERSION-linux-x64
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
    for f in "${ETC[@]}"; do paths+=("/etc/$f"); want+=("$(head_hash "deploy/wsl/${f##*/}")"); done
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
    ssh "$HOST" "PATH=\$HOME/.local/bin:\$PATH; for t in $CI_TOOLS; do command -v \$t > /dev/null || echo \"\$t: MISSING (deploy/gpu-box.sh install)\"; done"
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
    mkdir "$tmp/bin" "$tmp/units" "$tmp/etc"
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
    for f in "${ETC[@]}"; do git -C "$ROOT" show "HEAD:deploy/wsl/${f##*/}" > "$tmp/etc/${f##*/}"; done
    scp -q "$tmp"/etc/* "$HOST:/tmp/"
    ssh "$HOST" "for f in ${ETC[*]}; do $WSL_ROOT install -m 644 /tmp/\${f##*/} /etc/\$f || exit 1; \
        rm /tmp/\${f##*/}; done; $WSL_ROOT /usr/sbin/sysctl -q --system \
        && $WSL_ROOT /usr/bin/udevadm control --reload \
        && $WSL_ROOT /usr/bin/udevadm trigger --action=change --subsystem-match=block"
    ssh "$HOST" "command -v zstd shellcheck jq > /dev/null || { $WSL_ROOT /usr/bin/apt-get -qq update \
        && $WSL_ROOT /usr/bin/env DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get -qq -y install \
        zstd shellcheck jq > /dev/null; }"
    ssh "$HOST" "set -e; [ -x .local/node/$NODE/bin/node ] || { u=https://nodejs.org/dist/$NODE_VERSION; \
        cd /tmp; curl -fsSLO \$u/$NODE.tar.xz; \
        curl -fsSL \$u/SHASUMS256.txt | grep ' $NODE.tar.xz\$' | sha256sum -c --quiet -; \
        mkdir -p ~/.local/node; tar -xJf $NODE.tar.xz -C ~/.local/node; rm $NODE.tar.xz; }; \
        mkdir -p .local/bin; ln -sfn ~/.local/node/$NODE/bin/node .local/bin/node"
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
