#!/usr/bin/env bash
# Crawler write throughput with no network: `meiolol crawl --fake-api MS` answers every
# Riot call from fixtures after MS ms, so the database is the limit.
#   deploy/bench-crawl.sh seed DIR            box-sized databases in DIR/base (minutes)
#   deploy/bench-crawl.sh run DIR MIN [MODE]  crawl a fresh clone of DIR/base for MIN
#                                             minutes. MODE slow: macOS background QoS
#                                             (efficiency cores, throttled disk I/O);
#                                             micro: slow plus stopped 7 slices in 8
# Prints the last report line (matches/day, per-region matches and timelines) and the
# busy pauses. Seeded size, close to the box's on 2026-10-11: 1M players, 300k matches
# (3M participants), 100k compact timelines, 60k pending timelines (europe 40k), 50k
# raw summaries, 10k raw timelines.
set -eu
cd "$(dirname "$0")/.."
cmd=$1 dir=$2
bin=${MEIOLOL_BIN:-zig-out/bin/meiolol}

seed() {
    rm -rf "$dir/base" && mkdir -p "$dir/base"
    "$bin" status --data "$dir/base" > /dev/null
    local now
    now=$(date +%s)
    sqlite3 "$dir/base/meiolol.db" <<SQL
ATTACH '$dir/base/raw.db' AS raw;
ATTACH '$dir/base/timeline.db' AS timeline;
PRAGMA journal_mode=WAL;
BEGIN;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 1000000)
INSERT INTO players (puuid, tier, division, lp, wins, losses, rank_seen_at,
    matches_checked_at, source, platform, region, seen_at)
SELECT hex(randomblob(39)), 'GOLD', 'II', 40, 30, 28, $now,
    CASE WHEN i % 10 = 0 THEN NULL ELSE $now - i % 40000 END,
    CASE WHEN i % 3 = 0 THEN 'ladder' ELSE 'participant' END,
    CASE i % 4 WHEN 0 THEN 'EUW1' WHEN 1 THEN 'KR' WHEN 2 THEN 'NA1' ELSE 'OC1' END,
    CASE i % 4 WHEN 0 THEN 'europe' WHEN 1 THEN 'asia' WHEN 2 THEN 'americas' ELSE 'sea' END,
    $now - i % 86400
FROM n;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 300000)
INSERT INTO matches SELECT 'EUW1_' || (7000000000 + i), 'riot', 'EUW1', 420, '26.20',
    '26.20.1', ($now - i) * 1000, 1800, 100, 0 FROM n;
INSERT INTO match_queue (match_id, status, discovered_at, region)
    SELECT match_id, 'done', $now, 'europe' FROM matches;
WITH RECURSIVE s(slot) AS (SELECT 0 UNION ALL SELECT slot + 1 FROM s WHERE slot < 9)
INSERT INTO participants (match_id, slot, team_id, puuid, champion_id, position, win,
    kills, deaths, assists, gold, cs, champ_level, item0, item1, item2, keystone)
SELECT match_id, slot, 100 + 100 * (slot / 5), hex(randomblob(39)), 1 + abs(random()) % 170,
    'TOP', slot < 5, 5, 5, 5, 12000, 200, 16, 3031, 3006, 3036, 8005
FROM matches, s;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 100000)
INSERT INTO timeline.timelines SELECT 'EUW1_' || (7000000000 + i), 30, 900, randomblob(8500)
FROM n;
INSERT INTO timeline_queue (match_id, region, status, queued_at)
    SELECT match_id, 'europe', 'done', $now FROM timeline.timelines;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 60000)
INSERT INTO timeline_queue (match_id, region, queued_at)
SELECT 'EUW1_' || (7100000000 + i),
    CASE WHEN i % 3 = 0 THEN 'asia' ELSE 'europe' END, $now - i FROM n;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 50000)
INSERT INTO raw.raw_docs SELECT 'riot_match', 'EUW1_' || (7000000000 + i), $now,
    randomblob(8000) FROM n;
WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 10000)
INSERT INTO raw.timeline_docs SELECT 'EUW1_' || (7000000000 + i), $now, randomblob(60000)
FROM n;
COMMIT;
PRAGMA main.wal_checkpoint(TRUNCATE);
PRAGMA raw.wal_checkpoint(TRUNCATE);
PRAGMA timeline.wal_checkpoint(TRUNCATE);
SQL
    du -sh "$dir/base"
}

run() {
    local minutes=$1 mode=${2:-} run=$dir/run
    rm -rf "$run"
    # APFS clone: instant, and every run starts from the same state
    cp -cR "$dir/base" "$run" 2> /dev/null || cp -R "$dir/base" "$run"
    local hours prefix=()
    hours=$(echo "scale=4; $minutes / 60" | bc)
    [[ $mode == slow || $mode == micro ]] && prefix=(taskpolicy -c background)
    ${prefix[@]+"${prefix[@]}"} "$bin" crawl --data "$run" --fake-api 20 \
        --hours "$hours" > "$dir/run.log" 2>&1 &
    local pid=$!
    if [[ $mode == micro ]]; then
        # Runs 1 slice in 8, like the micro's 1/8 OCPU; stolen time stops every thread
        while kill -STOP $pid 2> /dev/null; do
            sleep 0.07
            kill -CONT $pid 2> /dev/null || break
            sleep 0.01
        done
    fi
    wait $pid || true
    grep 'matches/day' "$dir/run.log" | tail -1
    echo "busy pauses: $(grep -c 'database busy' "$dir/run.log" || true)," \
        "lock warnings: $(grep -c 'locked' "$dir/run.log" || true)"
}

case $cmd in
    seed) seed ;;
    run) run "${@:3}" ;;
    *) echo "usage: $0 seed DIR | run DIR MINUTES [slow|micro]" >&2; exit 2 ;;
esac
