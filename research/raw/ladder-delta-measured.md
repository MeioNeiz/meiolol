# Ladder delta vs new match ids, EUW Plat+ (2026-10-12)

Our measurement on the box with our key. Two samples of EUW1 ladder players (Platinum to Master) from the players table.

## Sample 1: 16.20 games per random player

match-v5 by-puuid ids, queue 420, startTime 1791351117 (first EUW1 16.20 game we stored, 2026-10-06), endTime now (2026-10-12 00:00Z). One count per player:

23 13 0 0 0 0 0 0 3 0 5 4 0 0 16 11 5 0 0 0 4 0 16 0 0 0 0 0 0 0 0 0 0 2 11 2 0 0 0 0 0 2 0 12 0 1 0 0 0 0 1 5 0 0 0 0 0 0 0 0 0 36 0 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 4 2 0 5 2 0 0 3 10 0 0 

90 players: 49 with 0 games on 16.20; mean 2.91 games per player; mean 6.39 among the 41 who played.

## Sample 2: ladder wins+losses growth vs ids returned

For players whose last ladder snapshot (rank_seen_at) was over 6 h old: league-v4 entries by-puuid now, minus wins+losses stored at rank_seen_at; then ids since rank_seen_at. Columns: delta, ids, hours since snapshot:

0 0 19;0 0 14;0 0 20;0 0 14;0 0 20;0 0 20;0 0 20;0 0 11;0 0 21;0 0 21;0 0 13;0 0 20;0 0 13;0 0 20;0 0 17;0 0 20;2 2 15;0 0 20;0 0 19;3 3 21;0 0 20;0 0 20;0 0 20;0 0 13;0 0 20;0 0 20;2 2 16;0 0 20;0 0 15;6 7 20;10 10 21;0 0 20;0 0 20;0 0 17;0 0 20;0 0 20;2 2 20;0 0 20;0 0 19;0 0 21;0 0 21;0 0 20;0 0 20;0 0 20;2 3 21;0 0 20;0 0 14;0 0 20;0 0 20;0 0 20;0 0 21;0 0 20;0 0 20;0 0 20;0 0 20;0 0 19;0 0 16;0 0 18;0 0 14;0 0 21;0 0 19;0 0 20;0 0 21;0 0 18;0 0 20;3 3 20;0 0 14;0 0 20;0 0 20;0 0 18;0 0 19;0 0 20;0 0 17;0 0 16;0 0 20;1 1 16;0 0 21;0 0 15;0 0 15;0 0 20;0 0 21;0 0 18;4 4 20;0 0 19;0 0 20;0 0 21;0 0 21;1 1 20;0 0 14;0 0 20;0 0 21;0 0 16;0 0 15;0 0 14;0 0 20;0 0 20;3 3 20;0 0 20;0 0 20;0 0 20;0 0 19;0 0 20;0 0 20;2 2 20;0 0 20;0 0 18;1 1 20;4 4 20;3 3 20;0 0 20;6 6 15;0 0 20;0 0 20;0 0 19;0 0 20;0 0 16;2 2 19;0 0 20;6 5 19;1 1 20;0 0 20;0 0 21;0 0 19;1 1 20;1 1 16;0 0 20;0 0 17;0 0 19;0 0 19;0 0 20;1 1 15;0 0 20;0 0 15;0 0 14;1 1 18;0 0 20;0 0 20;0 0 20;3 3 18;0 0 14;0 0 20;0 0 20;0 0 20;6 6 20;0 0 13;0 0 16;0 0 20;0 0 16;2 2 20;0 0 21;0 0 19;0 0 20;0 0 20;0 0 20;8 8 20;0 0 20;0 0 20;0 0 20;3 4 19;0 0 19;

160 players, median window 20 h. delta equals ids for 156 of 160, the rest within 1. 131 players had delta 0 and returned 0 ids in total. Players with delta > 0 returned 3.17 ids per call; all players 0.57 per call.
