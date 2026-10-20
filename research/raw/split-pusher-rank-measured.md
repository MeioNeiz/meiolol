# Yorick and split pushers' win rate by rank in ranked solo (our measurement, 2026-10-20)

## Method

Lab snapshot snap-20261013T2253Z's meiolol.db on the gpu-box (opened read-only): ranked solo (queue 420), no remakes, patches 16.19-16.20, every platform, 363,927 games, test games left out. Top lane players only, by the player's own rank. Split pushers: the set a commenter on the video used (Yorick, Fiora, Jax, Tryndamere, Nasus, Trundle). Script: yorick.py (scratchpad).

Limits: the crawl starts at Platinum IV, so "Gold or lower" are lower-ranked players who were in Platinum+ games, not Iron games; Iron itself can't be checked. The rank is looked up after the game, so winners sit a little higher: that is why every top laner's win rate climbs from 45.9% to 52.4% with rank. Compare a champion with all top laners in the same row, not across rows.

('16.19', '16.20', 363927)

Yorick top

| player's rank (looked up after the game) | games | won |
| --- | --- | --- |
| Gold or lower | 884 | 46.3% |
| Platinum | 3433 | 48.0% |
| Emerald | 3434 | 50.4% |
| Diamond | 1223 | 52.1% |
| Master+ | 545 | 47.5% |
| unknown | 656 | 44.7% |
| all | 10175 | 48.9% |

Split pushers top (Yorick, Fiora, Jax, Tryndamere, Nasus, Trundle)

| player's rank (looked up after the game) | games | won |
| --- | --- | --- |
| Gold or lower | 5517 | 46.8% |
| Platinum | 23330 | 48.3% |
| Emerald | 24808 | 51.2% |
| Diamond | 10769 | 52.7% |
| Master+ | 6080 | 50.9% |
| unknown | 4977 | 46.2% |
| all | 75481 | 49.9% |

Every top laner

| player's rank (looked up after the game) | games | won |
| --- | --- | --- |
| Gold or lower | 40102 | 45.9% |
| Platinum | 182323 | 48.8% |
| Emerald | 204132 | 51.0% |
| Diamond | 95810 | 52.4% |
| Master+ | 55507 | 51.7% |
| unknown | 40712 | 46.9% |
| all | 618586 | 50.0% |

Yorick minus every top laner, same rank: Gold or lower -0.4, Platinum -0.8, Emerald -0.6, Diamond -0.3, Master+ -4.2 points (Master+ on 545 games, about ±4.2 points at 95%).
