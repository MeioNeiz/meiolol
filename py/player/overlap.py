"""Data sanity for player history: does any player have two games that overlap in time?
Usage: overlap.py SNAP. Read-only; prints counts and a few examples (match ids only)."""
import sqlite3
import sys
from collections import defaultdict

snap = sys.argv[1]
db = sqlite3.connect(f"file:{snap}/meiolol.db?mode=ro", uri=True)
games = {m: (s, d, r) for m, s, d, r in db.execute("SELECT match_id, game_start, duration_s, remake FROM matches")}
by_player = defaultdict(list)
for m, p in db.execute("SELECT match_id, puuid FROM participants WHERE puuid IS NOT NULL"):
    if m in games:
        by_player[p].append(m)
pairs = overlap_players = shown = 0
gaps = []
for p, ms in by_player.items():
    ms.sort(key=lambda m: games[m][0])
    hit = False
    for a, b in zip(ms, ms[1:]):
        end_a = games[a][0] + games[a][1] * 1000
        if games[b][0] < end_a:
            pairs += 1
            hit = True
            gaps.append((end_a - games[b][0]) / 1000)
            if shown < 5:
                print("overlap", a, b, "by", round((end_a - games[b][0]) / 1000), "s", "remakes", games[a][2], games[b][2])
                shown += 1
    overlap_players += hit
gaps.sort()
print(f"players {len(by_player)} games {len(games)} overlapping pairs {pairs} players with any {overlap_players}")
if gaps:
    print("overlap seconds: median", gaps[len(gaps) // 2], "max", gaps[-1])
