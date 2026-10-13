---
title: 'Au, Herbinger, Stachl, Bischl, Casalicchio 2022: Grouped feature importance and combined features effect plot'
url: https://arxiv.org/pdf/2104.11688
kind: paper
commit: 
for: [correlated-importance]
looked: 2026-10-13
depth: docs (1-3, 6; 4-5 not read)
relevance: high
grade: B/strong
description: Data Mining and Knowledge Discovery 2022 (arXiv 2104.11688, LMU Munich); defines grouped permutation (GPFI, GOPFI), grouped refit (LOGO drop a group, LOGI group alone vs null) and grouped Shapley importance (GSI), compares them in simulations with dependent groups, varying within-group correlation and group sizes
---
# Au, Herbinger, Stachl, Bischl, Casalicchio 2022: Grouped feature importance and combined features effect plot

Why: the menu of grouped importance measures (permute vs refit, vs full model vs null
model, Shapley over groups) and when each misleads.

## Assessment

- Evidence: B. Peer-reviewed journal, same LMU group as
  [[molnar-2023-conditional-subgroup]]; small simulations (n=1000, 3-4 groups of 10
  features, SVM and random forest, 10-fold CV or 20 repeats), one psychology dataset.
- Reasoning: strong. Clear definitions, each recommendation tied to a scenario, and
  they admit that varying within-group correlation defeats all methods.
- Interests: none beyond their methods.
- Weigh: trust the taxonomy and the permute-vs-refit result for correlated groups. The
  simulations are tiny and synthetic; magnitudes do not transfer.

## Findings

- [method] Four grouped measures: GPFI (permute the group, others kept: its
  contribution with all others present), GOPFI (permute everything except the group:
  its contribution alone), LOGO (refit without the group), LOGI (refit with only the
  group, vs a null model). Sections 2.2-2.3 ^f1
  > The GPFI measures the contribution of one group to the model’s performance if all other groups are present in the model
  > LOGI(G) = E(L(fˆnull , Y )) − E(L(fˆD̊ (XG ), Y )).
- [method] Grouped Shapley importance (GSI): Shapley over groups with LOGI (refit) or
  GOPFI (permute) as the value function; it shares interaction credit between groups;
  single-feature Shapley scores add up to it when there are no higher-order
  interactions between groups. Sections 2.4, 6 ^f2
  > GSI scores account for feature interactions as they measure the average contribution of a given group to all possible combinations of groups and fairly distribute the importance value caused by interaction values among all groups.
  > single feature Shapley importance scores add up to GSI when no higher-order interactions between groups are present
- [method] [stats] Two near-copy groups: permutation methods gave both the same high
  importance; LOGO gave both near zero, revealing that they are interchangeable.
  Section 3.1 ^f3
  > The refitting methods highlight that G1 and G2 are more or less interchangeable, hence do not complement each other.
- [method] Recommendation: with correlated groups, prefer refitting; with few groups,
  refitting is affordable. Section 6 ^f4
  > If high correlations between groups are present, refitting methods should be preferred over permutation methods since they often deliver more meaningful results in these scenarios.
- [method] [stats] When within-group correlation differs across groups, all methods
  misstate group importance (equal true importance; the weakly correlated group scored
  under half of the strongly correlated one for permutation), worse with random
  forests. Sections 3.2, 6 ^f5
  > G3 is on average less than half as important as G1 for permutation-based methods. Thus, none of the methods reflect the underlying true importance of the different groups.
- [method] Larger groups tend to score higher; normalising per feature has its own
  problems. Section 6 ^f6
  > Groups with many features might tend to have a higher grouped importance score than groups with fewer features.
- [method] (inferred) For us: report both LOGO ("what is lost without economy, given
  towers, dragons, draft") and LOGI ("economy alone vs base rate") per minute; with ~6
  groups exact refit GSI is 64 fits per minute bucket, and it sums to the full model's
  skill. Keep groups similar in size and give each one or two summary features (gold
  lead rather than 10 per-player golds), or the size bias of ^f6 decides the ranking. ^f7

## Read

- Sections 1-3 (definitions, simulations) and 6 (conclusion).

## Not read

- Section 2.5 algorithm detail, Section 4 (combined features effect plot), Section 5
  (smartphone application).
