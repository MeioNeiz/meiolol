#!/usr/bin/env bash
# C01 tuning (docs/plan/vm.md "C01 tuning"): times the site's heavy steps on the live data
# with the web loop paused, N runs each into scratch files, and appends one row of
# medians to ~/vm-chain/tune/results.md. The setting under test goes in the environment:
#   MEIOLOL_FILTER_RUNS=8 c01-bench.sh runs-8 [N]
# Runs on C01 from ~/vm-chain/deploy (scp'd there, like vm-chain.sh); the crawler keeps
# running, as on the box when its figures were logged.
set -uo pipefail

label=$1 n=${2:-3}
D=$HOME/ml/meiolol
S=$HOME/vm-chain/tune
mkdir -p "$S"
cd "$D" || exit 1
log() { echo "$(date -u +%FT%TZ) $label: $*" | tee -a "$S/bench.log"; }
median() { sort -n | awk '{a[NR] = $1} END {print NR ? a[int((NR + 1) / 2)] : ""}'; }

# The daily eval runs inside the web loop, 24 h after data/eval.log's last write
# (web-loop.sh), and pausing the loop kills it: refuse while one runs or falls due before
# the bench ends (~16 min a run, 20 min margin)
if ! flock -n data/eval.lock true; then
    log "refused: an eval is running (data/eval.lock)"
    exit 3
fi
due=$(($(stat -c %Y data/eval.log 2> /dev/null || echo 0) + 86400 - $(date +%s)))
if ((due < n * 16 * 60 + 20 * 60)); then
    log "refused: the daily eval is due in $((due / 60)) min"
    exit 3
fi

args=(--contact "$(cat contact)" --origin https://meio.lol)
[[ -s riot.txt ]] && args+=(--riot-txt "$(< riot.txt)")

# While this runs a deploy copies a new bin/meiolol but holds the web loop and the
# render swap (box.sh web start): the runs keep one binary, the exit catches up
cp bin/meiolol "$S/meiolol"
systemctl --user stop meiolol-web
# Not in a fork of this shell: a renderer killed before its exec runs this trap too
trap '[[ $BASHPID == "$$" ]] || exit
    rm -rf data/site.tune data/views.tune.bin data/render-tune.ready;
    systemctl --user start meiolol-web
    cmp -s bin/meiolol "$S/meiolol" || systemctl --user -q is-active meiolol-render-swap \
        || systemd-run --user -q --collect --unit meiolol-render-swap \
            --working-directory="$D" "$D/bin/render-swap.sh"' EXIT

cores=() views=() loads=()
for i in $(seq "$n"); do
    log "run $i: core build"
    rm -rf data/site.tune
    t=$SECONDS
    if "$S/meiolol" site "${args[@]}" --out data/site.tune --static core \
        > "$S/core.log" 2>&1; then
        cores+=($((SECONDS - t)))
    else
        log "core build failed: $S/core.log"
    fi

    log "run $i: views write, every part fresh"
    rm -f data/views.tune.bin
    t=$SECONDS
    if "$S/meiolol" site --views data/views.tune.bin "${args[@]}" > "$S/views.log" 2>&1; then
        views+=($((SECONDS - t)))
    else
        log "views write failed: $S/views.log"
    fi

    # A renderer of its own on a spare port, loading the file just written
    log "run $i: renderer load"
    rm -f data/render-tune.ready
    # Emptied first: the wait below would otherwise find the previous run's line
    : > "$S/render.log"
    "$S/meiolol" render --contact "$(cat contact)" --host 127.0.0.1 --port 8099 \
        --views data/views.tune.bin --ready data/render-tune.ready > "$S/render.log" 2>&1 &
    pid=$!
    until grep -q 'views file read in' "$S/render.log" || ! kill -0 "$pid" 2> /dev/null; do
        sleep 1
    done
    kill "$pid" 2> /dev/null
    wait "$pid" 2> /dev/null
    ms=$(grep -oE 'views file read in [0-9]+ ms' "$S/render.log" | grep -oE '[0-9]+')
    if [[ -n $ms ]]; then loads+=($((ms / 1000))); else log "renderer load failed: $S/render.log"; fi
done

# Every page from the live renderer, 8 at a time (vm-chain.sh's latency)
host=$(hostname -I | cut -d' ' -f1)
printf 'header = "X-Meiolol-Admin: %s"\n' "$(cat admin.token)" \
    | curl -sf --max-time 60 -K - -o "$S/pages" "http://$host:8091/admin/api/pages.txt"
grep -E '^/[A-Za-z0-9._/-]*$' "$S/pages" \
    | sed "s|.*|url = \"http://$host:8091&\"\noutput = /dev/null|" \
    | curl -s -Z --parallel-max 8 -K - --max-time 30 -H 'Accept-Encoding: gzip' \
        -w '%{http_code} %{time_total}\n' > "$S/latency.raw"
lat=$(sort -k2 -n "$S/latency.raw" | awk '{t[NR] = $2 * 1000}
    END {printf "p50 %.0f p95 %.0f p99 %.0f", t[int(NR * .5) + 1], t[int(NR * .95) + 1],
        t[int(NR * .99) + 1]}')

med() { [[ $# -gt 0 ]] && printf '%s\n' "$@" | median || echo failed; }
cache=$(free -g | awk '/^Mem:/ {print $6}')
crawl=$(grep -oE '[0-9]+ matches/day' data/crawl.log | tail -n 1)
[[ -s $S/results.md ]] || {
    echo "| setting | core build s | views write s | renderer load s | render ms | buff/cache GB | crawl |"
    echo "|---|---|---|---|---|---|---|"
} > "$S/results.md"
echo "| $label | $(med "${cores[@]}") (${cores[*]}) | $(med "${views[@]}") (${views[*]}) |" \
    "$(med "${loads[@]}") (${loads[*]}) | $lat | $cache | $crawl |" >> "$S/results.md"
log "done: $(tail -n 1 "$S/results.md")"
