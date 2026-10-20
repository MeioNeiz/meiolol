# Objectives: how much more often the taking team wins than its chance just before (our measurement, 2026-10-20)

## Method

Lab snapshot snap-20261013T2253Z on the gpu-box (ranked solo, patches 16.19-16.20, every platform), events.tsv rows for towers, inhibitors and epic monsters, test games left out (is_test 0). For each take, the taking team's chance to win at the start of that minute is the draft-aware state model's cross-fitted chance (state/preds-wcd.tsv: gold, XP, towers, inhibitors, dragons, soul point, soul, elder, grubs, herald, baron and the draft, 5-fold cross-fit by game). "Won minus chance" is the taking team's eventual win rate minus that chance: win probability added from the start of the minute to the end of the game, the same kind of number as the Broken by Concept figures quoted in the video. 236,227 games have chances. Script: obj.py (scratchpad), one streaming pass.

Limits: the chance is from the minute's start frame, so a fight won earlier in the same minute (most barons and elders follow one) counts towards the objective. It is association: teams that take an objective differ in ways the state misses. "Soul" is a team's fourth elemental dragon; "first dragon" the game's first elemental dragon. Grubs are per grub.

games in file 238330 with preds 236227

| event (taking team) | when | takes | taking team won | chance just before | won minus chance |
| --- | --- | --- | --- | --- | --- |
| baron | all | 256196 | 79.4% | 69.4% | +10.0 pp |
| dragon | all | 928992 | 69.0% | 62.3% | +6.7 pp |
| dragon | first of game | 236046 | 61.9% | 55.7% | +6.2 pp |
| dragon | soul (team's 4th) | 73581 | 88.4% | 79.5% | +8.9 pp |
| elder | all | 14578 | 80.1% | 65.7% | +14.5 pp |
| grub | all | 707794 | 56.2% | 54.5% | +1.7 pp |
| herald | all | 204835 | 66.6% | 65.1% | +1.5 pp |
| inhibitor | all | 422574 | 90.3% | 82.8% | +7.5 pp |
| outer tower mid | <14 | 40807 | 76.8% | 73.3% | +3.5 pp |
| outer tower mid | 14-19 | 252068 | 64.3% | 60.9% | +3.5 pp |
| outer tower mid | 20+ | 92177 | 42.1% | 37.1% | +5.0 pp |
| outer tower mid | all | 385052 | 60.3% | 56.5% | +3.8 pp |
| outer tower side | <14 | 160516 | 70.0% | 67.8% | +2.2 pp |
| outer tower side | 14-19 | 476631 | 57.9% | 55.8% | +2.1 pp |
| outer tower side | 20+ | 172458 | 42.4% | 39.9% | +2.5 pp |
| outer tower side | all | 809605 | 57.0% | 54.8% | +2.2 pp |
| game's first mid outer tower | <14 | 40531 | 76.9% | 73.4% | +3.5 pp |
| game's first mid outer tower | 14-19 | 184280 | 70.1% | 66.7% | +3.4 pp |
| game's first mid outer tower | 20+ | 7911 | 63.6% | 59.8% | +3.8 pp |

Monster rows in the file (test games left out): no ATAKHAN rows at all (Atakhan was removed in patch 26.1).

| subtype | rows |
| --- | --- |
| AIR_DRAGON | 155530 |
| BARON_NASHOR | 259549 |
| CHEMTECH_DRAGON | 155074 |
| EARTH_DRAGON | 155241 |
| ELDER_DRAGON | 17071 |
| FIRE_DRAGON | 156637 |
| HEXTECH_DRAGON | 155883 |
| HORDE | 713527 |
| RIFTHERALD | 224946 |
| WATER_DRAGON | 154451 |

## Existing result, copied from docs/model.md "In-game events on the draft-aware state" (same snapshot, 236,227 games)

That run regresses each minute's change in win chance on the events in it, so events of one fight share credit: a cleaner per-event value than the table above.

Win points for the taking team, wc / wcd [95%] / rich:

| event | 10-14 min | 20-24 | 30-40 |
| --- | --- | --- | --- |
| dragon (any element) | 4.5 / 4.4-4.5 [±0.07] / 3.2-4.8 | 4.1 / 4.0-4.1 / 2.1-3.0 | 5.2-5.5 / 5.3-5.5 [±0.13] / 0.0-1.7 |
| elder | | | 9.2 / 9.2 [9.0, 9.3] / 4.4 |
| baron | | 5.8 / 5.6 [5.6, 5.7] / 3.8 | 8.0 / 7.9 [7.8, 7.9] / 3.5 |
| outer tower | 0.1 / 0.2 / -0.3 | 2.6 / 2.7 / 1.4 | 3.0 / 3.0 / 0.0 |
| inhibitor | | -0.1 / -0.2 / -1.0 | 3.5 / 3.4 [3.3, 3.4] / 2.0 |
| kill | 3.8 / 3.8 / 3.8 | 2.8 / 2.7 / 3.7 | 2.6 / 2.6 / 6.7 |
| grub (1-9 / 10-14) | 0.8 / 0.8 / 0.6 | | |
| herald (15-19) | 0.75 / 0.61 / 0.21 | | |

Also from docs/model.md "Objective value given the state, 2026-10-12": the value is the same whoever is ahead (objective x gold lead: nothing).
