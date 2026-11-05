---
title: 'Kale, Kay, Hullman 2020: Visual Reasoning Strategies for Effect Size Judgments and Decisions'
url: https://arxiv.org/pdf/2007.14516
kind: paper
commit: 
for: [showing-ranges]
looked: 2026-11-05
depth: listed (abstract, intro, 3.8 participants, 4 results, 5 strategies, 6 discussion and limits)
relevance: high
grade: A/strong
description: IEEE TVCG (VIS 2020), preregistered MTurk study, 622 users: how lay readers judge "A beats B" from 95% intervals, HOPs, densities and 20-dot quantile dotplots, each with and without a mean mark; most just compare distance
---
# Kale, Kay, Hullman 2020: Visual Reasoning Strategies for Effect Size Judgments and Decisions

Why: which shape helps a lay reader judge "is A better than B, and by how much", and
does drawing the mean on top of a range hurt?

## Assessment

- Evidence: A. IEEE TVCG paper, preregistered exclusions, 622 US MTurk users after
  exclusions (target 640 from pilot), Bayesian models, plus coded strategy reports from
  442 users; Kay and Hullman lead the field.
- Reasoning: strong. Caveat beside each take-away, limitations section (symmetrical
  distributions only, self-reported strategies, small incentives).
- Interests: Kay and Hullman authored quantile dotplots and HOPs, which they test here.
- Weigh: the "people judge by distance" result is large and robust; effects of adding a
  mean are small. Task: probability that a team scores more with a new player (our "A
  beats B"), plus a bet decision.

## Findings

- [ux/uncertainty] Most lay readers judge "how much better" by distance between the two
  shapes or their means: 80.8% (357 of 442); only about 8% scale distance by spread.
  5.1, 6 ^f1
  > the majority of users (357 of 442; 80.8%) rely on distance between distributions or mean difference to judge effect size.
  > Only about 8% of users (35 of 442) mention that their interpretations of distance depend on the spread of distributions
- [ux/uncertainty] With 95% interval bars it is worst: about 10% of interval users took
  width into account at all. 5.2 ^f2
  > only about 10% of intervals users (11 of 112) incorporate variance into their judgments of distance.
- [ux/uncertainty] Everyone underestimated "probability A beats B"; errors without a mean
  mark: dotplots 8.6, HOPs 14.0, intervals 14.8, densities 12.4 percentage points.
  4.1 ^f3
  > users show an average estimation error of 8.6, 14.0, 14.8, and 12.4 percentage points in probability of superiority units for quantile dotplots, HOPs, intervals, and densities,
- [ux/charts] Quantile dotplots gave the most accurate comparisons; under high mental
  load they beat HOPs. 6 ^f4
  > Quantile dotplots support the most perceptually accurate distributional comparisons, at least among the visualization designs we tested.
  > Conditions of high cognitive load seem to favor uncertainty visualizations like quantile dotplots over HOPs.
- [ux/uncertainty] HOPs did no better than intervals or densities: most HOPs users read
  position, only 19 of 121 counted how often draws swapped order. 4.3, 5.2 ^f5
  > However, it is surprising that users do not perform reliably differently with frequency-based HOPs than with intervals or densities.
  > about 35% (19 of 54) rely on the optimal strategy of counting the frequency of draws changing order.
- [ux/uncertainty] Drawing the mean on top of a range causes small but reliable bias
  (more distance reading, worse decisions in most cases), and means are "sticky": users
  who had them kept estimating means after they were removed. 6, 5.2 ^f6
  > Adding means leads to small biases in magnitude estimation and decision-making from distributional comparisons
  > This asymmetry in strategy switching suggests that means are “sticky” as a cue
- [ux/uncertainty] The best shape for estimating and the best for deciding differ:
  densities without means gave the best decisions across spreads. 6, 7 ^f7
  > Densities without means seem to support the best decisionmaking across levels of variance.
  > visualization designs which support the least biased estimation of effect size do not necessarily support the best decision-making.
- [ux/uncertainty] When spread is small relative to the axis, gaps look small even for
  big effects; readers act as if effects are larger whenever shapes are further apart,
  so axis scale drives the judgment. 4.3 ^f8
  > When variance is lower relative the axis scale, distances between distributions look small even for large effects
- [ux/uncertainty] Readers satisfice and switch strategies; few use the best one even
  when it exists. Abstract ^f9
  > many users switch strategies and do not employ an optimal strategy when one exists.
- [ux/uncertainty] (inferred) For "A or B" on meio.lol: two ranges or two dots on an axis
  will be read as the gap between centres, scaled by our axis, not by the ranges. State
  the answer instead ("A wins about 6 more games in 100; fairly sure"), and if a figure is
  needed, a 20-dot dotplot without a bold mean mark. Our gaps are small, the case where
  readers misjudge most. ^f10

## Read

- Abstract, introduction, participants, results 4.1-4.4, strategies 5.1-5.2, general
  discussion 6, limitations, conclusion.

## Not read

- Stimuli generation and model details (3.5-3.7); supplementary materials.
