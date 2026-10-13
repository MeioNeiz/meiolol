---
title: 'TrueSkill 2: An improved Bayesian skill rating system (Minka, Cleven, Zaykov, MSR 2018)'
url: https://www.microsoft.com/en-us/research/uploads/prod/2018/03/trueskill2.pdf
kind: paper
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole paper)
relevance: high
grade: A/strong
description: Microsoft tech report; TrueSkill plus squad offsets, experience-biased skill drift, kill/death stats, quit penalty, base skill plus per-mode (or per-character) offsets; Halo 5 time-split test, 52% to 68%; runs Gears of War 4
---
# TrueSkill 2: An improved Bayesian skill rating system (Minka, Cleven, Zaykov, MSR 2018)

Why: the reference industrial skill model; which pre-game terms it adds, how it handles
per-mode or per-character skill, and what each term buys on held-out games.

## Assessment

- Evidence: A. Canonical reference (Minka, Herbrich lineage), shipped in Gears of War 4
  since 2016; Halo 5, 23M training games, next 3M as a time-split test.
- Reasoning: strong. Each term is motivated by a calibration table (actual vs expected
  win rate per subgroup) before and after; states costs and side effects (quit model
  rewards completing; over-penalises quits).
- Interests: Microsoft's own system; no outside comparison except classic TrueSkill.
- Weigh: the 52% to 68% headline mixes all terms, and Halo 5 squads (up to 10+ friends,
  89% win rate) are a far bigger effect than anything in LoL solo queue. No per-term
  accuracy ablation: the evidence per term is calibration, not accuracy. The
  per-character extension is a suggestion with no data.

## Findings

- [method] Classic TrueSkill: per-player Gaussian skill, performance = skill + noise,
  team performance = time-weighted sum; skill drifts per match and per unit of idle
  time; modes independent. ^f1
  > Each player has a latent skill value that represents their expected contribution to a team.
- [method] TrueSkill2's changes: kills and deaths inform skill, quits count as losses,
  skill in one mode borrows from others, drift biased upward early, squads perform
  better than their sum. ^f2
  > The random walk of player skill is assumed biased toward increasing skill, with larger bias during the first matches a player plays in a game mode.
- [stats] Held-out accuracy: classic TrueSkill 52%, TrueSkill2 68%, on 3M Halo 5 games
  played after a 23M-game training period, predicting from team composition and squad
  membership only. ^f3
  > After tuning model parameters on the training data, classic TrueSkill achieved a predictive accuracy of 52% on the test set. TrueSkill2 achieved a predictive accuracy of 68% on the test set.
  > When making this prediction, only the team composition and squad membership are used
- [method] Evaluation protocol: parameters tuned on the training period; test games
  processed once in start-time order, predict then update online with the result. ^f4
  > The matches in the test set were sorted by start time and processed once in order.
- [method] Model building is metric-driven: a term is added only when a subgroup's
  actual win rate departs from the model's expected win rate, and kept if it closes the
  gap. ^f5
  > The basic principle is that any change to the model must be motivated by a metric that demonstrates a gap between the model and reality.
- [stats] Squads: actual win rate rises with squad size (4: 57%, 8: 68%, 10+: 89%)
  while TrueSkill expected about 49-52%; a per-size offset fixes it. ^f6
  > The skill rating of a squad should be larger than the sum of its players, and the effect grows with the size of the squad.
- [stats] Experience: new players win 45% at 0 prior matches rising to 49% at 10+,
  while TrueSkill expected 48-49%; a per-match skill increment by experience count
  (capped at 200, 200 parameters per mode) fixes it. ^f7
  > These results suggest that players tend to increase in skill as they play the game, with the largest increases happening at the beginning.
  > where experienceOffset is an array of 200 tunable parameters per game mode.
- [stats] Previous-match kill rate predicts the next game: 43% win at the lowest band,
  59% at the highest, against TrueSkill's 48-50%; kills and deaths modelled as
  truncated Gaussians from performance, monotonic so incentives stay aligned. ^f8
  > The table below partitions players in the test set according to their kill rate in their previous match.
- [stats] Quitting the previous game: 45% next-game win after a quit win vs 51% after
  a completed win; the quit model fixes it but over-penalises slightly. ^f9
  > We see that TrueSkill2 lowers a player's skill rating after a quit, but a bit more than it should.
- [stats] Lapse (days since last game): win rate falls from 49% (under 1 day) to 43%
  (7-9 days); no lapse term needed, the experience term reproduced it. ^f10
  > Win rate decreases with lapse, and classic TrueSkill does not capture this.
  > However, once the experience effect was added in TrueSkill2, the correct trend with lapse emerged automatically
- [stats] Skill in two modes correlates 0.6; modelled as one base skill (drifting) times
  a per-mode weight plus a per-mode offset with its own experience drift. ^f11
  > The skill ratings are correlated, with correlation coefficient = 0.6.
  > The skill of player i in mode d at time t is denoted skilltid and is equal to the base skill plus an offset.
- [method] Once a player has many games in a mode, other modes barely move that mode's
  rating: the offset absorbs it (hierarchical shrinkage toward base skill). ^f12
  > A player's skill rating in a mode where many matches have already been played will not be affected by playing other modes.
- [method] Suggested, not measured: the same base-plus-offset scheme per character in
  LoL or Dota 2; beating a first-time pick should count less than beating a main. ^f13
  > Using the same mechanism as above, a player can be given a different skill rating with each character, and these can be correlated.
  > If you beat someone who is playing a character for the first time, you should not get the same rating change as beating their best character.
- [method] Deliberately excluded: features correlated with skill but gameable (time of
  day, who you queue with, opponent's skill via matchmaking), for incentive reasons. ^f14
  > From a purely statistical perspective, including these correlations in the model would give better skill estimates. But TrueSkill does not do this, because it would create undesirable incentives
- [stats] Halo 5 fitted values: new-player skill spread small (v0 = 1.6 with
  performance noise 1), skill drifts slowly, 10^5 minutes idle equals one match of
  drift. ^f15
  > v0 = 1.6 (skills of new players only vary by 1 from the mean)
- [method] Batch inference (TrueSkill Through Time, smoothing over all games) gives
  different and better orderings than online filtering; Gears 4 recomputes all skills
  and parameters in batch before each season. ^f16
  > But the most accurate skill ratings come from processing many matches together as a batch.
- [method] (inferred) For us: the paper's checks are cheap to run on our data before
  any model change: per bucket of (games on champion, days since last game, previous
  game result, rank) compare actual vs predicted win rate on test games. A bucket off
  by 2+ points is a missing term. ^f17
- [method] (inferred) Per-champion skill for us = player base + champion offset with
  a mastery-driven experience drift: the offset is shrunk to zero when games on the
  champion are few, which is our 74% (no earlier game on the champion in our data).
  Mastery points before the game stand in for the missing experience count. ^f18
- [method] (inferred) Its strongest terms do not transfer: LoL ranked solo/duo has at
  most duos (squad effect small), and in-game stats (kills) are post-game for the
  player but legitimately pre-game for the next game, like our win-rate history.
  Expect gains of a point or two, not 16. ^f19

## Read

- Whole paper: sections 1-13

## Not read

- Infer.NET model code (not published with the paper)
