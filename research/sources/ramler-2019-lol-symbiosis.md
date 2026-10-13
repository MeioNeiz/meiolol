---
title: 'Ramler, Lee, Schuckers 2019: Identifying symbiotic relationships between champions in League of Legends'
url: https://ww2.amstat.org/meetings/proceedings/2019/data/assets/pdf/1199623.pdf
kind: paper
commit:
for: [effect-isolation]
looked: 2026-10-13
depth: docs (whole paper, 6 pages)
relevance: medium
grade: C/weak
description: JSM 2019 proceedings; LoL 2015 NA ranked ADC-support pairs, one logistic model per ADC with support indicators and vice versa, Bonferroni tests, classified as mutualism, commensalism, parasitic and so on
---
# Ramler, Lee, Schuckers 2019: ADC-support symbiosis in League of Legends

Why: the one LoL paper found that estimates ally pair (bot lane) effects with a
plus-minus style logistic model and reports how many pairs matter.

## Assessment

- Evidence: C. Conference proceedings, one season (2015 NA), large samples (13k to
  700k games per champion model), no held-out test, no shrinkage.
- Reasoning: weak on identification: the pair coefficient is not separated from the
  partner's own strength (see ^f6).
- Interests: none.
- Weigh: use as an example of the confound to avoid and as a rough upper bound on how
  often bot pairs look non-null; don't use its category counts as synergy evidence.

## Findings

- [method] [draft] Design: for each ADC, a logistic model of its win rate on
  indicators for which support it was paired with; a mirror set per support. Pair
  coefficient = how much ADC i gains from support j. ^f1
  > The regression coefficients (𝛽𝑗|𝑖 ) measure the impact on win rates of the ith ADC being paired with Support j.
- [data] Data: 2015 ranked solo and team, 17 ADCs by 19 supports, all 323 pairs seen,
  13,000 to 700,000 games per model. ^f2
  > Sample sizes used in the models ranged from roughly 13,000 for the least popular champions to 700,000 for the most popular.
- [stats] Pairs classified by Bonferroni-adjusted p < 0.05 on each one-way coefficient;
  no shrinkage, no interval reported. ^f3
  > We classified the ADC by Support relationships into one of the six categories based on whether or not a Bonferroni adjusted p-value associated with the regression coefficient
- [draft] Result: about 5% of pairs (17 of 323) benefit both, 14% one side only, 28%
  harm at least one; the rest null. ^f4
  > Only about 5% of pairs (17 of 323) were beneficial to both the ADC and Support (Mutualism, dark green) while another 14% were beneficial to one without negatively impacting the other
- [draft] Win rates by category: about 53% for mutualism pairs down to 45-47% for
  competitive pairs. ^f5
  > those with benefial pairing had higher rates (about 53% for mutualism) while this decreased to around 45 - 47% for competition
- [stats] [method] (inferred) Confounded: in ADC i's model the coefficient on support j
  is support j's own strength plus any interaction, since the model has no support
  main effect. A strong support looks "mutualistic" with every ADC. Their own footnote
  says the classic test is an interaction term, which they did not fit. ^f6
  > In a classic interaction model, being synergistic would imply a positive slope coefficient on the interaction term between two champions.
- [stats] (inferred) So the 53% vs 45-47% gap is mostly champion main effects, not bot
  lane synergy; it bounds pair-plus-main effects from above, not synergy. ^f7
- [draft] (inferred) Mutualism pairs cluster on three ADCs (Jinx, Sivir, Vayne) with
  crowd-control supports, which fits a main-effect explanation (strong ADCs that
  season) as well as a synergy one. ^f8
  > three ADCs (Jinx, Sivir, and Vayne) dominate the graph, with each having multiple Supports that they interact well with

## Read

- Whole paper.

## Not read

- Lee and Ramler 2017 data paper (the dataset source).
