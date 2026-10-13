---
title: 'CMU capstone 2024: Blue team wins in League of Legends (10-minute logistic)'
url: https://www.stat.cmu.edu/capstoneresearch/spring2024/460files/team17.pdf
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (whole report)
relevance: low
grade: D/weak
description: CMU stats undergraduate capstone (spring 2024); logistic regression on the Kaggle Diamond 10-minute dataset (~10k games) with gold diff, XP diff, kills, deaths
---
# CMU capstone 2024: Blue team wins in League of Legends (10-minute logistic)

Why: a baseline number for win prediction from a single early frame (minute 10), and
what a minimal feature set gets.

## Assessment

- Evidence: D. Student capstone, one public Kaggle dataset (~10k games, Diamond 1 to
  Master, minute 10 only), random 60/40 split, accuracy only.
- Reasoning: weak. Features dropped by assertion and by random-forest Gini importance;
  "RMSE 1.09" reported for a binary target; no log loss, AUC or calibration.
- Interests: none.
- Weigh: only the headline (about 73% at 10 minutes from gold and XP diff, gold alone
  about the same) is usable, as a sanity floor for our minute-10 accuracy.

## Findings

- [data] Data: Kaggle dataset of about 10k ranked Diamond 1 to Master games, 19
  features per team at the 10-minute mark; one frame per game, so no within-game
  leakage. Data ^f1
  > The dataset contains around 10k unique games with each game correlating to a gameID, 19 features per team
  > These games are all ranked soloqueue games in the Diamond 1 to Master ranks
- [method] Gold diff and XP diff dominate random-forest importance at minute 10; the
  per-team totals add nothing once diffs are in. Pre-processing ^f2
  > We immediately see that blueGoldDiff and blueExperienceDiff are far ahead the other ones.
- [method] Dragons, heralds, towers, wards and first blood dropped as unimportant at 10
  minutes (by assertion and low Gini importance, not by testing). Pre-processing ^f3
  > in the first ten minutes of the game, warding, elite monsters, dragons, and towers destroyed are not critical
- [method] Logistic regression on kills, deaths, gold diff, XP diff: 73.1% accuracy on a
  random 40% test split; gold diff alone 72.4%. Table 1 ^f4
  > the accuracy score of our original regression model (0.731) is higher than the accuracy score of the alternative model (0.724)
- [stats] Bootstrapped over games for 90% intervals on coefficients; kills' interval
  includes zero once gold diff is in (kills mostly act through gold). Quantifying
  Uncertainty ^f5
  > we use case bootstrapping (i.e., resampling of games) to find 90% confidence intervals for the coeﬀicient estimates of the logistic model.
  > the CI of blueKills ([-0.0015, 0.05]) contains zero
- [stats] Checked, not there: no draft, no other minutes, no log loss, AUC or
  calibration. ^f6
- [method] (inferred) A fair minute-10 floor for us: logistic on gold diff alone should
  reach about 72-73% in high Elo; lower Elo games are noisier, so expect a little less.
  Anything we build must beat gold-diff-only at each minute, not just overall. ^f7

## Read

- Whole report (10 pages)
