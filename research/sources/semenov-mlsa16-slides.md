---
title: 'Applications of Machine Learning in DOTA2 (MLSA16 slides, Yashkov, Romov, Semenov et al.)'
url: https://dtai.cs.kuleuven.be/events/MLSA16/slides/05_Daniil_Yashkov.pdf
kind: talk
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (all slides)
relevance: medium
grade: B/weak
description: ECML MLSA 2016 workshop slides by the Semenov et al. (AIST 2016) group summarising draft-only Dota 2 prediction with xgboost, FM and LR by skill bracket, plus a Kaggle in-class contest
---
# Applications of Machine Learning in DOTA2 (MLSA16 slides, Yashkov, Romov, Semenov et al.)

Why: the Semenov et al. 2016 paper (draft-only Dota 2, FM vs GBDT vs LR by skill
bracket, millions of games) is paywalled (Springer CCIS 661); these slides are the
authors' own summary.

## Assessment

- Evidence: B. Authors of the paper whose 3M-game data [[chen-avatar-embedding-2018]]
  reused; but slides give only headline numbers.
- Reasoning: weak here (slides): no split, sample sizes or per-model table.
- Interests: none known.
- Weigh: trust the headline AUC range and the skill-bracket direction; for per-model
  numbers see secondary reports (Akhmedov 2021 lit review: AUC 0.70 xgboost, 0.68 LR
  and NB; skipped) or the paper itself.

## Findings

- [method] Features: one-hot hero picks per team (113 heroes); models xgboost,
  factorisation machines, logistic regression. ^f1
  > Features – 113 “hero” features for each team.
  > Factorization machines
- [method] Draft-only outcome prediction reached AUC 0.66 to 0.70 depending on skill
  bracket. ^f2
  > Game outcome prediction using drafts stage auc = 0.66 – 0.7 (depending on skill)
- [method] [draft] Picks explain less of the outcome at higher skill: about 6% of the
  Shannon information for very high skill games vs 10% at normal skill. ^f3
  > Set of picked heroes explains at least
  > 6% of information(Shannon) for very high skill players
  > 10% of information for normal skill
- [method] In their Kaggle in-class contest (650 entrants, first 5 minutes of play),
  the winning solution used logistic regression over more complex models, with one-hot
  picks plus carefully selected hero pairs and triples. ^f4
  > Use Logistic Regression instead of more complex models (e.g. Random Forest, GBDT)
  > Often combinations of heroes in the team: pairs and triples (need to be accurately selected, easy to overfit)
- [method] (inferred) If "information explained" is the relative drop in log loss
  versus a coin flip (1 bit), 6-10% means draft-only log loss of about 0.62-0.65 nats
  in Dota 2; LoL ranked at AUC 0.55 explains well under 1%. ^f5

## Read

- All slides

## Not read

- The AIST 2016 paper itself (paywalled): split type, data size per bracket, FM vs
  xgboost table
