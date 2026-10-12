---
title: Deep Learning for League of Legends Match Prediction (Hall, Penn State class report, 2017)
url: https://github.com/minihat/LoL-Match-Prediction/blob/master/FINAL%20REPORT.pdf
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full report)
relevance: medium
grade: D/weak
description: Class report (repo 51 stars) claiming 84.4% pre-game accuracy from players' last 20 ranked games on 1000 matches; history fetched after the fact, model picked on the test set
---
# Deep Learning for League of Legends Match Prediction (Hall, Penn State class report, 2017)

Why: an 80%+ pre-game claim from recent form (match history), without champion picks.

## Assessment

- Evidence: D. 1000 matches over two days (800 train, 200 test), one split, class report.
- Reasoning: weak. Excludes the predicted game, which is good, but tunes on test loss and
  reads one lucky architecture as a finding.
- Interests: none.
- Weigh: the result is noise or leakage. Useful as a recipe to avoid and for its one good
  habit (drop game Y from the history).

## Findings

- [data] Features: for each player, stats from their ranked history except the predicted
  game, averaged and summed per team into 9 engineered features. ^f1
  > Collect all of the statistics from player X’s ranked games, except for game Y.
- [data] History is each participant's last 20 ranked games, fetched later, for 1000
  matches from two days; 800 train, 200 test. ^f2
  > For each of these 1000 matches, statistics are collected for each participant’s last 20 ranked games.
- [method] Test accuracy on engineered features: 59.8%, 84.4% and 70.2% for three
  networks; raw features about 50%. ^f3
  > On engineered features, the testing accuracy reaches an impressive mean of 84.4% after convergence.
- [method] Dropout and batch norm were tuned for the best testing loss: model selection on
  the test set. ^f4
  > carefully tuned to achieve the best testing loss
- [method] (inferred) "Last 20 games" fetched after the fact can include games played
  after the predicted one (fetch date not given), so some features are post-game form
  (LP gained, tilt, rank moves). With 200 test games (about 3.5 points standard error)
  and architectures spanning 60-84%, the 84.4% is not credible. ^f5
- [method] Admits Riot's matchmaker sees the same history (yet concludes matchmaking is
  off, not that the result is). (inferred) Pre-game history features compete with MMR,
  which already summarises them; large gains are a red flag. ^f6
  > The matchmaking system used by Riot Games has access to the same (or more) information used to train this neural network.

## Read

- Whole report

## Not read

- The repo code
