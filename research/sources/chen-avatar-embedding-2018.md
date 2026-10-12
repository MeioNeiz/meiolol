---
title: 'Modeling Game Avatar Synergy and Opposition through Embedding in MOBA Games (2018)'
url: https://arxiv.org/pdf/1803.10402
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (model, outcome prediction experiment, human evaluation)
relevance: high
grade: B/fair
description: Chen et al. 2018 (Northeastern); bilinear hero embeddings for synergy and opposition (GAE) vs LR, GBDT and FM on 1-3M games each of Dota 2, HotS and HoN
---
# Modeling Game Avatar Synergy and Opposition through Embedding in MOBA Games (2018)

Why: how much do pairwise hero interactions (synergy, counters) add over additive hero
strength in draft-only prediction, at millions of games, and does GBDT beat them?

## Assessment

- Evidence: B. Three games, 1.1-3.1M matches each, 10-fold CV with paired t-tests,
  off-the-shelf baselines (scikit-learn LR, xgboost, fastFM) tuned on a validation fold.
  Same group as [[lol-skill-decomposition]].
- Reasoning: fair. Explains why FM and GAE should tie and they do; admits HoN anomaly.
  Random folds within a single patch, so no drift test.
- Interests: authors' own model, but they report FM tying it.
- Weigh: the cleanest published comparison of additive vs pairwise vs trees at
  millions of games; AUC gaps are trustworthy in direction, the absolute level is for
  one-patch random splits.

## Findings

- [method] Model: logit = sum of hero biases difference + within-team synergy pairs
  (bilinear a_i P a_j) + cross-team opposition pairs (a_i Q a_j); trained by AdaGrad on
  log loss. Eqn. 3, 5 ^f1
  > we propose to model a winning outcome as the linear breakdown of the individual biases, as well as their intrateam and inter-team interactions
- [method] [data] Data: HotS 1,814,066 matches (Dec 2016, hotslogs), HoN 1,101,046
  (Dec 2014 to Apr 2015), Dota 2 3,056,596 (11 Feb to 2 Mar 2016, Semenov et al.'s
  data, normal-skill subset); all ranked or matchmade 5v5 with no major game update in
  the window. Table 1, section Performance Evaluation (two-column text interleaves in
  raw, so no clean quote) ^f2
- [method] Split: 10-fold cross-validation, 8:1:1 train, validation, test; random
  folds, not time. AUC compared by paired t-test. ^f3
  > we adopt 10-fold cross-validation procedure with train:validate:test ratio set to be 8:1:1
- [method] Test AUC (Table 2). Dota 2: LR 0.6875, GBDT 0.7014, FM 0.7143, GAE 0.7143.
  HotS: LR 0.6095, GBDT 0.6375, FM 0.6440, GAE 0.6437. HoN: LR 0.6115, GBDT 0.6144, FM
  0.6154, GAE 0.6220. No accuracy or log loss reported. ^f4
- [method] Additive-only LR is worst in every game; pairwise interactions add 0.027
  AUC (Dota), 0.035 (HotS), 0.011 (HoN) at 1-3M games. ^f5
  > We observe that LR has the worst classification AUC in all three games.
- [method] GBDT, which can capture higher-order interactions, lands between LR and the
  pairwise models; higher-order structure did not help. ^f6
  > We also find advanced models such as Gradient Boosting Decision Trees (Friedman 2001) potentially considering more intricate relationships do not improve the match outcome prediction task on all the three datasets we study
- [method] FM and the embedding model tie on Dota and HotS: both factorise pairwise
  interactions, so the parameterisation matters less than having low-rank pair terms. ^f7
  > When GAE and FM are tuned with a proper number of latent space dimensions K, they achieve comparable AUC in HotS and DOTA2.
- [method] No player skill terms: they argue ranked matchmaking equalises skill, so
  draft-only is reasonable for their data. ^f8
  > Note that in our formulation, players’ individual skill levels are not accounted for in the winning outcome’s probability.
- [method] (inferred) Draft-only AUC differs a lot by game at similar data size: 0.71
  Dota, 0.64 HotS, 0.62 HoN. The ceiling is set by the game's balance, not the model;
  LoL ranked at 0.55 (ours) sits below all three. ^f9

## Read

- Abstract, related work, model, relation to FM, outcome prediction experiment, human
  evaluation, case study start

## Not read

- Pick recommender case study details, hyperparameters (K = 75 for Dota case study)
