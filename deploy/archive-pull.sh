#!/usr/bin/env bash
# On the gpu-box, hourly (systemd user timer meiolol-archive-pull): the raw archive
# (docs/data-safety.md "Raw archive"). Asks the box for a new export, fetches every
# export waiting there, archives it pseudonymised (meiolol-lab archive) and only then
# acks it, so the box drops raw documents only once they are archived here. Players
# newly forgotten on the box are erased from what is already archived; days past 24
# months lose their player ids. Skips a round while League is open (Jacob's rule for
# long jobs on this PC); the box keeps everything unacked meanwhile.
set -euo pipefail
box=${ARCHIVE_BOX:-meiolol-archive}
archive=${ARCHIVE_DIR:-/mnt/wsl/archive/meiolol-raw}
work=${ARCHIVE_WORK:-$HOME/ml/archive-work}
lab=${LAB:-$HOME/ml/bin/meiolol-lab}
salt=${SALT:-$HOME/.config/meiolol/snap-salt}
# zstd unpacked from Ubuntu's package (no sudo here)
export PATH="$HOME/bin:$PATH"
awake=$HOME/ml/awake.d/archive-pull

log() { echo "$(date -u +%FT%TZ) $*"; }

mkdir -p "$work" "$HOME/ml/awake.d"
exec 9> "$work/.lock"
flock -n 9 || exit 0
if /mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null \
    | grep -qiE '^"(LeagueClient|League of Legends)\.exe"'; then
    log "League is open: next round"
    exit 0
fi
# Disk use for the box's health check (the box can't reach this PC): C: (it holds the WSL
# disk, Windows and games), the WSL disk, the archive partition ("-": not attached)
mount=$(dirname "$archive")
use() { df --output=pcent "$1" | tail -n 1 | tr -dc '0-9'; }
arch=-
mountpoint -q "$mount" && arch=$(use "$mount")
ssh -n "$box" disk "c$(use /mnt/c),wsl$(use /),arch$arch" || log "disk report failed"
[[ -d "$archive" ]] || { log "$archive missing: archive disk not attached"; exit 1; }
touch "$awake"

ssh -n "$box" forgotten > "$work/forgotten.txt"
touch "$work/forgotten-applied.txt"
comm -13 <(sort -u "$work/forgotten-applied.txt") <(sort -u "$work/forgotten.txt") \
    > "$work/forgotten-new.txt"
if [[ -s "$work/forgotten-new.txt" ]]; then
    nice -n 10 "$lab" archive-forget "$archive" "$work/forgotten-new.txt" "$salt"
    sort -u "$work/forgotten.txt" > "$work/forgotten-applied.txt"
fi

made=$(ssh -n "$box" export)
[[ -n "$made" ]] && log "box export: $made"
ssh -n "$box" list > "$work/list.txt"
while read -r name size; do
    touch "$awake"
    if ! grep -q "^$name	" "$archive/index.tsv" 2> /dev/null; then
        ssh -n "$box" send "$name" > "$work/$name.part"
        got=$(stat -c %s "$work/$name.part")
        [[ "$got" == "$size" ]] || { log "$name: got $got of $size bytes"; exit 1; }
        mv "$work/$name.part" "$work/$name"
        nice -n 10 "$lab" archive "$work/$name" "$archive" "$salt" "$work/forgotten.txt"
    fi
    ssh -n "$box" ack "$name"
    rm -f "$work/$name"
done < "$work/list.txt"

nice -n 10 "$lab" archive-age "$archive"
