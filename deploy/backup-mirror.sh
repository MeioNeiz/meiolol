#!/usr/bin/env bash
# A mirror of the box's backups (docs/data-safety.md "Backups"): the Mac (mac-watch.sh,
# daily) and the gpu-box (systemd user timer meiolol-backup-mirror, hourly). Fetches every
# file the box lists that is new here or changed there (a scrub), checks size and
# SHA-256, then acks it so the box may drop its copy. Then `meiolol backup --mirror`
# scrubs players the box has forgotten since and rotates state. Never deletes a segment:
# the box keeps only its newest, so this copy may be the only one.
#   backup-mirror.sh NAME DIR MEIOLOL HOST [REMOTE]
# NAME: mac or gpu-box; REMOTE: the command on HOST before the verb (the Mac's full-shell
# key: ml/meiolol/bin/backup-serve.sh; the gpu-box's forced-command key: none)
set -euo pipefail
name=$1 dir=$2 bin=$3 host=$4 remote=${5:-}
log() { echo "$(date -u +%FT%TZ) backup mirror: $*"; }
# Keepalives: the home router drops idle connections (archive-pull.sh, 14 Oct)
ssh_opts=(-o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o BatchMode=yes)
# shellcheck disable=SC2086 # remote is words
serve() { ssh -n "${ssh_opts[@]}" "$host" $remote "$@"; }
sha() {
    if command -v sha256sum > /dev/null; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Real PUUIDs in here: owner only
umask 077
mkdir -p "$dir/state" "$dir/segments"
chmod 700 "$dir"
# No flock on macOS; a lock left by a killed run expires after 6 h
lock=$dir/.lock
if ! mkdir "$lock" 2> /dev/null; then
    [[ -n $(find "$lock" -maxdepth 0 -mmin +360) ]] || exit 0
    touch "$lock"
fi
trap 'rmdir "$lock" 2> /dev/null || true' EXIT

serve list > "$dir/.list"
manifest=$dir/.manifest
touch "$manifest"
fetched=0 bytes=0
while read -r rel size want; do
    [[ "$rel" =~ ^(state/state-[0-9]{4}-[0-9]{2}-[0-9]{2}|segments/[0-9]{6})\.db$ ]] \
        || { log "box listed a bad name: $rel"; exit 1; }
    # The box's sum at fetch time: a local scrub or rotation since does not refetch
    grep -qxF "$rel $want" "$manifest" && continue
    serve send "$rel" > "$dir/$rel.part"
    got=$(wc -c < "$dir/$rel.part" | tr -d ' ')
    [[ "$got" == "$size" ]] || { log "$rel: got $got of $size bytes"; rm -f "$dir/$rel.part"; exit 1; }
    [[ "$(sha "$dir/$rel.part")" == "$want" ]] || { log "$rel: sum differs"; rm -f "$dir/$rel.part"; exit 1; }
    mv "$dir/$rel.part" "$dir/$rel"
    { grep -v "^$rel " "$manifest" || true; echo "$rel $want"; } > "$manifest.tmp"
    mv "$manifest.tmp" "$manifest"
    fetched=$(( fetched + 1 )) bytes=$(( bytes + size ))
done < "$dir/.list"

# Ack everything listed that this mirror holds, in one connection
# shellcheck disable=SC2086 # remote is words
grep -xFf <(awk '{ print $1 " " $3 }' "$dir/.list") "$manifest" \
    | ssh "${ssh_opts[@]}" "$host" $remote acks "$name" || log "acks failed"

serve forgotten > "$dir/forgotten.txt.tmp"
mv "$dir/forgotten.txt.tmp" "$dir/forgotten.txt"
"$bin" backup --mirror "$dir" --forgotten "$dir/forgotten.txt"
touch "$dir/.mirrored"
log "$fetched files fetched ($(( bytes >> 20 )) MB), $(wc -l < "$dir/.list" | tr -d ' ') on the box"
