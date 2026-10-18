#!/usr/bin/env bash
# deploy/aa-build.sh SNAP BEFORE_MS > aa_build.tsv: per champion-role, the completed crit or
# attack-speed items held at the end of the game (Data Dragon item stats of the snapshot's
# patches, SNAP/legendaries.tsv for completed), mean of its won and lost games' means, ranked
# solo games starting before BEFORE_MS (champgroups: bounds[2]). Input for `meiolol-lab
# champgroups --aa`; Riot's summaries don't split basic-attack damage from abilities
set -euo pipefail
snap=${1:?SNAP}
before=${2:?BEFORE_MS}
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for f in "$snap"/ddragon/*/item.json; do
    jq -r '.data | to_entries[] | select((.value.stats.FlatCritChanceMod // 0) > 0
        or (.value.stats.PercentAttackSpeedMod // 0) > 0) | .key' "$f"
done | sort -u | join - <(cut -f2 "$snap/legendaries.tsv" | sort -u) > "$tmp"
sqlite3 -readonly "$snap/meiolol.db" <<EOF
CREATE TEMP TABLE aa(id INTEGER PRIMARY KEY);
.mode tabs
.import $tmp aa
WITH s AS (
  SELECT p.champion_id c,
    CASE p.position WHEN 'TOP' THEN 0 WHEN 'JUNGLE' THEN 1 WHEN 'MIDDLE' THEN 2
      WHEN 'BOTTOM' THEN 3 WHEN 'UTILITY' THEN 4 END r,
    p.win w,
    (p.item0 IN aa) + (p.item1 IN aa) + (p.item2 IN aa) + (p.item3 IN aa) + (p.item4 IN aa)
      + (p.item5 IN aa) + (p.item6 IN aa) n
  FROM participants p JOIN matches m USING (match_id)
  WHERE m.queue_id = 420 AND m.remake = 0 AND m.game_start < $before
    AND p.position IN ('TOP', 'JUNGLE', 'MIDDLE', 'BOTTOM', 'UTILITY')
), h AS (SELECT c, r, w, avg(n) a, count(*) k FROM s GROUP BY c, r, w)
SELECT 'champion', 'role', 'aa_build' UNION ALL
SELECT c, r, printf('%.4f', avg(a)) FROM h GROUP BY c, r HAVING count(*) = 2 AND sum(k) >= 30;
EOF
