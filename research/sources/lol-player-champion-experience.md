---
title: Using ML to Predict Game Outcomes Based on Player-Champion Experience in LoL (Do et al., FDG 2021)
url: https://arxiv.org/pdf/2108.02799
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full 5-page paper)
relevance: high
grade: D/weak
description: FDG 2021 short paper claiming 75.1% pre-game accuracy on 5000 NA ranked games from mastery and season champion win rate; features appear to include the predicted game
---
# Using ML to Predict Game Outcomes Based on Player-Champion Experience in LoL (Do et al., FDG 2021)

Why: the most cited "75% pre-game" LoL claim; is it real, and which player features carry
it? Earlier skipped as covered by [[lol-skill-decomposition]]; reopened for the leakage
check.

## Assessment

- Evidence: D. 5000 games, NA 2020, random 80/20 split, short peer-reviewed paper; no
  time split, no log loss or calibration, no leakage discussion.
- Reasoning: weak on validity. Feature timing is never stated; the result is 15 points
  above every other pre-game LoL result it cites (55-60%) without asking why.
- Interests: none known.
- Weigh: treat 75% as leakage until shown otherwise. Useful as a worked example of the
  trap: season stats and mastery read after the game include the game.

## Findings

- [method] Headline: 75.1% accuracy (DNN) from player-champion experience after all
  picks; GBOOST 75.4%, RF 74.7%, SVC 74.3%. ^f1
  > game outcomes can be predicted with 75.1% accuracy after all players have selected champions
- [method] It says most pre-match LoL predictors land around 55-60%. ^f2
  > the majority of these pre-match predictors have an accuracy around 55-60%
- [data] Sampling: random players, each one's most recent ranked match, 5000 unique
  matches, NA, Iron to Diamond 2020. ^f3
  > we used this API to query random players and filter their most recent ranked match
- [data] [method] Features: mastery points, the player's ranked win rate on that champion
  over the 2020 season, season games on it, and recent games on it among the last 20. ^f4
  > Player-champion win rate - A percentage (0.0 to 1.0) indicating the player’s victory ratio for ranked games played on the given champion during the 2020 ranked season.
- [method] Only win rate and mastery correlated with outcome; games played (season and
  recent) had none and hurt the models. ^f5
  > player-champion win rate and champion mastery points were the only features that correlated with the outcome of a match
- [method] Checked, not there: no statement that the season win rate or mastery were
  taken before the predicted match or exclude it; the match is each player's latest, so
  stats pulled afterwards contain it. ^f6
- [method] (inferred) That is label leakage: a player with few season games on the
  champion has a win rate that largely is this game's result (1 game: exactly it). Season
  games mean 58.95, but the low-count players dominate the signal. The 75% is not a
  pre-game number. ^f7
- [method] Split: random 80/20 with stratified 10-fold, no time split. ^f8
  > 80% of the matches (4000 matches) were randomly chosen, while the other 20% (1000 matches) were chosen for the testing dataset
- [data] (inferred) Riot API needs per player: champion-mastery-v4 (points, a current
  snapshot only) and a season champion win rate, which Riot does not serve directly: it
  means crawling that player's match-v5 history and counting games before the game time. ^f9

## Read

- Whole paper (abstract, related work, dataset, features, models, results, conclusion)

## Not read

- References [20, 24] (other pre-match LoL predictors in the 55-60% range)
