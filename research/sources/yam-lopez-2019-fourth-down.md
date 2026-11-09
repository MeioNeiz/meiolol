---
title: 'Yam and Lopez: causal effects of conservative fourth down decisions in the NFL (NESSIS poster)'
url: https://www.nessis.org/nessis17/Yam_adj.pdf
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-09
depth: listed
relevance: medium
grade: B/fair
description: NESSIS 2017 poster (Brown, Skidmore; later JSA 2019) estimating wins lost to conservative NFL fourth downs by matching plays on win probability, time, yards to go and a propensity score, outcome the change in win probability
---
# Yam and Lopez: causal effects of conservative fourth down decisions in the NFL (NESSIS poster)

Why: a worked template for in-game choices whose takers differ (our item buyers who were
already ahead): what to match on, which outcome, how to get intervals.

## Assessment

- Evidence: B. Lopez is an established sports statistician (NFL); poster only, the
  journal version (JSA 2019) not read. ~13,000 plays.
- Reasoning: fair. States the confounding problem and the estimand; no sensitivity
  analysis on the poster.
- Interests: none known.
- Weigh: trust the design (state + propensity matching, delta-WP outcome, bootstrap);
  the wins-added numbers depend on two win models we can't check.

## Findings

- [method/causal] Choosers differ from non-choosers, so each non-chooser is matched to a
  chooser on the game state before the choice: win probability, game time, yards to go
  and the propensity to choose. ^f1
  > Teams that did not go for it matched to those that did based on: win probability, game time, yards to go, and propensity score (defined as the probability of going for it).
  > Teams that went for it differ inherently from those that did not.
- [method/causal] The outcome is the change in win probability across the decision, not
  the final result, from the average of two win models, with a nonparametric bootstrap
  for intervals. ^f2
  > Change in win probability, calculated using average of two models
  > Distributions of wins added estimated using non-parametric bootstrap.
- [method/causal] They frame the unchosen action's outcome as missing data. ^f3
  > 4th down outcomes are a missing data problem
- [method/causal] (inferred) For us: an item's or objective's effect is win chance after
  vs before, matched within champion-role on lead, minute and the propensity to buy;
  effect-isolation C1-C3 already names delta-WP, this adds the propensity match. ^f4

## Read

- Poster: whole (417 words)

## Not read

- JSA 2019 paper (doi 10.3233/JSA-190294): balance diagnostics, sensitivity
