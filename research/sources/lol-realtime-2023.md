---
title: 'Junior and Campelo 2023: League of Legends real-time result prediction'
url: https://arxiv.org/pdf/2309.02449
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (whole paper)
relevance: medium
grade: C/weak
description: UFCG (Brazil) 2023 paper; 64.6k Iron to Diamond ranked games from match-v5 timelines, team totals (kills, dragons by type, towers, gold, CS, level) at 20/40/60/80% of game length; eight classifiers compared
---
# Junior and Campelo 2023: League of Legends real-time result prediction

Why: the nearest published match to our data (match-v5 ranked timelines, Iron to
Diamond) with a model bake-off (LR, GBDTs, RF, MLP) at several game stages.

## Assessment

- Evidence: C. One dataset (published on Zenodo), cross-validation, accuracy and AUC
  per stage; no calibration, no log loss.
- Reasoning: weak. Stages are fractions of the final game length, which is not known
  live; "cross-validation" unstated whether by game; feature choice by correlation.
- Interests: none (mentions betting as motivation).
- Weigh: the model ranking (all GBDTs and LR within about 1 point; MLP worst) is
  plausible and useful; the stage numbers are inflated by the known-length leak.

## Findings

- [data] Data: 64,556 ranked games, Iron to Diamond, January to May 2023, from the Riot
  API; games under 5 minutes dropped as remakes. Sections IV-B, IV-C ^f1
  > ranging from Iron to Diamond elo. The 64,556 collected matches provide a comprehensive and diverse view of the competitive landscape during the period from January 12, 2023, to May 18, 2023.
- [method] [data] Snapshots at a percentage of the final game length (20, 40, 60, 80%),
  not at a clock minute: at prediction time the length is unknown, so this leaks the
  outcome-correlated duration. Section IV-C ^f2
  > The dataset was then divided into four scenarios, representing different percentages of the total match duration: 20% PET (Percent Elapsed Time), 40% PET, 60% PET, and 80% PET.
- [method] Features: per team kills, first blood, dragons by type (incl. elder), herald,
  baron, towers, inhibitors, total gold, lane and jungle CS, mean level (Table VI);
  no draft, no timers, no gold diff. Table VI ^f3
  > Table VI presents the variables that were taken into account in the construction of prediction models
- [method] Eight models; LR best at 20% (accuracy 0.623), LightGBM best at 40-80%
  (0.854 at 80%, LR 0.848); all GBDTs and RF within about a point of each other, the
  MLP far behind (0.734 at 80%). Section V, Table VII ^f4
  > When considering 20% of the elapsed time, the standout models were Logistic Regression, followed by Gradient Boosting and XGBoost.
  > Finally, reaching 80% of the elapsed time, LightGBM once again demonstrated the best accuracy
- [method] Random search tuning on LightGBM and RF moved accuracy by a few tenths of a
  point at most (LightGBM 0.6189 vs 0.6164 at 20%). Table VIII ^f5
  > Table VIII presents the accuracy rates achieved through the application of the hyperparameter search technique known as Random Search on the LightGBM and Random Forest models.
- [method] Signal by stage (random-forest importance): total gold leads at every stage;
  dragon and tower correlations with the win grow with the stage (dragons 0.16 at 40%
  to 0.43 at 80%). Section V, Tables III-V ^f6
  > at 20% of the elapsed time, the most important variable for predicting the victory of the blue team was redTotalGold.
  > At 40% PET scenario, the variable ”blueTotalGold” became the most relevant
- [method] Authors leave a time-series (sequence) model as future work. Section VI ^f7
  > An interesting perspective for future work is to address the challenge of predicting the outcomes of League of Legends matches as a time series.
- [stats] Checked, not there: no calibration, log loss or Brier; no per-minute
  results; no statement that folds group frames by game (one snapshot per game per
  stage, so likely fine). ^f8
- [method] (inferred) On match-v5 team aggregates, model family barely matters (GBDT vs
  LR within a point); gains must come from features (diffs, timers, draft) and from
  evaluating at clock minutes. ^f9

## Read

- Whole paper (8 pages); Table VII read from the column order in raw
