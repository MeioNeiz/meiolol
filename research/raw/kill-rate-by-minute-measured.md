# Kill rate and kill gold by game time (our measurement, 2026-10-20)

## Ranked solo games, local snapshot data/snap (patches 16.19-16.20, all regions, no remakes)

SQLite over matches and participants, queue 420:

games 85693, kills per game 64.2, mean length 28.9 min, kills per minute 2.22 (total kills over total minutes), 2.20 (mean of per-game rates)

## Every champion kill in the lab snapshot snap-20261013T2253Z (events.tsv, gpu-box)

Ranked solo lab games with a 10-participant timeline. Rate per band is kills in the band over the minutes games were still running in it, so games that ended earlier don't count as zero-kill minutes. Kill gold is the event's bounty column (bounty plus shutdown, what the killer gets).

games 290807 kills 18714920 kills/game 64.4 mean min 28.9 kpm 2.23

| band | games running | kills per minute | seconds per kill | mean kill gold |
| --- | --- | --- | --- | --- |
| 0-5 min | 290807 | 1.16 | 52 | 312 |
| 5-10 min | 290255 | 1.91 | 31 | 295 |
| 10-15 min | 288382 | 2.33 | 26 | 317 |
| 15-20 min | 286719 | 2.54 | 24 | 347 |
| 20-25 min | 262333 | 2.68 | 22 | 363 |
| 25-30 min | 217100 | 2.82 | 21 | 374 |
| 30-35 min | 126315 | 2.85 | 21 | 382 |
| 35-40 min | 48821 | 2.83 | 21 | 385 |
| 40-45 min | 13927 | 2.83 | 21 | 387 |
| 45+ min | 3097 | 2.80 | 21 | 388 |
