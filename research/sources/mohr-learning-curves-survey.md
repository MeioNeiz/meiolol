---
title: 'Mohr and van Rijn 2022: Learning Curves for Decision Making in Supervised Machine Learning, A Survey'
url: https://arxiv.org/pdf/2201.12150
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, sections 1, 2.2 part, 2.4 well-behaved curves, 4.1-4.2, 5.1.4, 6)
relevance: medium
grade: A/fair
description: Survey (v2 2025) of sample-wise and iteration-wise learning curves and their use for data acquisition, early stopping and early discarding; framework of decision questions
---
# Mohr and van Rijn 2022: Learning Curves for Decision Making, A Survey

Why: whether learning curves (score vs training games) can separate "this idea needs
more data" from "this idea has no effect", so the lab can park ideas instead of
discarding them.

## Assessment

- Evidence: A. Survey by two learning curve researchers (Leiden, La Sabana), arXiv
  2022, revised 2025; reviewed by Brazdil, Guyon, Klein, Loog; classifies the whole
  literature in one framework.
- Reasoning: fair. Clear definitions, points out where methods are untested against
  each other; a survey, so little new evidence.
- Interests: authors cite their own convexity and learning curve cross-validation work.
- Weigh: trust the definitions and the map of decision situations; extrapolation
  accuracy is explicitly under-benchmarked.

## Findings

- [lab] [method] Learning curves serve three decisions: data acquisition, early
  stopping, and early discarding in model selection. Abstract, section 1 ^f1
  > Learning curves have important applications in several machine learning contexts, most notably in data acquisition, early stopping of model training, and model selection.
- [lab] Early discarding: stop evaluating a candidate once it is unlikely to beat the
  best seen so far, judged against other models, not its own curve. Section 4.1 ^f2
  > if we want to select from various models, we want to stop the evaluation of a candidate when we are sure that it is not competitive to the current best solution.
- [lab] [stats] Whether more data would help and how much data to use both reduce to
  locating the saturation point of the curve. Section 4.1 ^f3
  > whether more data points would be helpful to improve performance is related to the question of the training size that should be chosen to minimise training effort. Both questions, at their core, ask for the saturation point of the learning curve.
- [lab] [stats] If performance is already near the data's intrinsic noise, more rows
  will not help; acquire new features instead. Section 4.1.1 ^f4
  > If we know that, with the given data, we already achieve a performance close to the intrinsic noise, then data acquisition should focus on acquiring additional features instead of new instances.
- [lab] Most sample-wise curves are well behaved (monotone, even convex); empirical
  curves violate this mainly when few validations per point or on a plateau. Section 2.4 ^f5
  > extensive empirical studies have shown that most sample-wise curves are even convex (Mohr and van Rijn, 2023) and hence well behaved.
  > specifically when the number of validations conducted at the anchors is small or when the learning curve has reached a plateau.
- [lab] Parametric models (e.g. three-parameter inverse power law) can extrapolate from
  very few anchors. Section 6 ^f6
  > Even when the performance of a learner is observed at very few anchors, the learning curve can already be extrapolated to make predictions about larger anchors.
- [lab] [stats] Naive stopping rules on noisy curves stop too early; confidence
  intervals are wide at small anchors and narrow with size, so choose the point where
  the interval is narrow enough. Section 5.1.4 ^f7
  > preliminary results indicate that this approach often stops too early. This is mainly caused by high aleatoric uncertainty, which implies noisy empirical learning curves.
  > Typically, the confidence intervals are large on small anchors and then contract for increasing anchor sizes.
- [lab] Sampling extra anchors costs more than one full fit when training time is
  linear in data size (an anchor at 40% plus two neighbours is ~120% of a full run). Section 5.1.4 ^f8
  > Suppose a costly anchor at 40% of the overall data size. If we draw only two additional samples around this anchor, then the runtime is around 120% of the runtime we would have had if we had trained on the complete dataset once.
- [lab] Extrapolation methods have been compared with each other only a little;
  simple binary-question methods such as successive halving and Hyperband have proven
  effective. Section 6 ^f9
  > these models have only been subject to limited comparison.
  > Approaches that remain faithful to this question level (such as successive halving and hyperband) have proven effective and received considerable attention.
- [lab] The best learner on a split-off training set need not be the best on the full
  training set; extrapolation can predict which wins at full size. Section 6 ^f10
  > It is not necessarily the case that the same learner performs best on both.
- [lab] (inferred) For meiolol: fit baseline and candidate at 3-4 nested data sizes
  (geometric, e.g. 25/50/100%) and compare the gap: a gap that grows with data is
  "needs more data, park it"; a flat gap near zero with narrow intervals is "no
  effect". Cost is under 2 full runs if fit time is linear. ^f11

## Read

- Abstract, section 1, 2.2 (empirical curve studies), 2.4 well-behaved curves,
  4.1 intro, 4.1.1 start, 4.2, 5.1.4, 6

## Not read

- Section 3 curve models in detail, 5.2 model-based approaches (Domhan et al. etc.),
  Table 1
