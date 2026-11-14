#!/usr/bin/env bash
# Runs on the box: prints one line per problem, exit 1 when there are any. Used by
# deploy/health-loop.sh (box, ntfy), deploy/mac-watch.sh (Mac, wz notify), the admin page
# and `deploy/box.sh status`. Thresholds and where it reaches Jacob: docs/health.md.
# Keeps the crawler's last progress in data/health.state.
set -u
if [[ $(uname) != Linux ]]; then
    echo "health.sh runs on the box (GNU date, stat, df, its units): deploy/box.sh health check" >&2
    exit 2
fi
cd "$(dirname "$0")/.." || exit 1
# host.env (MEIOLOL_BACKUPS etc.) is the services' EnvironmentFile; mac-watch.sh runs this
# over ssh without it
[[ -f host.env ]] && { set -a; . ./host.env; set +a; }
BACKUPS=${MEIOLOL_BACKUPS:-$HOME/ml/meiolol/backups}
STALL_H=${STALL_H:-2}
# Key use alert: any region under KEYUSE_PCT of the key over the last KEYUSE_MIN min
KEYUSE_PCT=${KEYUSE_PCT:-90}
KEYUSE_MIN=${KEYUSE_MIN:-30}
now=$(date +%s)
problems=()
# A systemd user service (deploy/systemd)
running() { systemctl --user is-active -q "$1" 2>/dev/null; }
# A condition's first sighting while it lasts (data/health.episodes, "NAME UNIX"), so its
# line stays the same and health-loop.sh pushes it once. `episode NAME 1` prints its start;
# `episode NAME 0` forgets it and fails
EPISODES=${HEALTH_EPISODES:-data/health.episodes}
episode() {
    local start
    start=$(awk -v n="$1" '$1 == n { print $2 }' "$EPISODES" 2> /dev/null)
    if (( $2 )); then
        [[ -n "$start" ]] || { start=$now; echo "$1 $now" >> "$EPISODES"; }
        date -u -d "@$start" '+%F %H:%MZ'
        return 0
    fi
    if [[ -n "$start" ]]; then
        grep -v "^$1 " "$EPISODES" > "$EPISODES.new"
        mv "$EPISODES.new" "$EPISODES"
    fi
    return 1
}

if ! running meiolol-crawl; then
    if tail -n 5 data/crawl.log 2>/dev/null | grep -q 'KEY REJECTED'; then
        problems+=("crawler stopped: Riot rejected the key (exit 3)")
    else
        problems+=("crawler not running (meiolol-crawl)")
    fi
    episode keyuse 0
    episode stall 0
else
    # Report line every minute; its per-region "<n>m" and "<n>req" counters are cumulative
    # per process
    reports=$(grep 'matches/day' data/crawl.log | tail -n $(( KEYUSE_MIN + 5 )))
    report=$(tail -n 1 <<< "$reports")
    stamp=$(cut -c1-19 <<< "$report")
    age=$(( now - $(date -u -d "$stamp" +%s 2>/dev/null || echo 0) ))
    if (( age > 900 )); then
        problems+=("crawler silent: last report $(( age / 60 )) min ago")
    fi
    # The complete form after a packer or sealer error, until its restart (riot/complete.zig)
    if grep -q '| complete off' <<< "$report"; then
        problems+=("complete form off: day files not written (crawl.log 'complete:' lines)")
    fi
    restarts=$(grep -oE '[0-9]+ restarts/h' <<< "$report" | cut -d' ' -f1)
    (( ${restarts:-0} >= 3 )) && problems+=("complete form restarted $restarts times in the last hour (crawl.log 'complete:' lines)")
    dropped=$(grep -oE '[0-9]+ dropped' <<< "$report" | cut -d' ' -f1)
    (( ${dropped:-0} > 0 )) && problems+=("complete form dropped $dropped documents: its queue was full or a spool write failed")
    quarantined=$(find data/complete/spool/quarantine -type f 2> /dev/null | wc -l | tr -d ' ')
    (( quarantined > 0 )) && problems+=("complete form: $quarantined spool segments quarantined after unclean runs (docs/health.md \"Complete form quarantine\")")
    damaged=$(find data/complete -maxdepth 1 -name '*.cfd.damaged-*' 2> /dev/null | wc -l | tr -d ' ')
    (( damaged > 0 )) && problems+=("complete form: $damaged day files set aside with a damaged frame (docs/health.md \"Complete form damaged file\")")
    # Mastery blocks seal every minute or so: an open day file standing still means none do
    part=$(ls -t data/complete/*.cfd.part 2> /dev/null | head -n 1)
    if [[ -n "$part" ]] && (( now - $(stat -c %Y "$part") > 1800 )); then
        problems+=("complete form: no day file written for $(( (now - $(stat -c %Y "$part")) / 60 )) min")
    fi
    total=$(grep -oE ' [0-9]+m ' <<< "$report" | awk '{ s += $1 } END { print s + 0 }')
    state=${HEALTH_STATE:-data/health.state}
    read -r last_total last_progress 2> /dev/null < "$state" || last_progress=$now
    if [[ "${total:-0}" != "${last_total:-}" ]]; then last_progress=$now; fi
    echo "${total:-0} $last_progress" > "$state"
    if (( now - last_progress > STALL_H * 3600 )); then
        problems+=("no new matches for $(( (now - last_progress) / 3600 ))h")
    fi
    # Key use: each region's requests over the window's report lines of this process (a
    # restart resets the counters) against the key's 100 per 120 s. Not the "time %" lines:
    # commits and rests there overlap the limiter's catch-up, so they show 10-15% lost in
    # hours that used 97-100% of the key. 4-10 Nov, 30 min under 90%: 1-6 dips a day
    read -r secs worst <<< "$(awk -v since="$(date -u -d "@$(( now - KEYUSE_MIN * 60 ))" '+%F %T')" '
        {
            n++; t[n] = $1 " " $2; d[n] = $1
            s[n] = substr($2, 1, 2) * 3600 + substr($2, 4, 2) * 60 + substr($2, 7, 2)
            for (i = 3; i < NF; i++) if ($i ~ /^(americas|asia|europe|sea)$/)
                for (j = i + 1; j <= i + 6 && j <= NF; j++)
                    if ($j ~ /^[0-9]+req$/) { r[n, $i] = $j + 0; g[$i] = 1; break }
        }
        END {
            k = n
            while (k > 1 && t[k - 1] >= since) {
                back = 0
                for (x in g) if (r[k - 1, x] > r[k, x]) back = 1
                if (back) break
                k--
            }
            secs = s[n] - s[k] + (d[n] != d[k] ? 86400 : 0)
            if (secs <= 0) exit
            worst = 1000
            for (x in g) { u = (r[n, x] - r[k, x]) * 120 / secs; if (u < worst) worst = u }
            printf "%d %d\n", secs, worst
        }' <<< "$reports")"
    dip=0
    (( ${secs:-0} >= KEYUSE_MIN * 48 && ${worst:-100} < KEYUSE_PCT )) && dip=1
    if began=$(episode keyuse $dip); then
        problems+=("crawler key use under ${KEYUSE_PCT}% since $began (crawl.log time % lines say where the minutes go)")
    fi
    # The writer's stall reports (riot/stall.zig): a batch over 30 s, a checkpoint round
    # over 60 s, or no checkpoint for 5 min
    stalls=$(grep -E 'stall: |no checkpoint for' data/crawl.log | tail -n 20 \
        | awk -v since="$(date -u -d "@$(( now - 900 ))" '+%F %T')" '$1 " " $2 >= since' | wc -l)
    if began=$(episode stall $(( stalls > 0 ))); then
        problems+=("crawler writer stalling since $began (crawl.log 'stall:' and 'no checkpoint for' lines)")
    fi
fi

# deploy/crawl-revive.sh's last outcome: a restart for a day, or a crawler it gave up on
read -r at what why < <(tail -n 1 data/crawl-revive.log 2> /dev/null)
if [[ "${what:-}" == restarted: ]] && (( now - $(date -d "$at" +%s) < 86400 )); then
    problems+=("crawler auto-restarted $at: ${why:0:200} (data/crawl-revive.log)")
elif [[ "$(cat data/crawl-revive.held 2> /dev/null)" == failed ]]; then
    problems+=("crawler auto restart didn't help, not trying again: needs a look (data/crawl-revive.log)")
fi

# The crawler's checkpointer keeps WALs to ~64 MB; a reader holding a WAL read mark (-shm
# bytes 124-127; /proc/locks) stops it restarting the WAL, so it grows (13 Nov: a 43 min
# sqlite3 box job, 6.6 GB). Names those holders, the crawler's own aside
wal_readers() {
    local inode pid unit out=
    inode=$(stat -c %i "$1" 2> /dev/null) || return
    for pid in $(awk -v i="$inode" '$2 != "->" && $4 == "READ" && split($6, d, ":") == 3 \
        && d[3] == i && $7 >= 124 && $7 <= 127 { print $5 }' /proc/locks | sort -un); do
        unit=$(sed -n 's#.*/\([^/]*\.service\)$#\1#p' "/proc/$pid/cgroup" 2> /dev/null)
        [[ "$unit" == meiolol-crawl.service ]] && continue
        out+="${out:+; }${unit:+$unit: }$(tr '\0' ' ' < "/proc/$pid/cmdline" 2> /dev/null | cut -c1-80 | sed "s/ *$//")"
        out+=" (pid $pid, up $(( $(ps -o etimes= -p "$pid" 2> /dev/null || echo 0) / 60 )) min)"
    done
    echo "$out"
}
for wal in data/*.db-wal; do
    [[ -f "$wal" ]] || continue
    size=$(stat -c %s "$wal")
    (( size > 4 << 30 )) || continue
    readers=$(wal_readers "${wal%-wal}-shm")
    problems+=("${wal#data/} at $(( size >> 30 )) GB: WAL not checkpointed, ${readers:+held by $readers}${readers:-no reader besides the crawler (crawl.log checkpointer and stall lines)}")
done

if ! running meiolol-web; then
    problems+=("site loop not running (meiolol-web)")
fi
uploaded=$(grep -oE '^[0-9TZ:-]+ uploaded' data/web.log 2>/dev/null | tail -n 1 | cut -d' ' -f1)
if [[ -z "$uploaded" ]] || (( now - $(date -d "$uploaded" +%s) > 26 * 3600 )); then
    problems+=("site upload stale: last ${uploaded:-never}")
fi
# Each web loop step's latest outcome (web-loop.sh step_status: step, unix time, ok|failed,
# detail). A failed refit leaves no Meio until the next binary; a failed daily job keeps
# yesterday's files. The line carries the failure's time, so it pushes once
while IFS=$'\t' read -r step at status detail; do
    [[ "$status" == failed && "$at" =~ ^[0-9]+$ ]] || continue
    problems+=("site loop: $step failed $(date -u -d "@$at" '+%F %H:%MZ'): ${detail:0:200}")
done < <(cat data/web-steps.tsv 2> /dev/null)
# The public site end to end, from here through Cloudflare's tunnel: nginx, the renderer
# (a page and a lock answer) and the Your games API. X-Meiolol-Render STALE or ANY-*:
# nginx served its last copy because the renderer did not answer. MEIOLOL_SITE (host.env)
# empty: no public site to check
site=${MEIOLOL_SITE-https://meio.lol}
if [[ -n "$site" ]]; then
    for path in "" data/lock/meio/darius/top/plat/none.bin api/health; do
        url=$site/$path
        head=$(curl -s -o /dev/null -D - -w '%{http_code}' -m 20 -A meiolol-health "$url")
        code=${head##*$'\n'}
        render=$(grep -i '^x-meiolol-render:' <<< "$head" | tr -d '\r' | cut -d' ' -f2)
        if [[ "$code" != 200 ]]; then
            problems+=("site: $url answers ${code/#000/nothing}")
        elif [[ "$render" == STALE || "$render" == ANY-* ]]; then
            problems+=("site: $url served from nginx's copy ($render): the renderer is not answering (data/render.log)")
        fi
    done
fi

# Without C01's data disk cache file (deploy/c01): 30 GB of its 60 GB /, and it never grows
read -r size used <<< "$(df -B1 --output=size,used / 2>/dev/null | tail -n 1)"
fixed=$(stat -c %s /var/lib/meiolol/cache.img 2>/dev/null || echo 0)
use=$(( ${size:-0} > fixed ? (${used:-0} - fixed) * 100 / (size - fixed) : 0 ))
(( use >= 80 )) && problems+=("disk / at ${use}% (not counting the disk cache file)")
mnt=$(df --output=target data 2>/dev/null | tail -n 1)
use=$(df --output=pcent data 2>/dev/null | tail -n 1 | tr -dc '0-9')
[[ "$mnt" != / ]] && (( ${use:-0} >= 80 )) && problems+=("disk $mnt at ${use}%")
# C01's shares and data disk (host.env; deploy/c01). With the data disk itself down this
# script can't run: mac-watch.sh reports that (ssh's exit 127)
for m in ${MEIOLOL_MOUNTS:-}; do
    mountpoint -q "$m" || problems+=("$m not mounted: meiolol-disk.service retries (its journal says why)")
done

# The newest deploy's outcome (data/deploys.tsv, from the Mac's on-push.sh): after a
# failed one the site lags main until a push deploys. The line carries its time
last=$(awk -F'\t' '$3 == "deploy" && $4 != "start"' data/deploys.tsv 2> /dev/null | tail -n 1)
IFS=$'\t' read -r at sha _ status detail <<< "$last"
if [[ "$status" == failed && "$at" =~ ^[0-9]+$ ]]; then
    problems+=("deploy ${sha:0:7} failed $(date -u -d "@$at" '+%F %H:%MZ'): ${detail:0:200}")
fi
# A push that never reaches the box: the Mac's on-push.sh deploys and, asleep, queues (8
# Nov: 8d32828e sat ~2 days). Every head it handles leaves a deploys.tsv row, skipped ones
# too, so origin main's head missing there for BEHIND_H is that. MEIOLOL_ORIGIN (host.env)
# empty: not checked; GitHub not answering: left as it was
origin=${MEIOLOL_ORIGIN-https://github.com/MeioNeiz/meiolol.git}
if [[ -n "$origin" ]] \
    && head=$(timeout 20 git ls-remote "$origin" refs/heads/main 2> /dev/null | cut -f1) \
    && [[ "$head" =~ ^[0-9a-f]{40}$ ]]; then
    behind=1
    cut -f2 data/deploys.tsv 2> /dev/null | grep -qxF "$head" && behind=0
    if began=$(episode behind $behind); then
        since=$(awk '$1 == "behind" { print $2 }' "$EPISODES")
        (( now - since >= ${BEHIND_H:-2} * 3600 )) \
            && problems+=("box behind origin main since $began: ${head:0:7} never reached it (the Mac's on-push.sh: asleep? .git/meiolol-deploy.log)")
    fi
fi

if ! running meiolol-backup; then
    problems+=("backup loop not running (meiolol-backup)")
fi
# Every forget and backup brings sealed day files up to the forgotten list
# (riot/complete_scrub.zig); the next run retries what failed. Last outcome: "<unix> ok",
# "<unix> failed N" or "<unix> error NAME"
read -r _ scrub detail < data/complete-scrub.status 2> /dev/null || scrub=
if [[ -n "$scrub" && "$scrub" != ok ]]; then
    problems+=("complete form scrub $scrub ${detail:-}: day files not brought up to the forgotten list")
fi
# Its cause: the line before backup-mirror.sh's FAILED line (that names the step)
if systemctl --user -q is-failed meiolol-megatron-mirror.service 2> /dev/null; then
    cause=$(grep -B1 ' backup mirror: FAILED' data/backup-mirror.log 2> /dev/null | tail -n 2 \
        | tr '\n' ' ')
    problems+=("Megatron mirror failed: ${cause:0:300}${cause:+ }(data/backup-mirror.log)")
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
    # With nothing exported (the crawler stored nothing) acks stop too: then the pulls'
    # reports (data/gpu-box.pull, first field its time) say whether the gpu-box is there
    read -r pulled _ < data/gpu-box.pull 2> /dev/null || pulled=0
    [[ "$pulled" =~ ^[0-9]+$ ]] || pulled=0
    if [[ "$since" =~ ^[0-9]+$ ]] && (( since > ACK_H * 3600 )) \
        && { (( ${unacked:-0} > 0 )) || (( now - pulled > ACK_H * 3600 )); }; then
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
# The gpu-box's disks and logins backup, reported by each archive pull
# (deploy/archive-pull.sh). C: holds the WSL disk next to Windows and games
if read -r _ use 2> /dev/null < data/gpu-box.disk; then
    IFS=, read -r c wsl arch acct <<< "$use"
    (( ${c#c} >= 85 )) && problems+=("gpu-box C: at ${c#c}% (holds the WSL disk)")
    (( ${wsl#wsl} >= 85 )) && problems+=("gpu-box WSL disk at ${wsl#wsl}%")
    if [[ "$arch" == arch- ]]; then problems+=("gpu-box: archive partition not attached")
    elif (( ${arch#arch} >= 85 )); then problems+=("gpu-box archive partition at ${arch#arch}%"); fi
    case $acct in
        acctfail) problems+=("gpu-box logins backup failing (~/ml/accounts-pull.log)") ;;
        acctoff) problems+=("gpu-box logins backup timer not running (meiolol-accounts-pull)") ;;
        acctold) problems+=("gpu-box logins backup: newest copy over 3 days old") ;;
    esac
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
# Days to a full data disk: its growth over the newest week without the WALs and day files
# (data/admin-history.tsv, each web round; only rows that measured day files), plus their
# newest whole day at its real size, as the admin page's "Disk full around"
read -r left rate files < <(awk -F'\t' -v since=$(( now - 7 * 86400 )) -v free="${free:-0}" '
    NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; if (!("complete_day" in c)) exit; next }
    $1 >= since && $(c["complete"]) != "" && $(c["disk_used"]) != "" {
        v = $(c["disk_used"]) - $(c["complete"]) - $(c["meiolol_wal"]) - $(c["timeline_wal"]) - $(c["raw_wal"])
        if (!n++) { t0 = $1; v0 = v }
        t1 = $1; v1 = v; d = $(c["complete_day"])
    }
    END {
        if (n < 2 || t1 - t0 < 86400 / 5 || d == "") exit
        r = (v1 - v0) / (t1 - t0) * 86400 + d
        if (r > 0) printf "%d %.1f %.1f\n", free / r, r / 1e9, d / 1e9
    }' data/admin-history.tsv 2> /dev/null)
if [[ -n "${left:-}" ]] && (( left < 30 )); then
    problems+=("box data disk full in ~$left days: $rate GB a day, day files $files GB of it (docs/data-safety.md Disk)")
fi

(( ${#problems[@]} == 0 )) && exit 0
printf '%s\n' "${problems[@]}"
exit 1
