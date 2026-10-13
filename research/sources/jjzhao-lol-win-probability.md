---
title: 'jjzhao05/LoL-Win-Probability: LR vs XGBoost per-minute win probability on ranked NA timelines'
url: https://github.com/jjzhao05/LoL-Win-Probability
kind: project
commit: b364e1db02e481ffaab0da11270740a1ae0a62a1
for: [live-win-probability]
looked: 2026-10-13
depth: code (README, results/minute_bucket_breakdown.csv, common.py, xgboost_engineering.py)
relevance: high
grade: C/fair
description: Student project (2026) on 9,596 NA ranked match-v5 timelines (296k minute frames, Iron to Challenger); LR and XGBoost on team and role diffs plus 3-minute deltas; match-level split; AUC, log loss, Brier by minute band; ablations with match-level bootstrap
---
# jjzhao05/LoL-Win-Probability: LR vs XGBoost per-minute win probability on ranked NA timelines

Why: the only source found with log loss and Brier per minute band on ranked match-v5
timelines (our exact data), with a game-level split and LR vs GBDT head to head.

## Assessment

- Evidence: C. One author, 0 stars, created July 2026; 9.6k games, one patch, NA only;
  but results files are committed and the split code is visible.
- Reasoning: fair. Match-level split, bootstrap intervals by match, ablations, metrics
  by minute; no draft, no timers.
- Interests: none.
- Weigh: trust the per-minute shape and the LR-equals-XGBoost result at this size; at
  our 230k games a GBDT may pull ahead, so re-measure.

## Findings

- [data] Data: 9,596 ranked solo/duo NA games, 295,852 per-minute snapshots, single
  patch, Iron to Challenger. README ^f1
  > A logistic regression baseline and an XGBoost ensemble were trained on 9,596 ranked solo/duo NA matches (295,852 per-minute snapshots, single patch, Iron through Challenger)
- [data] [stats] Split by match id (80/20), so a game's frames never cross train and
  test. `common.py` load_or_create_split ^f2
  > """Match-id-level train/test split, cached to SPLIT_FILE."""
- [method] Features: blue minus red diffs (team gold, XP, level, CS, damage, per-role
  stats, dragons, heralds, barons, towers by group, inhibitors by lane, first blood,
  first tower) plus a 3-minute change of each diff, a cheap stand-in for a sequence
  model. `xgboost_engineering.py` add_momentum_features ^f3
  > """3-minute momentum deltas, excluding event flags and per-part
  > (pl.col(c) - pl.col(c).shift(3).over("match_id"))
- [method] LR and XGBoost tie overall: AUC 0.817 vs 0.816, Brier 0.173 vs 0.174.
  README ^f4
  > | Logistic Regression | 0.817 | 72.4% | 0.173 |
  > | XGBoost | 0.816 | 72.3% | 0.174 |
- [stats] By minute band (XGBoost): AUC 0.629 / log loss 0.667 / Brier 0.237 at 1-5;
  0.733 / 0.604 at 6-10; 0.823 / 0.515 at 11-15; 0.862 / 0.461 at 16-20; 0.905 / 0.388
  at 21-25; 0.909 / 0.381 at 26-30; 0.866 / 0.455 at 31-45. LR within 0.02 everywhere
  and better at 31-45 (AUC 0.884). `results/minute_bucket_breakdown.csv` ^f5
  > XGBoost,1-5,9600,0.629,0.6669,0.587,0.2372
  > XGBoost,11-15,9600,0.8226,0.5149,0.7412,0.1721
  > XGBoost,21-25,8232,0.9054,0.3879,0.8166,0.1254
  > XGBoost,31-45,4771,0.8664,0.4552,0.7759,0.1505
  > LogisticRegression,31-45,4771,0.8835,0.426,0.7927,0.1401
- [method] Economy (gold, XP, levels) alone keeps 99% of full-model AUC, objectives
  alone 94%; objectives matter most in close games and at high ranks. README ^f6
  > Economy is the more complete standalone signal, retaining 99% of full-model AUC alone. Objectives alone retain 94%, indicating they are not merely a proxy for economic state.
  > Stratifying by gold-difference magnitude, an objectives-only model retains 89.5% of full-model AUC in close games versus 99.6% in blowouts.
- [stats] Late band dips (31-45 minutes): fewer, unusually even games. README ^f7
  > before a slight decline in the 31-45 minute bucket (a smaller, atypical sample of unusually even games).
- [method] Checked, not there: no draft or champion features, no buff or respawn
  timers, no sequence model. ^f8
- [method] (inferred) These per-band numbers are the bar for our minute model without
  draft: log loss about 0.67 at minutes 1-5, 0.52 at 11-15, 0.39 at 21-25. A draft
  term should help most in the 1-10 band, where the state model is near 0.6-0.67. ^f9

## Read

- README, results by minute band, split function, feature engineering

## Not read

- report.pdf, ablation code and CIs (results/ablation_bootstrap_cis.csv)
