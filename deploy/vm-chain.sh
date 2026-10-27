#!/usr/bin/env bash
# VM3 on C01 without a session in the loop (docs/plan/vm.md): waits for the first copy
# (meiolol-copy-* units, "done" last in ~/copy-*.log), catches the live copy up and
# checks it (PRAGMA quick_check, again on a failure), then benchmarks against the box's
# own logs: core build, a full views write, renderer load, render latency at 8 in flight,
# deploy/bench-crawl.sh. Needs the x86 binary there first (box.sh sync, crawler off).
# Each finished stage leaves STATE/<stage>, so a rerun goes on from where it stopped.
# Results and the verdict in STATE/results.md; the last line is "VERDICT: ...".
#   systemd-run --user --unit meiolol-vm-chain bash ~/vm-chain/deploy/vm-chain.sh
#   vm-chain.sh final    VM6's last pass, the box's writers stopped: exit 0 when copied
set -uo pipefail

STATE=$HOME/vm-chain
D=$HOME/ml/meiolol
BENCH=/srv/meiolol/bench
out=$STATE/results.md
mkdir -p "$STATE"
cd "$D" || exit 1
log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$STATE/chain.log"; }
note() { echo "$*" >> "$out"; }
done_stage() { touch "$STATE/$1"; log "stage $1 done"; }
# Median of the numbers on stdin
median() { sort -n | awk '{a[NR] = $1} END {print NR ? a[int((NR + 1) / 2)] : ""}'; }

wait_copy() {
    local f
    log "waiting for the first copy"
    for f in meiolol timeline raw rest; do
        until [[ $(tail -n 1 "$HOME/copy-$f.log" 2> /dev/null) == "done" ]]; do
            sleep 30
        done
    done
    done_stage copy
}

# Deltas since the first copy, the three databases and the rest at once. The box writes
# them throughout, so the db and its -wal can disagree: quick_check tells, and a failed
# check gets another pass
catch_up() {
    local pids=() p rc=0 db
    rm -f data/*.db-shm
    for db in meiolol timeline raw; do
        rsync -a --inplace --ignore-missing-args "meiolol-box:data/$db.db" \
            "meiolol-box:data/$db.db-wal" data/ >> "$STATE/catch-up.log" 2>&1 &
        pids+=($!)
    done
    rsync -a --inplace --exclude=/bin/ --exclude='*.db-shm' --exclude=/data/meiolol.db \
        --exclude=/data/timeline.db --exclude=/data/raw.db --exclude='/data/*.db-wal' \
        meiolol-box:./ ./ >> "$STATE/catch-up.log" 2>&1 &
    pids+=($!)
    for p in "${pids[@]}"; do wait "$p" || rc=$?; done
    return $rc
}

check() {
    local try db r bad
    for try in 1 2 3 4; do
        log "catch-up pass $try"
        catch_up || { log "catch-up failed: $STATE/catch-up.log"; continue; }
        bad=''
        for db in meiolol timeline raw; do
            r=$(sqlite3 "data/$db.db" 'PRAGMA quick_check' 2>&1 | head -n 3)
            log "quick_check $db.db: $r"
            [[ $r == ok ]] || bad+=" $db"
        done
        if [[ -z $bad ]]; then
            note "- copy: quick_check ok on pass $try"
            done_stage check
            return 0
        fi
    done
    note "- copy: quick_check still failing after 4 passes:$bad"
    note "VERDICT: blocked, copy inconsistent ($STATE/chain.log)"
    exit 1
}

# The box's figures from its own logs (the rrsync key reads ~/ml/meiolol)
box_logs() {
    mkdir -p "$STATE/box"
    rsync -a meiolol-box:data/web.log meiolol-box:data/render.log \
        meiolol-box:data/crawl.log "$STATE/box/"
}

site_args() {
    args=(--contact "$(cat contact)" --origin https://meio.lol)
    [[ -s riot.txt ]] && args+=(--riot-txt "$(< riot.txt)")
}

# 1.1x the box or under is ok. Up to 2x (or 5 s) is slower but no block (Jacob 27 Oct:
# C01 is tuned after the move, a local M.2 planned); beyond that, or a failed step (no
# figure), blocks
compare() {
    local name=$1 c01=$2 box=$3
    if [[ -z $c01 ]]; then
        note "| $name | failed | ${box:-?} | FAILED |"
        blocking+=" $name"
    elif [[ -z $box ]]; then
        note "| $name | $c01 | ? | no figure |"
    elif (( c01 * 10 <= box * 11 )); then
        note "| $name | $c01 | $box | ok |"
    elif (( c01 <= box * 2 || c01 - box <= 5 )); then
        note "| $name | $c01 | $box | slower, accepted |"
        slower+=" $name"
    else
        note "| $name | $c01 | $box | over 2x |"
        blocking+=" $name"
    fi
}

bench() {
    local args t core views reload lines box_core box_views box_reload slower='' blocking=''
    box_logs
    site_args
    if [[ ! -x bin/meiolol ]]; then
        note "VERDICT: blocked, no bin/meiolol (box.sh sync)"
        exit 1
    fi

    log "core build"
    rm -rf data/site.bench
    t=$SECONDS
    if bin/meiolol site "${args[@]}" --out data/site.bench --static core \
        > "$STATE/core.log" 2>&1; then
        core=$((SECONDS - t))
    else
        core=''
        log "core build failed: $STATE/core.log"
    fi
    rm -rf data/site.bench

    log "views write, every part fresh"
    t=$SECONDS
    if nice -n 10 ionice -c 3 bin/meiolol site --views data/views.bin "${args[@]}" \
        > data/views.log 2>&1; then
        views=$((SECONDS - t))
    else
        views=''
        log "views write failed: data/views.log"
    fi

    log "renderer"
    systemctl --user stop meiolol-render@a 2> /dev/null
    rm -f data/render-a.ready
    lines=$(wc -l < data/render.log)
    systemctl --user start meiolol-render@a
    t=$SECONDS
    until [[ -e data/render-a.ready ]] || (( SECONDS - t > 900 )); do sleep 2; done
    reload=$(tail -n +$((lines + 1)) data/render.log \
        | grep -oE 'views file read in [0-9]+ ms' | tail -n 1 \
        | grep -oE '[0-9]+')
    if [[ -e data/render-a.ready && -n $reload ]]; then
        reload=$((reload / 1000))
    else
        reload=''
    fi
    latency

    box_core=$(grep -oE 'upload: site [0-9]+s' "$STATE/box/web.log" | tail -n 10 \
        | grep -oE '[0-9]+' | median)
    box_views=$(grep -E 'views file [0-9]+s \([0-9]+ bytes\)$' "$STATE/box/web.log" \
        | tail -n 5 | grep -oE 'file [0-9]+s' | grep -oE '[0-9]+' | median)
    box_reload=$(grep -oE 'views file read in [0-9]+ ms' "$STATE/box/render.log" \
        | tail -n 10 | grep -oE '[0-9]+' | median)
    box_reload=$(( ${box_reload:-0} / 1000 ))

    note ""
    note "| | C01 s | box s (median of its last runs) | |"
    note "|---|---|---|---|"
    compare "core build" "$core" "$box_core"
    compare "views write, full" "$views" "$box_views"
    compare "renderer load" "$reload" "$box_reload"
    note ""
    note "- box's figures include its crawler running alongside; C01's crawler is off"
    note "- render latency, $(cat "$STATE/latency.txt")"
    done_stage bench
    echo "$slower" > "$STATE/slower"
    echo "$blocking" > "$STATE/blocking"
}

# Every page the renderer serves, 8 at a time, straight to it
latency() {
    local host
    host=$(hostname -I | cut -d' ' -f1)
    printf 'header = "X-Meiolol-Admin: %s"\n' "$(cat admin.token)" \
        | curl -sf --max-time 60 -K - -o "$STATE/pages" \
            "http://$host:8091/admin/api/pages.txt" \
        || { echo "no page list from the renderer" > "$STATE/latency.txt"; return; }
    grep -E '^/[A-Za-z0-9._/-]*$' "$STATE/pages" \
        | sed "s|.*|url = \"http://$host:8091&\"\noutput = /dev/null|" \
        | curl -s -Z --parallel-max 8 -K - --max-time 30 -H 'Accept-Encoding: gzip' \
            -w '%{http_code} %{time_total}\n' > "$STATE/latency.raw"
    sort -k2 -n "$STATE/latency.raw" | awk '
        {c[$1]++; t[NR] = $2 * 1000}
        END {
            printf "%d pages: p50 %.0f ms, p95 %.0f ms, p99 %.0f ms, max %.0f ms; status",
                NR, t[int(NR * .5) + 1], t[int(NR * .95) + 1], t[int(NR * .99) + 1], t[NR]
            for (k in c) printf " %s %d", k, c[k]
            print ""
        }' > "$STATE/latency.txt"
}

crawl_bench() {
    local here
    here=$(cd "$(dirname "$0")" && pwd)
    log "crawl bench: seed"
    mkdir -p "$BENCH"
    export MEIOLOL_BIN=$D/bin/meiolol
    "$here/bench-crawl.sh" seed "$BENCH" > "$STATE/bench-seed.log" 2>&1
    log "crawl bench: 20 min"
    "$here/bench-crawl.sh" run "$BENCH" 20 > "$STATE/bench-crawl.txt" 2>&1
    note "- crawl bench (fake API, the database the limit):" \
        "$(head -n 2 "$STATE/bench-crawl.txt" | paste -sd' ' -)"
    note "- box crawler, its last report:" \
        "$(grep 'matches/day' "$STATE/box/crawl.log" | tail -n 1)"
    rm -rf "$BENCH/run"
    done_stage crawl
}

# VM6 (deploy/vm-cutover.sh): the box's writers stopped, one pass. No quick_check: rsync
# checks each whole file it copies, the source is at rest, and C01's random reads make
# the checks take ~2 h with the crawler down. A stopped writer removes its -wal; an older
# one left here would be replayed over the fresh .db
if [[ ${1:-} == final ]]; then
    if fuser data/*.db 2> /dev/null | grep -q .; then
        log "final: a database is open here: $(fuser data/*.db 2>&1 | paste -sd' ' -)"
        exit 1
    fi
    rm -f data/*.db-wal
    catch_up || { log "final catch-up failed: $STATE/catch-up.log"; exit 1; }
    log "final catch-up done"
    exit 0
fi
[[ -e $STATE/copy ]] || wait_copy
if [[ ! -e $STATE/check ]]; then
    : > "$out"
    note "# VM3 on C01, $(date -u +%F)"
    note ""
    check
fi
[[ -e $STATE/bench ]] || bench
[[ -e $STATE/crawl ]] || crawl_bench
slower=$(cat "$STATE/slower" 2> /dev/null)
blocking=$(cat "$STATE/blocking" 2> /dev/null)
if [[ -n ${blocking// /} ]]; then
    note "VERDICT: downgrade in$blocking: retune (docs/plan/vm.md Later), then rerun"
elif [[ -n ${slower// /} ]]; then
    note "VERDICT: go, slower in$slower (under 2x, accepted: tuned after the move)"
else
    note "VERDICT: no downgrade"
fi
log "finished: $out"
