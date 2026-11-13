---
title: 'Molnar: Interpretable Machine Learning, chapter 21 Feature Interaction (H-statistic)'
url: https://christophm.github.io/interpretable-ml-book/interaction.html
kind: book
commit: 
for: [frontier-interactions]
looked: 2026-11-13
depth: docs (chapter 21: H-statistic, Strengths, Limitations)
relevance: high
grade: B/fair
description: Textbook chapter on Friedman's H-statistic: definition, 2n^2 predict calls per pair, and a limitations list (unstable under sampling, no model-agnostic test, can exceed 1, spurious when the pair's total effect is weak, correlated features); no experiments
---
# Molnar: Interpretable Machine Learning, chapter 21 Feature Interaction (H-statistic)

Why: a practitioner's list of where the H-statistic fails, to set against the original
paper.

## Assessment

- Evidence: B. A widely used open textbook on interpretability, by the author of
  the iml R package that implements the statistic, so first-hand use. No experiment,
  simulation or number backs any item in the limitations list; one is called anecdotal.
- Reasoning: fair. States what each limitation follows from (small denominator,
  independent shuffling) but shows none of them.
- Interests: own package (iml); none against the method.
- Weigh: a reliable map of known failure modes and of cost; take sizes and frequency
  from elsewhere ([[inglis-vivid-unnormalised-h-2022]] for the one simulation).

## Findings

- [method/interpret] H is the share of the variance of the two-way partial dependence
  (or of the model, for one feature against the rest) explained by the interaction: 0
  with none, 1 when the single-feature effects are flat. Friedman's H-statistic ^f1
  > The amount of the variance explained by the interaction (difference between observed and no-interaction PD) is used as an interaction strength statistic.
- [method/interpret] It can exceed 1, which has no clean reading. Friedman's
  H-statistic, Limitations ^f2
  > This can happen when the variance of the 2-way interaction is larger than the variance of the 2-dimensional partial dependence plot.
- [method/interpret] Cost: each data point needs a partial dependence, itself a pass
  over all n points, so up to 2n^2 model calls for one pair and 3n^2 for one feature
  against the rest. Friedman's H-statistic ^f3
  > In the worst case, we need 2n2 calls to the machine learning model’s predict function to compute the two-way H-statistic (j vs. k) and 3n2 for the total H-statistic (j vs. all).
- [stats] Subsampling to cut cost makes the partial dependence estimates noisy and the
  statistic unstable from run to run; the advice is to repeat the computation and look
  at the spread. Friedman's H-statistic, Limitations ^f4
  > This has the disadvantage of increasing the variance of the partial dependence estimates, which makes the H-statistic unstable.
  > I recommend repeating the H-statistic computation a few times to see if you have enough data to get a stable result.
- [stats] No model-agnostic significance test: Friedman and Popescu's null needs a
  version of the model with the interaction removed, which not every model type allows.
  So there is also no threshold for a "strong" H. Friedman's H-statistic, Limitations ^f5
  > To generate the interaction statistic under the null hypothesis, you must be able to adjust the model so that it has no interaction between feature j and k or all others. This is not possible for all types of models.
  > it is difficult to say when the H-statistic is large enough for us to consider an interaction “strong.”
- [method/interpret] Weak-effect failure: when two features together matter little but
  what they do is mostly interaction, the denominator is small and H is very large;
  correlation makes it worse. The suggested remedy is the unnormalised statistic, the
  square root of the numerator. Limitations ^f6
  > When the total effect of two features is weak but mostly consists of interactions, then the H-statistic will be very large. These spurious interactions require a small denominator of the H-statistic and are made worse when features are correlated.
  > A possible remedy is to visualize the unnormalized version of the H-statistic, which is the square root of the numerator of the H-statistic
- [method/interpret] Correlated features: the statistic assumes features can be shuffled
  independently, so it averages the model over unrealistic combinations, and correlated
  features can give large H. Limitations ^f7
  > we integrate over feature combinations that are very unlikely in reality
  > Correlated features can lead to large values of the H-statistic.
- [method/interpret] (claim) The author has seen small simulations where H did not
  return the planted answer; no detail given. Limitations ^f8
  > Sometimes the results are strange, and for small simulations do not yield the expected results. But this is more of an anecdotal observation.
- [method/interpret] H gives strength, not shape or sign: the workflow is H to pick
  pairs, then the 2D partial dependence plot. Applies to classification on the
  predicted probability. Limitations ^f9
  > The H-statistic tells us the strength of interactions, but it does not tell us how the interactions look like.
  > The interaction strength statistic can also be applied in a classification setting if the prediction is a probability.
- [method/interpret] Strengths listed: dimensionless so comparable across features and
  models, catches any form of interaction, extends to 3 or more features. Strengths ^f10
  > Since the statistic is dimensionless, it is comparable across features and even across models.
- [method/interpret] Checked, not there: nothing on categorical features with many
  levels, nothing on low-signal or near-chance outcomes, no false positive rates, no
  multiple-testing over pairs. The example is a random forest on penguin body
  measurements. ^f11

## Read

- Chapter 21: "Friedman's H-statistic", "Strengths", "Limitations" in full; "What are
  feature interactions?" and "Examples" skimmed.

## Not read

- "Software and alternatives" beyond the package list (Hooker's variable interaction
  networks, Greenwell's partial-dependence measure): other readers cover functional
  ANOVA.
