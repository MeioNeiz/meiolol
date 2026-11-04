---
title: 'Hofman, Goldstein, Hullman 2020: How Visualizing Inferential Uncertainty Can Mislead Readers About Treatment Effects in Scientific Results'
url: https://mucollective.northwestern.edu/files/2020-Visualizing-Inferential-Uncertainty.pdf
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-04
depth: listed (abstract, intro, participants, discussion)
relevance: high
grade: A/strong
description: CHI 2020 honourable mention, two MTurk experiments (2,351 and 2,400 lay readers): 95% confidence intervals made people overstate how often a treatment wins and how much to pay for it; prediction intervals and HOPs were closest to correct
---
# Hofman, Goldstein, Hullman 2020: Inferential uncertainty misleads about effects

Why: when we show a range around a win rate and compare two options, do readers judge
"how often does A beat B" correctly?

## Assessment

- Evidence: A. Two preregistered-style powered experiments, about 2,400 US MTurk lay
  readers each, effect sizes varied; Microsoft Research and Northwestern; CHI 2020
  honourable mention.
- Reasoning: strong. Normative answers defined; limits (task, four displays, lay only)
  stated.
- Interests: none beyond the authors' HOPs line of work.
- Weigh: the task (a competition you win or lose, "probability of superiority") is close
  to a champion win rate comparison. Strongest bias for small effects, which is all of
  League.

## Findings

- [ux/uncertainty] Readers shown 95% CIs overestimated a treatment's effect and paid
  more for it than readers shown 95% prediction intervals of the same data. Abstract ^f1
  > "participants are willing to pay more for and overestimate the effect of a treatment when shown confidence intervals relative to prediction intervals"
- [ux/uncertainty] Across measures CIs were furthest from correct; prediction intervals
  or HOPs (variation in individual outcomes) were closest; rescaling the axis helped
  only somewhat. Discussion ^f2
  > "visualizations oriented towards inferential uncertainty (95% CIs) led to the greatest deviation from normatively correct answers"
  > "responses closest to the normatively correct answers across all measures were attained by people presented with visualizations that encoded information about variation in individual outcomes (95% PIs or HOPs)"
- [ux/uncertainty] Misperception was worst for small effects (Cohen's d around 0.25),
  the common case. Discussion ^f3
  > "misperceptions were largest for visualizations depicting smaller effect sizes"
- [ux/uncertainty] The competition task: how often you would win with versus without
  the treatment (probability of superiority). Introduction ^f4
  > "probability of superiority in which we ask participants how often they believe they would win a competition with or without the treatment"
- [ux/trust] Significant mean differences invite the false belief that every member of
  one group beats the other, when the distributions overlap. Discussion ^f5
  > "statistically significant differences in means between groups implies that all the members of one group are superior to those in another"
- [ux/uncertainty] Open: a display that shows both inferential and outcome uncertainty
  well does not exist yet; showing both doubles the plots. Discussion ^f6
  > "An innovative representation that does justice to effect size and sample mean differences would be welcome"
- [ux/uncertainty] (inferred) For meio.lol, "A beats B" can mean "A's true win rate is
  higher" (inferential, can be 95% sure) or "you win more games with A" (outcome, 52 vs
  50 of 100). A tight range or a high "chance A is better" next to a 2-point gap will be
  read as a big edge; pair it with games out of 100. ^f7

## Read

- abstract, intro, related work on HOPs, participants of both experiments, discussion

## Not read

- experiment stimuli details and per-condition plots
