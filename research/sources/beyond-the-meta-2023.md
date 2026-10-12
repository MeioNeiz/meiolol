---
title: 'Beyond the Meta: Leveraging Game Design Parameters for Patch-Agnostic Esport Analytics (2023)'
url: https://arxiv.org/pdf/2305.18477
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: skimmed (abstract, related work, data and split)
relevance: low
grade: C/fair
description: University of York (Drachen group) arXiv 2023; replaces one-hot hero ids with clustered ability features from patch notes so a Dota 2 model survives new patches; predicts kills, not wins
---
# Beyond the Meta: Leveraging Game Design Parameters for Patch-Agnostic Esport Analytics (2023)

Why: patch drift in draft models; also its related work reports Semenov et al. 2016's
per-skill-bracket numbers, which we could not read (paywalled).

## Assessment

- Evidence: C. Preprint; 61,254 pro and premium matches, patches 7.27-7.33; target is
  kill count, so its own numbers do not bear on win prediction.
- Reasoning: fair on the patch problem.
- Interests: none known.
- Weigh: use for the patch-drift argument and as a secondary report of Semenov.

## Findings

- [method] Secondary report of Semenov et al.: draft-only accuracy falls as skill
  rises, from about 71% (FM, normal skill) to about 64% (naive Bayes, very high skill);
  heroes encoded +1 Radiant, -1 Dire. ^f1
  > the higher the player rank, the harder it is to predict the winner based on character selection alone
  > ranged from approximately 71% (Factorization Machines classifier for normal skill level) to approximately 64% (Naive Bayes for very high skill matches)
- [method] [data] Esports analytics papers mostly use short windows to dodge patch
  changes; one-hot hero ids break with new heroes and meta shifts. ^f2
  > much of the esport literature is done focusing on a limited periods of time, to reduce the impact of those changes
- [method] Their test: train on patches 7.27-7.31 (random 64/16/20 split), hold out
  7.32 (new hero) and 7.33 (new attribute type) entirely as out-of-patch tests. ^f3
  > All matches for patches 7.32 & 7.33 were excluded from the training set to be used as special test comparisons.

## Read

- Abstract, introduction, related work, data collection, split

## Not read

- Clustering method, kill-prediction results
