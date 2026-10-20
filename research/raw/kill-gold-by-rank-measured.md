# Kill gold and early leads by lobby rank in ranked solo (our measurement, 2026-10-20)

## Data and method

- events.tsv from the lab snapshot snap-20261013T2253Z (gpu-box): every champion kill in 290,807 ranked solo games with a 10-participant timeline, patches 16.19-16.20, all regions.
- Kill gold is the event's bounty column: bounty plus shutdown, what the killer gets (assist gold not included). Base kill gold is 300 to 420 by victim level, first blood +100; under 300 means a depreciated victim, over 450 means an active bounty or shutdown above base.
- Lobby tier joined from the same snapshot's meiolol.db: median of the players' post-game ranked solo tiers (at least 6 known). Crawl floor Platinum IV, so Gold and below is a small, atypical group; real low elo is not in this data.
- Lead before a kill: the events.tsv gold column (team gold, blue minus red, from the last minute frame at or before the kill), signed to the killer's team; kills from 10:00.
- Chained kills: kills before 15:00 with at least one other kill by the same team within 30 s either side (events.tsv kills_near columns). This counts any nearby team kill, teamfights included, not only the dives and repeat kills a coach means by a chained play.
- Early lead by tier: team gold at 10 and 14 minutes (sum of participants gold10, gold14), winner's side minus loser's, from the local and lab meiolol.db (games with both values and a winner).

## Kill gold by lobby tier (events.tsv bounty column: bounty plus shutdown, what the killer gets)

| lobby tier | games | kills | kills per game | mean kill gold | under 300 (depreciated) | over 450 (bounty or shutdown) |
| --- | --- | --- | --- | --- | --- | --- |
| Gold and below | 14425 | 1005132 | 69.7 | 341 | 28.8% | 9.3% |
| Platinum | 91218 | 6072966 | 66.6 | 341 | 28.7% | 9.2% |
| Emerald | 101652 | 6540180 | 64.3 | 341 | 28.6% | 9.2% |
| Diamond | 44187 | 2728355 | 61.7 | 340 | 28.7% | 9.2% |
| Master+ | 25987 | 1523315 | 58.6 | 337 | 29.3% | 8.9% |
| all | 290807 | 18714920 | 64.4 | 340 | 28.7% | 9.2% |

Mean kill gold by 5-minute band and lobby tier:

| lobby tier | 0-5 | 5-10 | 10-15 | 15-20 | 20-25 | 25-30 | 30+ |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gold and below | 312 | 294 | 315 | 345 | 360 | 371 | 383 |
| Platinum | 312 | 295 | 316 | 346 | 363 | 374 | 383 |
| Emerald | 312 | 295 | 317 | 347 | 364 | 375 | 383 |
| Diamond | 312 | 295 | 318 | 348 | 364 | 375 | 382 |
| Master+ | 311 | 294 | 318 | 348 | 363 | 374 | 381 |
| all | 312 | 295 | 317 | 347 | 363 | 374 | 383 |

## Kill gold by the killer team's gold lead just before the kill (kills from 10:00)

Lead from the last minute frame at or before the kill (events.tsv gold, blue minus red, signed to the killer's team).

| killer team's lead | kills | mean kill gold | over 450 (bounty or shutdown) |
| --- | --- | --- | --- |
| behind 3k+ | 2788670 | 481 | 37.3% |
| behind 1-3k | 1974057 | 390 | 19.8% |
| within 1k | 2599521 | 330 | 5.0% |
| ahead 1-3k | 2386102 | 308 | 0.7% |
| ahead 3k+ | 4519167 | 294 | 0.0% |

Same, over 450 share by lobby tier (behind 3k+ / within 1k / ahead 3k+):

| lobby tier | behind 3k+ | within 1k | ahead 3k+ |
| --- | --- | --- | --- |
| Gold and below | 36.3% | 4.8% | 0.0% |
| Platinum | 36.9% | 5.0% | 0.0% |
| Emerald | 37.5% | 5.0% | 0.0% |
| Diamond | 37.9% | 5.1% | 0.1% |
| Master+ | 38.2% | 5.0% | 0.0% |
| all | 37.3% | 5.0% | 0.0% |

## Kills chained before 15:00 by lobby tier

Share of kills before 15:00 with another kill by the same team within 30 s either side (events.tsv kills_near).

| lobby tier | kills before 15:00 | with a team kill within 30 s |
| --- | --- | --- |
| Gold and below | 385482 | 66.4% |
| Platinum | 2449584 | 66.5% |
| Emerald | 2728975 | 66.5% |
| Diamond | 1177899 | 66.5% |
| Master+ | 704701 | 67.3% |
| all | 7802014 | 66.5% |

## Team gold lead at 10 and 14 minutes by lobby tier

### games-local.tsv

| lobby tier | games | median abs lead at 10 | at 14 | winner ahead at 10 | winner ahead 1k+ at 10 | winner ahead 1k+ at 14 | team ahead 2k+ at 14 wins |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gold and below | 5239 | 1395 | 2316 | 68.8% | 47.1% | 60.3% | 83.1% |
| Platinum | 16617 | 1386 | 2317 | 68.0% | 46.5% | 58.8% | 82.5% |
| Emerald | 22962 | 1420 | 2336 | 68.0% | 47.6% | 59.8% | 82.9% |
| Diamond | 9417 | 1414 | 2389 | 68.6% | 47.0% | 60.8% | 83.5% |
| Master+ | 6306 | 1478 | 2571 | 69.8% | 49.9% | 62.5% | 84.2% |
| all | 60541 | 1412 | 2360 | 68.4% | 47.4% | 60.0% | 83.1% |

### games-lab.tsv

| lobby tier | games | median abs lead at 10 | at 14 | winner ahead at 10 | winner ahead 1k+ at 10 | winner ahead 1k+ at 14 | team ahead 2k+ at 14 wins |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gold and below | 14239 | 1408 | 2318 | 68.2% | 47.5% | 59.9% | 82.9% |
| Platinum | 90030 | 1410 | 2337 | 68.4% | 47.3% | 59.5% | 82.7% |
| Emerald | 100473 | 1422 | 2357 | 68.3% | 47.7% | 59.9% | 82.9% |
| Diamond | 43684 | 1410 | 2393 | 68.2% | 47.6% | 60.4% | 83.0% |
| Master+ | 25749 | 1470 | 2557 | 69.7% | 49.9% | 62.6% | 84.3% |
| all | 274175 | 1419 | 2372 | 68.4% | 47.8% | 60.1% | 83.0% |
