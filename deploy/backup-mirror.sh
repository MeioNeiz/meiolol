#!/usr/bin/env bash
# A mirror of the box's backups (docs/data-safety.md "Backups"): the Mac (mac-watch.sh,
# daily), the gpu-box (systemd user timer meiolol-backup-mirror, hourly) and Megatron from
# the box itself (meiolol-megatron-mirror, hourly, outside C01's disk image). Fetches
# every file the box lists that is new here or changed there (a scrub), checks size and
# SHA-256, then acks it so the box may drop its copy. Then `meiolol backup --mirror`
# scrubs players the box has forgotten since and rotates state and mastery files (kept as
# history: the gpu-box and Megatron 730 days, the privacy policy's cap, the Mac 32). Never
# deletes a segment: the box keeps only its newest, so this copy may be the only one.
#   backup-mirror.sh NAME DIR MEIOLOL HOST [REMOTE]
# NAME: mac, gpu-box or megatron; REMOTE: the command on HOST before the verb (the Mac's
# full-shell key: ml/meiolol/bin/backup-serve.sh; the gpu-box's forced-command key: none).
# HOST local: REMOTE runs here, no ssh (the box mirroring onto its own NAS)
set -euo pipefail
name=$1 dir=$2 bin=$3 host=$4 remote=${5:-}
log() { echo "$(date -u +%FT%TZ) backup mirror: $*"; }
# Keepalives: the home router drops idle connections (archive-pull.sh, 14 Oct)
ssh_opts=(-o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o BatchMode=yes)
# shellcheck disable=SC2086 # remote is words
serve() {
    if [[ $host == local ]]; then $remote "$@" < /dev/null
    else ssh -n "${ssh_opts[@]}" "$host" $remote "$@"; fi
}
sha() {
    if command -v sha256sum > /dev/null; then sha256sum "$1" | cut -d' ' -f1
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Real PUUIDs in here: owner only
umask 077
mkdir -p "$dir/state" "$dir/segments" "$dir/mastery"
chmod 700 "$dir"
# No flock on macOS. A run killed without its trap (a WSL restart, 23 Oct) leaves the
# lock: stale once its owner is gone, the pid dead or from another boot; one without an
# owner file (being taken, or older than owner files) after 6 h. snapshot-gpu.sh takes
# the same lock
boot_id() { cat /proc/sys/kernel/random/boot_id 2> /dev/null || sysctl -n kern.boottime; }
lock=$dir/.lock
if ! mkdir "$lock" 2> /dev/null; then
    if read -r pid boot 2> /dev/null < "$lock/owner"; then
        [[ "$boot" != "$(boot_id)" ]] || ! kill -0 "$pid" 2> /dev/null || exit 0
    else
        [[ -n $(find "$lock" -maxdepth 0 -mmin +360) ]] || exit 0
    fi
    log "stale lock taken over"
fi
echo "$$ $(boot_id)" > "$lock/owner"
trap 'rm -rf "$lock"' EXIT

serve list > "$dir/.list"
manifest=$dir/.manifest
touch "$manifest"
fetched=0 bytes=0
while read -r rel size want; do
    [[ "$rel" =~ ^(state/state-[0-9]{4}-[0-9]{2}-[0-9]{2}|(segments|mastery)/[0-9]{6})\.db$ ]] \
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
    | if [[ $host == local ]]; then $remote acks "$name"
      else ssh "${ssh_opts[@]}" "$host" $remote acks "$name"; fi || log "acks failed"

serve forgotten > "$dir/forgotten.txt.tmp"
mv "$dir/forgotten.txt.tmp" "$dir/forgotten.txt"
if [[ $name == gpu-box || $name == megatron ]]; then echo 730 > "$dir/mastery-keep-days"; else echo 32 > "$dir/mastery-keep-days"; fi
"$bin" backup --mirror "$dir" --forgotten "$dir/forgotten.txt"
kb=$(du -sk "$dir/mastery" | cut -f1)
n=$(find "$dir/mastery" -name '[0-9]*.db' | wc -l | tr -d ' ')
serve mastery-size "$name:$(( kb * 1024 )):$n" || log "mastery-size failed"
touch "$dir/.mirrored"
log "$fetched files fetched ($(( bytes >> 20 )) MB), $(wc -l < "$dir/.list" | tr -d ' ') on the box"

# A failed snapshot build keeps its real-id copy a day for a resume (snapshot-gpu.sh), no
# longer, even when no build comes. Dated by its start, else the dir (older builds)
if [[ $name == gpu-box ]] && ! systemctl --user -q is-active meiolol-snapshot; then
    for d in "$HOME"/ml/snaps/.snap-*-real; do
        [[ -e "$d" ]] || continue
        f=$d/started
        [[ -f "$f" ]] || f=$d
        [[ -n $(find "$f" -maxdepth 0 -mmin +1440) ]] || continue
        rm -rf "$d"
        log "removed ${d##*/}, a failed snapshot build's real-id copy over a day old"
    done
fi
