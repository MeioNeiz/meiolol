#!/usr/bin/env bash
# On the gpu-box, hourly (systemd user timer meiolol-archive-pull): the raw archive
# (docs/data-safety.md "Raw archive"). Asks the box for exports of at most 2 hours of
# fetches each until it has caught up, and for each: fetches it to the archive disk,
# tells the box its sha256 (the box then deletes its file), archives it pseudonymised
# (meiolol-lab archive) and only then acks it, so the box drops raw documents only once
# they are archived here. Players newly forgotten on the box are erased from what is
# already archived; days past 24 months lose their player ids. Skips a round while
# League is open (Jacob's rule for long jobs on this PC), and stops one between exports
# when it opens; the box keeps everything unacked meanwhile. Each round tells the box
# how it went (archive-serve.sh report), so its health check names the cause. An export
# whose archive fails stays here unacked, and no new export is asked for until it goes.
set -euo pipefail
box=${ARCHIVE_BOX:-meiolol-archive}
archive=${ARCHIVE_DIR:-/mnt/wsl/archive/meiolol-raw}
work=${ARCHIVE_WORK:-$HOME/ml/archive-work}
lab=${LAB:-$HOME/ml/bin/meiolol-lab}
salt=${SALT:-$HOME/.config/meiolol/snap-salt}
# zstd unpacked from Ubuntu's package (no sudo here)
export PATH="$HOME/bin:$PATH"
awake=$HOME/ml/awake.d/archive-pull
# Received exports wait here, on the archive disk (not C:), until archived and acked: the
# box has deleted its copy
incoming=$(dirname "$archive")/incoming

log() { echo "$(date -u +%FT%TZ) $*"; }
# Keepalives: an export of a long backlog prints nothing for half an hour, and the home
# router drops the idle connection, leaving the pull waiting for ever (14 Oct)
box_ssh() { ssh -n -o ServerAliveInterval=30 -o ServerAliveCountMax=10 "$box" "$@"; }
# Each ssh can die on the home link (sshd: "message authentication code incorrect", 14-17
# Oct); every box command is safe to repeat
retry() {
    local i
    for i in 1 2 3; do
        "$@" && return 0
        # stderr: callers capture stdout
        (( i < 3 )) && { log "retrying: $*" >&2; sleep 20; }
    done
    return 1
}
league() {
    /mnt/c/Windows/System32/tasklist.exe /NH /FO CSV 2> /dev/null \
        | grep -qiE '^"(LeagueClient|League of Legends)\.exe"'
}
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
if league; then
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

mkdir -p "$incoming"
# Legacy: exports fetched before 18 Oct, whose box copy stays until the ack
rm -f "$work"/raw-*.db "$work"/raw-*.db.part

archived() { grep -q "^${1%.db}	" "$archive/index.tsv" 2> /dev/null; }
fetch() {
    local name=$1 size=$2 got sum
    box_ssh send "$name" > "$incoming/$name.part" || return 1
    got=$(stat -c %s "$incoming/$name.part")
    [[ "$got" == "$size" ]] || { log "$name: got $got of $size bytes"; return 1; }
    sum=$(sha256sum < "$incoming/$name.part")
    echo "${sum%% *}" > "$incoming/$name.sha256"
    # On disk before the box deletes its copy
    sync "$incoming/$name.part" "$incoming/$name.sha256"
    mv "$incoming/$name.part" "$incoming/$name"
    sync "$incoming"
}
# An export here not yet archived: no new one until it is
pending() {
    local f
    for f in "$incoming"/raw-*.db; do
        [[ -e "$f" ]] && ! archived "$(basename "$f")" && return 0
    done
    return 1
}
# One round per export: export (when asked), list, then every unacked export in order
failed=
while :; do
    made=""
    held=""
    if [[ -n "$failed" ]]; then :
    elif pending; then held=1
    else
        made=$(retry box_ssh export) || die "export failed"
        [[ -n "$made" ]] && log "box export: $made"
    fi
    retry box_ssh list > "$work/list.txt" || die "list failed"
    while read -r name size; do
        touch "$awake"
        if ! archived "$name"; then
            if [[ ! -f "$incoming/$name" ]]; then
                case "$size" in
                    received) die "$name: the box deleted it as received, but it is not in $incoming" ;;
                    missing) continue ;;
                esac
                retry fetch "$name" "$size" || die "$name: fetch failed"
            fi
            # The box keeps its file until it hears the sha256 (again after a lost answer)
            if [[ "$size" != received ]]; then
                retry box_ssh got "$name" "$(cat "$incoming/$name.sha256")" || die "$name: got failed"
            fi
            if ! out=$(nice -n 10 "$lab" archive "$incoming/$name" "$archive" "$salt" "$work/forgotten.txt" \
                2>&1 < /dev/null); then
                [[ -n "$out" ]] && echo "$out"
                log "$name: archive failed, not acked: $(tail -n 1 <<< "$out")"
                failed=${failed:-"$name: $(tail -n 1 <<< "$out")"}
                continue
            fi
            echo "$out"
        fi
        # A failed ack is retried next round: the export stays listed, and is archived
        retry box_ssh ack "$name" || { log "$name: ack failed"; continue; }
        rm -f "$incoming/$name" "$incoming/$name.sha256"
    done < "$work/list.txt"
    # On while the export was capped, or held back by one this pass has now archived
    [[ -z "$failed" && ( "$(cut -f6 <<< "$made")" == 1 || -n "$held" ) ]] || break
    if league; then
        log "League is open: rest of the backlog next round"
        break
    fi
done
# Archived and acked in an earlier round whose ack answer was lost
for f in "$incoming"/raw-*.db; do
    [[ -e "$f" ]] || continue
    n=$(basename "$f")
    archived "$n" && ! grep -q "^$n " "$work/list.txt" && rm -f "$f" "$f.sha256"
done

nice -n 10 "$lab" archive-age "$archive"
[[ -z "$failed" ]] || die "archive failed for $failed"
