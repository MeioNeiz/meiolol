#!/usr/bin/env bash
# Runs on the box: prints one line per problem, exit 1 when there are any. Used by
# deploy/health-loop.sh (box, ntfy) and deploy/mac-watch.sh (Mac, wz notify). Thresholds
# in docs/data-safety.md. Keeps the crawler's last progress in data/health.state.
set -u
cd "$(dirname "$0")/.." || exit 1
# host.env (MEIOLOL_BACKUPS etc.) is the services' EnvironmentFile; mac-watch.sh runs this
# over ssh without it
[[ -f host.env ]] && { set -a; . ./host.env; set +a; }
BACKUPS=${MEIOLOL_BACKUPS:-/mnt/d/meiolol-backups}
STALL_H=${STALL_H:-2}
now=$(date +%s)
problems=()
# A systemd user service (deploy/systemd) on the cloud box, a tmux session on the gpu-box
running() {
    systemctl --user is-active -q "$1" 2>/dev/null || tmux has-session -t "$1" 2>/dev/null
}

if ! running meiolol-crawl; then
    if tail -n 5 data/crawl.log 2>/dev/null | grep -q 'KEY REJECTED'; then
        problems+=("crawler stopped: Riot rejected the key (exit 3)")
    else
        problems+=("crawler not running (meiolol-crawl)")
    fi
else
    # Report line every minute; its per-region "<n>m" counters are cumulative per process
    report=$(grep 'matches/day' data/crawl.log | tail -n 1)
    stamp=$(cut -c1-19 <<< "$report")
    age=$(( now - $(date -u -d "$stamp" +%s 2>/dev/null || echo 0) ))
    if (( age > 900 )); then
        problems+=("crawler silent: last report $(( age / 60 )) min ago")
    fi
    total=$(grep -oE ' [0-9]+m ' <<< "$report" | awk '{ s += $1 } END { print s + 0 }')
    state=${HEALTH_STATE:-data/health.state}
    read -r last_total last_progress 2> /dev/null < "$state" || last_progress=$now
    if [[ "${total:-0}" != "${last_total:-}" ]]; then last_progress=$now; fi
    echo "${total:-0} $last_progress" > "$state"
    if (( now - last_progress > STALL_H * 3600 )); then
        problems+=("no new matches for $(( (now - last_progress) / 3600 ))h")
    fi
fi

if ! running meiolol-web; then
    problems+=("site loop not running (meiolol-web)")
fi
uploaded=$(grep -oE '^[0-9TZ:-]+ uploaded' data/web.log 2>/dev/null | tail -n 1 | cut -d' ' -f1)
if [[ -z "$uploaded" ]] || (( now - $(date -d "$uploaded" +%s) > 26 * 3600 )); then
    problems+=("site upload stale: last ${uploaded:-never}")
fi

# /mnt/c holds the WSL disk image, so it, not /, is the real limit. D: (backups) was
# already 86% full with other things when backups started, hence 90
for limit in /mnt/c:80 /mnt/d:90 /:80; do
    mount=${limit%:*}
    use=$(df --output=pcent "$mount" 2>/dev/null | tail -n 1 | tr -dc '0-9')
    if (( ${use:-0} >= ${limit#*:} )); then problems+=("disk $mount at ${use}%"); fi
done

if ! running meiolol-backup; then
    problems+=("backup loop not running (meiolol-backup)")
fi
newest=$(ls -t "$BACKUPS"/state/state-*.db 2>/dev/null | head -n 1)
if [[ -z "$newest" ]] || (( now - $(stat -c %Y "$newest") > 26 * 3600 )); then
    problems+=("backup missing: newest ${newest:+$(basename "$newest")}${newest:-none}")
fi

# Backup mirrors (deploy/backup-serve.sh status): the box drops a backup only once a mirror
# acked it, so unmirrored ones are both unsafe and filling the box. Lines carry times
if [[ -x bin/backup-serve.sh ]] && mirrors=$(bin/backup-serve.sh status 2> /dev/null); then
    while read -r what name last; do
        [[ "$what" == mirror && "$last" =~ ^[0-9]+$ ]] || continue
        if (( now - last > 48 * 3600 )); then
            problems+=("backup mirror $name: last ack $(date -u -d "@$last" '+%F %H:%MZ')")
        fi
    done <<< "$mirrors"
    read -r _ files bytes oldest <<< "$(grep '^unacked ' <<< "$mirrors")"
    if [[ "$oldest" =~ ^[0-9]+$ ]] && (( ${files:-0} > 0 && now - oldest > 26 * 3600 )); then
        since=$(date -u -d "@$oldest" '+%F %H:%MZ')
        problems+=("backups not mirrored since $since ($files files, $(( ${bytes:-0} >> 20 )) MB)")
    fi
fi

# Raw archive: the gpu-box pulls and acks (deploy/archive-pull.sh); the box can't reach the
# PC, so a stale ack is how it sees the PC off or WSL down. Lines carry the last ack's time,
# not an age, so health-loop.sh doesn't push again every hour. Never exported: not live yet
ACK_H=${ACK_H:-12}
if archive=$(bin/meiolol raw-export --data data --status 2>&1); then
    since=$(awk '$1 == "since_ack_s" { print $2 }' <<< "$archive")
    oldest=$(awk '$1 == "oldest_unacked_s" { print $2 }' <<< "$archive")
    unacked=$(awk '$1 == "unacked" { print $2 }' <<< "$archive")
    # The disk valve (archive.valve) dropped raw the archive never got: data lost on
    # purpose to keep the box up. Keyed on the last drop's time, so each new drop pushes
    drops=$(awk '$1 == "drops_24h" { print $2 }' <<< "$archive")
    since_drop=$(awk '$1 == "since_drop_s" { print $2 }' <<< "$archive")
    if [[ "$drops" =~ ^[0-9]+$ ]] && (( drops > 0 )) && [[ "$since_drop" =~ ^[0-9]+$ ]]; then
        at=$(date -u -d "@$(( now - since_drop ))" '+%F %H:%MZ')
        problems+=("box disk low: raw not yet archived dropped, last at $at (data/raw-dropped.log)")
    fi
    if [[ "$since" =~ ^[0-9]+$ ]] && (( since > ACK_H * 3600 )); then
        last=$(date -u -d "@$(( now - since ))" '+%F %H:%MZ')
        problems+=("gpu-box: no archive ack since $last ($unacked exports waiting)")
    elif [[ "$since" == null && "$oldest" =~ ^[0-9]+$ ]] && (( oldest > ACK_H * 3600 )); then
        problems+=("gpu-box: first archive export never acked")
    elif [[ "$oldest" =~ ^[0-9]+$ ]] && (( oldest > ACK_H * 3600 )); then
        # Acks go on, but one export stays: its raw documents and everything newer stay
        # on the box (see archive-pull.log on the gpu-box)
        made=$(date -u -d "@$(( now - oldest ))" '+%F %H:%MZ')
        problems+=("gpu-box: archive export made $made still not acked")
    fi
else
    problems+=("archive status failed: $(head -n 1 <<< "$archive")")
fi
# Each archive pull's outcome (archive-serve.sh report): the cause, where the ack check
# above only sees that acks stopped. The line carries when it began, so it pushes once
if read -r _ since outcome msg 2> /dev/null < data/gpu-box.pull && [[ "$outcome" == fail ]]; then
    began=$(date -u -d "@$since" '+%F %H:%MZ' 2> /dev/null || echo "?")
    problems+=("gpu-box archive failing since $began: ${msg:-no message}")
fi
# The gpu-box's disks, reported by each archive pull (deploy/archive-pull.sh). C: holds
# the WSL disk next to Windows and games
if read -r _ use 2> /dev/null < data/gpu-box.disk; then
    IFS=, read -r c wsl arch <<< "$use"
    (( ${c#c} >= 85 )) && problems+=("gpu-box C: at ${c#c}% (holds the WSL disk)")
    (( ${wsl#wsl} >= 85 )) && problems+=("gpu-box WSL disk at ${wsl#wsl}%")
    if [[ "$arch" == arch- ]]; then problems+=("gpu-box: archive partition not attached")
    elif (( ${arch#arch} >= 85 )); then problems+=("gpu-box archive partition at ${arch#arch}%"); fi
fi
# While the gpu-box is away raw stays in raw.db, a day's worth (what it was sent over the
# last 24 h, archive-serve.sh) a day: under 3 days of it above the raw valve, a long
# outage ends with raw the archive never got dropped. Exports wait on the box only until
# the gpu-box has them, ~1 GB each, so their files are shown apart
free=$(df --output=avail -B1 data | tail -n 1 | tr -dc '0-9')
valve=$(grep -oE -- '--raw-valve-free-gb [0-9]+' crawl.args 2> /dev/null | tr -dc '0-9')
day=$(awk -v since=$(( now - 86400 )) '$1 >= since { n += $3 } END { print n + 0 }' \
    data/archive-sent.log 2> /dev/null || echo 0)
waiting=$(du -sb data/archive-out 2> /dev/null | cut -f1)
if (( day > 0 && ${free:-0} - ${valve:-0} * (1 << 30) < 3 * day )); then
    days=$(awk -v f="$free" -v v="${valve:-0}" -v d="$day" 'BEGIN { printf "%.1f", (f - v * 2^30) / d }')
    line="box disk: $(( free >> 30 )) GB free, $days days of raw ($(( day >> 30 )) GB a day)"
    line+=" above the ${valve:-0} GB raw valve should the gpu-box stop archiving"
    (( ${waiting:-0} >= 1 << 30 )) && line+=", $(( waiting >> 30 )) GB of it in exports waiting for the gpu-box"
    problems+=("$line")
fi

(( ${#problems[@]} == 0 )) && exit 0
printf '%s\n' "${problems[@]}"
exit 1
