#!/usr/bin/env bash
# On the box: the backups' side of their mirrors (docs/data-safety.md "Backups"). Forced
# command of the gpu-box's backup key in ~/.ssh/authorized_keys; the Mac runs it with
# arguments over its own key. deploy/backup-mirror.sh calls list, send FILE, acks MIRROR
# (lines "FILE SHA256" on stdin) and forgotten; deploy/backup-loop.sh runs prune after
# each backup; deploy/health.sh reads status.
#   list        one line per file: FILE SIZE SHA256 (sums cached by size and mtime)
#   prune       delete files a mirror acked at their current sum (mastery files: both
#               mirrors, as they keep them as history), except the newest state
#               snapshot, segment and mastery file (the next backup starts after them)
#   mastery-size MIRROR:BYTES:FILES   a mirror's mastery history, for the admin page
#               (backups/acks/MIRROR.mastery: time bytes files)
#   status      "mirror NAME LAST_ACK" per mirror, then "unacked FILES BYTES OLDEST_MTIME"
set -euo pipefail
cd "$HOME/ml/meiolol"
# shellcheck disable=SC1091 # host-specific, on the box only
if [[ -f host.env ]]; then set -a; . ./host.env; set +a; fi
dir=${MEIOLOL_BACKUPS:-$HOME/ml/meiolol/backups}
acks=$dir/acks sums=$dir/.sums
mkdir -p "$acks" "$sums"
read -r cmd arg _ <<< "${SSH_ORIGINAL_COMMAND:-$*}"

file_ok() { [[ "$1" =~ ^(state/state-[0-9]{4}-[0-9]{2}-[0-9]{2}|(segments|mastery)/[0-9]{6})\.db$ ]]; }
mirror_ok() { [[ "$1" =~ ^(mac|gpu-box)$ ]]; }

files() {
    shopt -s nullglob
    local f
    for f in "$dir"/state/state-*.db "$dir"/segments/[0-9]*.db "$dir"/mastery/[0-9]*.db; do
        echo "${f#"$dir"/}"
    done
}

# SHA-256 of FILE, recomputed only when its size or mtime changed (a scrub rewrites it)
sum() {
    local c=$sums/${1//\//_} key cs cm csha
    key=$(stat -c '%s %Y' "$dir/$1")
    if [[ -f "$c" ]] && read -r cs cm csha < "$c" && [[ "$cs $cm" == "$key" ]]; then
        echo "$csha"
        return
    fi
    csha=$(nice -n 10 sha256sum "$dir/$1" | cut -d' ' -f1)
    echo "$key $csha" > "$c"
    echo "$csha"
}

# Files acked by some mirror at their current sum; `acked prune`: mastery files only once
# both mirrors acked them (the Mac keeps 32 days, the gpu-box 24 months: neither alone
# may be the only copy of a file the box drops)
acked() {
    shopt -s nullglob
    local rel s need tsv=("$acks"/*.tsv)
    (( ${#tsv[@]} > 0 )) || return 0
    while read -r rel; do
        s=$(sum "$rel")
        need=1
        [[ ${1:-} == prune && $rel == mastery/* ]] && need=2
        if awk -F'\t' -v r="$rel" -v s="$s" -v need="$need" \
            '$1 == r && $2 == s && !(FILENAME in by) { by[FILENAME]; n++ } END { exit n < need }' \
            "${tsv[@]}"; then
            echo "$rel"
        fi
    done < <(files)
}

case "${cmd:-}" in
    list) while read -r rel; do echo "$rel $(stat -c %s "$dir/$rel") $(sum "$rel")"; done < <(files) ;;
    send) file_ok "$arg" || { echo "bad file name" >&2; exit 2; }; exec cat "$dir/$arg" ;;
    acks)
        mirror_ok "$arg" || { echo "bad mirror name" >&2; exit 2; }
        out=$acks/$arg.tsv now=$(date +%s) bad=0
        touch "$out"
        while read -r rel s; do
            file_ok "$rel" && [[ "$s" =~ ^[0-9a-f]{64}$ ]] || { bad=1; continue; }
            [[ -f "$dir/$rel" && "$(sum "$rel")" == "$s" ]] || { bad=1; continue; }
            awk -F'\t' -v r="$rel" '$1 != r' "$out" > "$out.tmp"
            printf '%s\t%s\t%s\n' "$rel" "$s" "$now" >> "$out.tmp"
            mv "$out.tmp" "$out"
        done
        (( bad == 0 )) || { echo "some acks did not match the box's files" >&2; exit 1; }
        ;;
    forgotten)
        tmp=$(mktemp)
        bin/meiolol forget --data data --export "$tmp" > /dev/null 2>&1
        cat "$tmp"
        rm -f "$tmp"
        ;;
    prune)
        newest_state=$(files | grep '^state/' | tail -n 1)
        newest_seg=$(files | grep '^segments/' | tail -n 1)
        newest_mastery=$(files | grep '^mastery/' | tail -n 1)
        n=0 bytes=0
        while read -r rel; do
            [[ "$rel" == "$newest_state" || "$rel" == "$newest_seg" || "$rel" == "$newest_mastery" ]] \
                && continue
            bytes=$(( bytes + $(stat -c %s "$dir/$rel") ))
            rm -f "$dir/$rel" "$sums/${rel//\//_}"
            n=$(( n + 1 ))
        done < <(acked prune)
        echo "$(date -u +%FT%TZ) backup prune: $n files mirrored, $(( bytes >> 20 )) MB freed"
        ;;
    mastery-size)
        [[ "$arg" =~ ^(mac|gpu-box):([0-9]+):([0-9]+)$ ]] || { echo "bad size" >&2; exit 2; }
        out=$acks/${BASH_REMATCH[1]}.mastery
        echo "$(date +%s) ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}" > "$out.tmp"
        mv "$out.tmp" "$out"
        ;;
    status)
        shopt -s nullglob
        for a in "$acks"/*.tsv; do
            echo "mirror $(basename "$a" .tsv) $(cut -f3 "$a" | sort -n | tail -n 1)"
        done
        n=0 bytes=0 oldest=0
        mapfile -t done_ < <(acked)
        while read -r rel; do
            printf '%s\n' "${done_[@]}" | grep -qxF "$rel" && continue
            m=$(stat -c %Y "$dir/$rel")
            n=$(( n + 1 )) bytes=$(( bytes + $(stat -c %s "$dir/$rel") ))
            (( oldest == 0 || m < oldest )) && oldest=$m
        done < <(files)
        echo "unacked $n $bytes $oldest"
        ;;
    *) echo "backup-serve: list|send FILE|acks MIRROR|forgotten|prune|status" >&2; exit 2 ;;
esac
