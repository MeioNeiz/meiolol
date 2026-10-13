---
title: 'Beyond the Meta: Leveraging Game Design Parameters for Patch-Agnostic Esport Analytics (2023)'
url: https://arxiv.org/pdf/2305.18477
kind: paper
commit:
for: [draft-predictor-methods, comp-attribute-features]
looked: 2026-10-13
depth: docs (abstract, related work, method, results, discussion)
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
- Weigh: use for the patch-drift argument and as a secondary report of Semenov. Its
  feature result is over a hero-id baseline stuck at AUC 0.50, so it says nothing about
  attribute features adding to ids.

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

- [method] Ability features: K-means (K=68, elbow plus silhouette) over standardised
  ability properties from OpenDota's dotaconstants (abilities.json, heroes.json) plus hero
  attributes; a hero is the sum of one-hot cluster vectors of its abilities, a team the
  sum of its heroes. ^f4
  > one character can then be represented by adding all of the K-long vectors of their abilities
  > The individual character vectors for a team's selection is added together collapsing it into one K-long vector.
- [method] Three networks, all with match duration as input: NN1 duration only, NN2 plus
  one-hot hero ids, NN3 plus team ability-cluster sums; target is each team's kills, not
  win. ^f5
  > These models attempts to predict the number of kills (also referred to as the score) for each team at the end of the match.
- [method] Table 2, kills AUC: NN1 0.50, NN2 0.50 (0.49 on 7.32 and 7.33), NN3 0.85
  (0.85, 0.86). Split sizes: train 27,171, validation 6,793, test 8,491, 7.32 16,564,
  7.33 2,235. (Table text interleaved in raw; read from the layout.) ^f6
- [method] The hero-id baseline learnt nothing: NN1 and NN2 gave near-identical outputs,
  and the authors conjecture NN2 ignored the lineup. So the 0.35 AUC gap is over a failed
  baseline, not over a working hero-id model. ^f7
  > Thus, it is conjectured that (NN2) trained in a way to put very little significance for the lineup vectors, instead having more significant weights around the duration feature.
  > (NN1) and (NN2) produced a relatively flat training AUC graph
- [method] (inferred) Sigmoid activations through 6 hidden layers, batch size 1, no
  regularisation, kills regression: more likely a training failure on the sparse one-hot
  input than evidence that ability features beat ids. ^f8
  > No dropout layers or regularizer were used.
- [method] Checked, not there: no win-prediction result, no hero-id plus ability-feature
  model (ability clusters replace ids, never added), no explicit within-team non-additive
  or cross-team interaction terms, no log loss or accuracy. ^f9

## Read

- Abstract, introduction, related work, data collection, split, data processing,
  clustering, networks, results (Tables 1-2), discussion

## Not read

- Appendix figures (loss curves); released CSVs
