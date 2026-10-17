#!/usr/bin/env bash
# On the gpu-box, hourly (systemd user timer meiolol-archive-pull): the raw archive
# (docs/data-safety.md "Raw archive"). Asks the box for a new export, fetches every
# export waiting there, archives it pseudonymised (meiolol-lab archive) and only then
# acks it, so the box drops raw documents only once they are archived here. Players
# newly forgotten on the box are erased from what is already archived; days past 24
# months lose their player ids. Skips a round while League is open (Jacob's rule for
# long jobs on this PC); the box keeps everything unacked meanwhile. Each round tells the
# box how it went (archive-serve.sh report), so its health check names the cause; an
# export whose archive fails stays unacked and the rest go on.
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
# Keepalives: an export of a long backlog prints nothing for half an hour, and the home
# router drops the idle connection, leaving the pull waiting for ever (14 Oct)
box_ssh() { ssh -n -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$box" "$@"; }
# Set once the round is under way: the reason the round failed, for the box's report
reporting=
why=
die() { why=$*; log "$*"; exit 1; }
finish() {
    local rc=$?
    [[ -n "$reporting" ]] || return 0
    if (( rc == 0 )); then box_ssh report ok || log "report failed"
    else box_ssh report fail "${why:-exit $rc}" || log "report failed"; fi
}

mkdir -p "$work" "$HOME/ml/awake.d"
exec 9> "$work/.lock"
flock -n 9 || exit 0
if /mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null \
    | grep -qiE '^"(LeagueClient|League of Legends)\.exe"'; then
    log "League is open: next round"
    exit 0
fi
reporting=1
trap finish EXIT
trap 'why=${why:-"line $LINENO: $BASH_COMMAND"}' ERR
# Disk use for the box's health check (the box can't reach this PC): C: (it holds the WSL
# disk, Windows and games), the WSL disk, the archive partition ("-": not attached)
mount=$(dirname "$archive")
use() { df --output=pcent "$1" | tail -n 1 | tr -dc '0-9'; }
arch=-
mountpoint -q "$mount" && arch=$(use "$mount")
box_ssh disk "c$(use /mnt/c),wsl$(use /),arch$arch" || log "disk report failed"
[[ -d "$archive" ]] || die "$archive missing: archive disk not attached"
touch "$awake"

box_ssh forgotten > "$work/forgotten.txt"
touch "$work/forgotten-applied.txt"
comm -13 <(sort -u "$work/forgotten-applied.txt") <(sort -u "$work/forgotten.txt") \
    > "$work/forgotten-new.txt"
if [[ -s "$work/forgotten-new.txt" ]]; then
    nice -n 10 "$lab" archive-forget "$archive" "$work/forgotten-new.txt" "$salt"
    sort -u "$work/forgotten.txt" > "$work/forgotten-applied.txt"
fi

made=$(box_ssh export)
[[ -n "$made" ]] && log "box export: $made"
box_ssh list > "$work/list.txt"
# Exports kept after a failed archive that the box no longer lists
for f in "$work"/raw-*.db; do
    [[ -e "$f" ]] || continue
    grep -q "^$(basename "$f") " "$work/list.txt" || rm -f "$f"
done
failed=
while read -r name size; do
    touch "$awake"
    # index.tsv names exports without .db (before 17 Oct this never matched, so an
    # export whose ack failed was fetched and archived again)
    if ! grep -q "^${name%.db}	" "$archive/index.tsv" 2> /dev/null; then
        # Kept from a round whose archive failed: not fetched again
        if [[ ! -f "$work/$name" || "$(stat -c %s "$work/$name")" != "$size" ]]; then
            box_ssh send "$name" > "$work/$name.part"
            got=$(stat -c %s "$work/$name.part")
            [[ "$got" == "$size" ]] || die "$name: got $got of $size bytes"
            mv "$work/$name.part" "$work/$name"
        fi
        if ! out=$(nice -n 10 "$lab" archive "$work/$name" "$archive" "$salt" "$work/forgotten.txt" \
            2>&1 < /dev/null); then
            [[ -n "$out" ]] && echo "$out"
            log "$name: archive failed, not acked: $(tail -n 1 <<< "$out")"
            failed=${failed:-"$name: $(tail -n 1 <<< "$out")"}
            continue
        fi
        echo "$out"
    fi
    # One export the box won't ack must not stop the rest: the box's health check
    # reports an export left unacked
    box_ssh ack "$name" || log "$name: ack failed"
    rm -f "$work/$name"
done < "$work/list.txt"

nice -n 10 "$lab" archive-age "$archive"
[[ -z "$failed" ]] || die "archive failed for $failed"
