# Fed players and their team: win rates (our measurement, 2026-10-20)

## Method

Local snapshot data/snap/meiolol.db (ranked solo, queue 420, no remakes, patches 16.19-16.20, all regions), games of 15:00 or longer with gold at 14:00 for all ten players: 652,400 player rows in 65,240 games. A player's lane lead is their gold at 14:00 minus their opponent's in the same position. "Rest of team" is the team's gold lead at 14:00 minus that player's own lane lead (the other four's leads over their opponents, summed). "Fed" here: 1000+ gold ahead of the lane opponent at 14:00. End-of-game rows use final gold and kills (games with a tie for the top dropped). Script: fed.sql (scratchpad).

Limits: association, not cause. End-of-game gold and kills are partly a result of winning (the winning team gets more kills and gold late), so those rows describe, they don't test carrying. Platinum IV+ games (the crawl's floor). A support's lane lead is small by nature, so few supports pass 1000.

## A player 1000+ gold ahead of their lane opponent at 14:00, by where the other four stood

| rest of team at 14:00 | players | won |
| --- | --- | --- |
| 3000+ behind | 16328 | 27.6% |
| 1500-3000 behind | 18349 | 46.6% |
| 0-1500 behind | 25119 | 60.7% |
| 0-1500 ahead | 26488 | 73.0% |
| 1500+ ahead | 56450 | 89.1% |
| all 1000+ ahead | 142734 | 68.6% |
| all 1000+ ahead, rest of team behind | 59796 | 47.3% |

## By role, 1000+ ahead at 14:00

| role | players | won | won when the other four were behind | of them, other four behind |
| --- | --- | --- | --- | --- |
| BOTTOM | 35520 | 70.2% | 50.4% | 14808 |
| JUNGLE | 27324 | 69.6% | 48.3% | 11235 |
| MIDDLE | 29785 | 69.6% | 49.0% | 12582 |
| TOP | 36004 | 64.6% | 44.6% | 17476 |
| UTILITY | 14101 | 70.6% | 39.4% | 3695 |

## End of game

| player | players | won |
| --- | --- | --- |
| most gold in the game | 65221 | 86.9% |
| most kills in the game | 58470 | 85.8% |
| 10+ kills and at most 3 deaths | 30065 | 96.0% |

## Existing result, copied from docs/learned.md (2026-10-14, "Carry and impact")

No champion was found to turn its own gold lead into wins better than others in its role: what 1,000 gold on your champion is worth depends on the role, at 15 minutes about 8 percentage points for the bot laner, 4.5-7 for top, jungle and mid and about 0 for the support (at 25 minutes: 5, 3-3.5 and 0).
