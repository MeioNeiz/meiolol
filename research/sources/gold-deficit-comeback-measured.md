---
title: 'Gold deficits and comebacks by game time in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=gold-deficit-comeback-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Win rate of the team behind by gold deficit at 10-35 minutes in 240k ranked solo timelines (lab snapshot 13 Oct, 16.19-16.20, test games left out), how 5k leads move over the next 5 minutes, and the lab's gold lead weight by minute
---
# Gold deficits and comebacks by game time in ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-down-5000-gold]]: how often 5,000 gold behind comes back, and
whether a lead's value shrinks with game time.

## Assessment

- Evidence: A. 239,629 ranked solo games with timelines (every platform, Platinum IV+),
  Riot's per-minute frames; 20,888 games 4.5-5.5k behind at 15 minutes, 20,677 at 20.
  The per-1000-gold weight is the lab's earlier held-out EUW regression.
- Reasoning: fair. Method: at minute m, games still going, team gold lead from the frame;
  the behind team's eventual win rate by deficit band. Limits: games that ended before m
  drop out (stomps, surrenders), so later minutes are a survivor sample; gold only,
  towers and dragons not held fixed; "lead shrank" is partly the comeback itself, so
  that split describes, not predicts.
- Interests: none.
- Weigh: no split by rank or role.

## Findings

- [data] Teams 4.5-5.5k gold behind win 7.2% at 10 minutes, 13.0% at 15, 15.2% at 20, 16.0% at 25, 17.4% at 30 and 21.3% at 35. ^f1
  > | 4.5-5.5k | 7.2% (6217) | 13.0% (20888) | 15.2% (20677) | 16.0% (16934) | 17.4% (10267) | 21.3% (4047) |
- [data] The same deficit costs less later: 1.5-2.5k behind wins 27.5% at 10 minutes and 38.5% at 35; in the lab's model 1000 gold of lead is worth 0.345 log-odds at 10 minutes and 0.125 at 30. ^f2
  > | 1.5-2.5k | 27.5% (55312) | 32.1% (40241) | 33.7% (29420) | 34.1% (21056) | 35.1% (13099) | 38.5% (6243) |
  > | 1000 gold lead, log-odds | 0.345 | 0.253 | 0.216 | 0.161 | 0.125 |
- [data] Part of that is scale: total gold in the game is 57.0k at 15 minutes and 125.2k at 30, so 5k is a smaller share later. ^f3
  > - 15 min: 57.0k
  > - 30 min: 125.2k
- [data] Leads mostly grow: of teams 4.5-5.5k ahead at 15 minutes, the lead was smaller five minutes later in only 32% (median +1.34k); from 25 minutes, 47%. ^f4
  > | 15 | 18565 | 32% | 29.5% (5880) | 7.6% (12685) | +1.34 |
  > | 25 | 10234 | 47% | 42.9% (4822) | 8.7% (5412) | +0.27 |
- [data] When a 5k lead held or grew over five minutes, the behind team won 5-9%; when it shrank, 23-43%. ^f5
  > | 10 | 6134 | 11% | 22.8% (703) | 5.3% (5431) | +2.97 |
  > | 20 | 17685 | 38% | 35.5% (6666) | 6.9% (11019) | +1.07 |

## Read

- `raw/gold-deficit-comeback-measured.md`: all
