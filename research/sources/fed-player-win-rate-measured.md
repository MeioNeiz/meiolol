---
title: 'Fed players and their team: win rates in ranked solo (our measurement, 2026-10-20)'
url: https://meio.lol/?measured=fed-player-win-rate-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: high
grade: A/fair
description: Win rate of players 1000+ gold ahead of their lane opponent at 14:00, split by where the other four stood, by role, in 65k ranked solo games of 16.19-16.20 (local snapshot); end-of-game top gold and kills; the lab's gold value by role
---
# Fed players and their team: win rates in ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-carry-when-fed]]: how often does a fed player lose because the
rest of the team is behind?

## Assessment

- Evidence: A. 65,240 ranked solo games of 15:00+ (85,693 in the snapshot; every
  region, Platinum IV+), 142,734 player-games 1000+ gold ahead of their lane opponent at
  14:00. The per-role gold value is the lab's held-out result (10,604 EUW games).
- Reasoning: fair. Method: lane lead = own gold at 14:00 minus the same position's
  opponent's; rest of team = team gold lead minus that lane lead; win rate per band.
  Limits: association; the end-of-game rows are mostly a result of winning (winners
  pile up late kills and gold), so they describe, not test.
- Interests: none.
- Weigh: "fed" as 1000 gold at 14:00 is our cut; the video doesn't define it.

## Findings

- [data] A player 1000+ gold ahead of their lane opponent at 14:00 wins 68.6%. ^f1
  > | all 1000+ ahead | 142734 | 68.6% |
- [data] In 42% of those games the other four are behind, and then the fed player wins 47.3%: a coin flip. ^f2
  > | all 1000+ ahead, rest of team behind | 59796 | 47.3% |
- [data] The rest of the team decides most of it: fed with the other four 3000+ behind wins 27.6%, with them 1500+ ahead 89.1%. ^f3
  > | 3000+ behind | 16328 | 27.6% |
  > | 1500+ ahead | 56450 | 89.1% |
- [data] Fed with the team behind, bot laners win 50.4%, mid 49.0%, jungle 48.3%, top 44.6%, supports 39.4%. ^f4
  > | BOTTOM | 35520 | 70.2% | 50.4% | 14808 |
  > | TOP | 36004 | 64.6% | 44.6% | 17476 |
  > | UTILITY | 14101 | 70.6% | 39.4% | 3695 |
- [data] At the end, the player with the most gold in the game wins 86.9% and the top killer 85.8%; 10+ kills with 3 or fewer deaths, 96.0% (mostly the result of winning). ^f5
  > | most gold in the game | 65221 | 86.9% |
  > | 10+ kills and at most 3 deaths | 30065 | 96.0% |
- [data] What 1000 gold on one player is worth depends on the role (15 minutes: about 8 points for bot, 4.5-7 for top, jungle and mid, 0 for support), and no champion converts its own lead better than others in its role. ^f6
  > what 1,000 gold on your champion is worth depends on the role, at 15 minutes about 8 percentage points for the bot laner, 4.5-7 for top, jungle and mid and about 0 for the support

## Read

- `raw/fed-player-win-rate-measured.md`: all
