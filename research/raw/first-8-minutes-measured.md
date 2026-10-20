# Kills and objectives in the first 10 minutes of ranked solo (our measurement, 2026-10-20)

## Data and method

- events.tsv from the lab snapshot snap-20261013T2253Z (gpu-box): champion kills, towers and epic monsters in 290,807 ranked solo games with a 10-participant timeline, patches 16.19-16.20, all regions.
- Counts by 30-second bin of game time. Kills per game-minute: kills in the bin over 290,807 games times half a minute (almost every game is still running before 10:00).
- First dragon, grub, tower and herald: the game's earliest of each; first blood: the kill flagged first_blood. Roles are the killer's and victim's role in the timeline.
- Lobby tier as in kill-gold-by-rank-measured (median post-game tier, crawl floor Platinum IV).

## The first 8 minutes

Per game means by lobby tier (minutes; each over games where it happened):

| lobby tier | kills before 8:00 | first blood | first dragon | first grub | first tower | first herald |
| --- | --- | --- | --- | --- | --- | --- |
| Gold and below | 11.1 | 2.04 | 8.15 | 8.96 | 13.64 | 16.88 |
| Platinum | 11.2 | 2.04 | 8.38 | 8.93 | 13.54 | 16.95 |
| Emerald | 11.3 | 2.07 | 8.44 | 8.92 | 13.49 | 17.01 |
| Diamond | 11.2 | 2.11 | 8.37 | 8.92 | 13.47 | 17.02 |
| Master+ | 11.6 | 2.08 | 8.37 | 8.89 | 13.32 | 16.86 |
| all | 11.3 | 2.07 | 8.40 | 8.93 | 13.49 | 16.98 |

Kills, first blood and first objectives by 30-second bin, all games (counts over 290,807 games):

| from | kills | kills per game-minute | first bloods | jungler first bloods | first dragons | first grubs | first towers |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0:00 | 0 | 0.00 | 0 | 0 | 0 | 0 | 0 |
| 0:30 | 46531 | 0.32 | 33555 | 3495 | 0 | 0 | 0 |
| 1:00 | 80270 | 0.55 | 48358 | 4381 | 0 | 0 | 0 |
| 1:30 | 124865 | 0.86 | 62272 | 5065 | 0 | 0 | 0 |
| 2:00 | 229593 | 1.58 | 71185 | 11637 | 0 | 0 | 0 |
| 2:30 | 220756 | 1.52 | 36035 | 5223 | 0 | 0 | 0 |
| 3:00 | 297408 | 2.05 | 24573 | 7427 | 0 | 0 | 0 |
| 3:30 | 257164 | 1.77 | 8191 | 2593 | 0 | 0 | 0 |
| 4:00 | 223452 | 1.54 | 2903 | 764 | 0 | 0 | 0 |
| 4:30 | 206098 | 1.42 | 1332 | 298 | 0 | 0 | 0 |
| 5:00 | 237367 | 1.63 | 976 | 199 | 2415 | 0 | 0 |
| 5:30 | 270229 | 1.86 | 718 | 184 | 26570 | 0 | 5 |
| 6:00 | 273502 | 1.88 | 342 | 104 | 39446 | 0 | 19 |
| 6:30 | 264951 | 1.82 | 178 | 48 | 35457 | 0 | 37 |
| 7:00 | 274537 | 1.89 | 81 | 21 | 28038 | 0 | 86 |
| 7:30 | 269957 | 1.86 | 47 | 12 | 21953 | 0 | 162 |
| 8:00 | 278651 | 1.92 | 25 | 9 | 18287 | 106584 | 453 |
| 8:30 | 311471 | 2.14 | 17 | 6 | 20590 | 87533 | 978 |
| 9:00 | 289704 | 1.99 | 6 | 4 | 16402 | 43246 | 1642 |
| 9:30 | 290897 | 2.00 | 4 | 1 | 12904 | 24028 | 3413 |

First blood: killer and victim role, all games:

| role | as killer | as victim |
| --- | --- | --- |
| top | 25.4% | 28.1% |
| jungle | 14.3% | 9.7% |
| middle | 19.0% | 19.1% |
| bottom | 28.4% | 20.8% |
| utility | 12.6% | 22.3% |

Jungler kills by 30-second bin before 6:00 (all games):

| from | 0:00 | 0:30 | 1:00 | 1:30 | 2:00 | 2:30 | 3:00 | 3:30 | 4:00 | 4:30 | 5:00 | 5:30 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| jungler kills | 0 | 4403 | 6700 | 10891 | 39320 | 40486 | 90754 | 71358 | 54539 | 45221 | 49401 | 64634 |


Share of games with a dragon or grub taken by each time (cumulative, of games where one was taken):

grub total 288725: by 6:00 0.0% by 7:00 0.0% by 8:00 0.0% by 8:30 36.9% by 9:00 67.2% by 10:00 90.5%
dragon total 288645: by 6:00 10.0% by 7:00 36.0% by 8:00 53.3% by 8:30 59.6% by 9:00 66.8% by 10:00 76.9%
