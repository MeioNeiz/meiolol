# Gold deficits and comebacks by game time (our measurement, 2026-10-20)

## Method

Lab snapshot snap-20261013T2253Z on the gpu-box (ranked solo, patches 16.19-16.20, every platform), per-minute state export (state/minute.f32: Riot's frame at m:00, team gold lead blue minus red), games with a 10-player timeline, test games left out. A game counts at minute m only while still going. The behind team's win rate is pooled over both sides (a game counts once, for whichever team is behind). Script: lead.py (scratchpad).

Limits: games still going at m only, so later minutes leave out games that ended (stomps and surrenders) before m. Gold lead only: the behind team may also be behind in towers, dragons and levels, which this table does not hold fixed. Description, not cause.

games with a timeline, test games left out: 239629

Win rate of the team behind, by its gold deficit (thousands) at the minute; games still going

| deficit | 10 min | 15 min | 20 min | 25 min | 30 min | 35 min |
| --- | --- | --- | --- | --- | --- | --- |
| 0.5-1.5k | 38.2% (78815) | 41.1% (46949) | 41.6% (31664) | 42.3% (21654) | 42.6% (13658) | 43.9% (6549) |
| 1.5-2.5k | 27.5% (55312) | 32.1% (40241) | 33.7% (29420) | 34.1% (21056) | 35.1% (13099) | 38.5% (6243) |
| 2.5-3.5k | 18.4% (32632) | 24.7% (33796) | 26.6% (26466) | 27.0% (19506) | 28.4% (12446) | 30.4% (5468) |
| 3.5-4.5k | 11.9% (16092) | 18.0% (27137) | 20.6% (23837) | 20.7% (18073) | 22.8% (11513) | 27.3% (4684) |
| 4.5-5.5k | 7.2% (6217) | 13.0% (20888) | 15.2% (20677) | 16.0% (16934) | 17.4% (10267) | 21.3% (4047) |
| 5.5-6.5k | 4.3% (2120) | 8.7% (15073) | 11.3% (17529) | 11.4% (15050) | 13.4% (8873) | 17.1% (3120) |
| 6.5-8k | 1.9% (682) | 5.5% (14546) | 7.9% (19336) | 7.6% (18876) | 9.5% (10778) | 13.5% (3261) |
| 8-10k | 1.2% (85) | 2.4% (8897) | 4.0% (16313) | 4.5% (18164) | 4.8% (9395) | 8.9% (2377) |
| 10-99k | - (5) | 0.8% (3918) | 1.3% (14800) | 1.3% (18804) | 2.1% (7487) | 3.5% (1401) |

Teams 4.5-5.5k ahead at minute m and still playing at m+5: how the lead moved, and the behind team's win rate

| minute m | games | lead smaller at m+5 | behind team won, lead shrank | behind team won, lead held or grew | median lead change (k) |
| --- | --- | --- | --- | --- | --- |
| 10 | 6134 | 11% | 22.8% (703) | 5.3% (5431) | +2.97 |
| 15 | 18565 | 32% | 29.5% (5880) | 7.6% (12685) | +1.34 |
| 20 | 17685 | 38% | 35.5% (6666) | 6.9% (11019) | +1.07 |
| 25 | 10234 | 47% | 42.9% (4822) | 8.7% (5412) | +0.27 |

Total gold in the game at the minute (both teams, median, k), for scale

- 10 min: 35.9k
- 15 min: 57.0k
- 20 min: 80.0k
- 25 min: 102.7k
- 30 min: 125.2k
- 35 min: 147.6k

## Existing result, copied from docs/model.md "Objective value given the state, 2026-10-12" (EUW, 16.19-16.20)

Logistic regression per minute of blue's win on the gold and XP lead and objectives held; the weight of a 1000 gold lead in log-odds:

| held (one more than the enemy) | 10 min | 15 min | 20 min | 25 min | 30 min |
| --- | --- | --- | --- | --- | --- |
| 1000 gold lead, log-odds | 0.345 | 0.253 | 0.216 | 0.161 | 0.125 |
