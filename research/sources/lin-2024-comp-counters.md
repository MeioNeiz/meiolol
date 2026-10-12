---
title: Identifying and Clustering Counter Relationships of Team Compositions in PvP Games (Lin et al., TMLR 2024)
url: https://arxiv.org/pdf/2408.17180
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (sections 4.1-4.2, Tables 1-2 and their discussion)
relevance: medium
grade: B/fair
description: TMLR 2024; compares additive Bradley-Terry with neural counter models for composition win prediction in six games incl. 182k LoL solo games, where only the additive model beats chance on held-out folds
---
# Identifying and Clustering Counter Relationships of Team Compositions in PvP Games (Lin et al., TMLR 2024)

Why: does a non-additive (counter-aware) composition model beat an additive champion
rating on held-out LoL games?

## Assessment

- Evidence: B. Peer-reviewed (TMLR), six games, 5-fold CV; LoL is a side dataset.
- Reasoning: fair. Discusses LoL's overfitting honestly; metric is their own (strength
  relation classification), close to but not exactly match accuracy.
- Interests: none (they propose the neural counter table, which loses on LoL).
- Weigh: old Kaggle data (136 champions, so about 2014-2017, many patches pooled, no
  roles, no patch feature); trust the direction (additive wins at ~180k), not the levels.

## Findings

- [data] LoL data: Kaggle "League of Legends Ranked Matches", 182,527 ranked solo games, 136 champions; almost every composition is unique. ^f1
  > The dataset covers 182,527 ranked solo games with
  > 348,498 unique compositions observed, which implies that almost all compositions are different.
- [stats] Evaluation: 5-fold cross-validation (random, not by time), neural approximators trained 100 epochs with Adam. ^f2
  > 5-fold cross-validation. A linear decay learning rate from 0.00025 to 0 over 100 epochs with the Adam
- [method] BT is additive: a composition's rating is the sum of its champions' ratings. ^f3
  > rating of a composition can be derived from the sum of the element ratings within the composition.
- [method] On LoL test folds only additive BT beats chance (53.6%); per-composition win value, pairwise win, neural rating and the neural counter table score 50.9-51.1% while reaching 79-91% on training folds (Table 1). ^f4
  > Accuracies (%) in training (above) and testing (below) for various games
- [method] [stats] The authors read LoL as overfitting: draft counter-picking and the huge composition space make unseen matchups hard; more games needed. ^f5
  > clear overfitting, such as in League of Legends, it suggests the need for more match results to generalize
  > This increases the difficulty of win rate prediction for unobserved cases.
- [method] (inferred) Same pattern as [[jcj-lol-draft#^f2]] at a similar size: an additive champion model is the honest baseline that flexible models fail to beat below a few hundred thousand games. ^f6

## Read

- Sections 4.1.7, 4.2, Tables 1-2 and the LoL discussion.

## Not read

- Method details (vector quantization, codebook), other games' results, appendix A.4.
