---
title: 'Sample size estimation for power and accuracy in the experimental comparison of algorithms (Campelo, Takahashi, 2019)'
url: https://arxiv.org/pdf/1808.02997
kind: paper
commit: 
for: [smart-experiment-search]
looked: 2026-10-12
depth: skimmed (abstract, 1, 3.1, 4.1 on number of instances, algorithm 2)
relevance: high
grade: B/strong
description: Journal of Heuristics paper (2019) on fixing a minimally relevant effect size before comparing two algorithms and deriving the number of instances for a paired t-test at a set power
---
# Sample size estimation for power and accuracy in the experimental comparison of algorithms (Campelo, Takahashi, 2019)

Why: how to know, before running, whether a model change of a given size could be
detected with the data we have (minimum detectable effect for a paired comparison).

## Assessment

- Evidence: B. Peer-reviewed (Journal of Heuristics), with an R package (CAISEr) and
  two worked examples; standard power theory applied to algorithm comparison.
- Reasoning: strong. Explains why to fix the effect size first, the pseudoreplication
  trap, and what to do when the needed sample exceeds what is available.
- Interests: authors' own method and package.
- Weigh: the maths is the textbook paired t-test; trust it. Their instances are
  optimisation problems; for us the instance is the game (or the cluster, if games
  share players), the paired difference is per-game log-loss difference.

## Findings

- [stats] With large enough samples any minuscule difference becomes significant;
  fixing a minimally relevant effect size (MRES) before the experiment avoids reading
  that as practical superiority, yet it is rarely done. `1` ^f1
  > arbitrarily large sample sizes allow statistical procedures to detect even minuscule differences, which may lead to the wrongful interpretation that effects of no practical consequence are strongly significant
  > this problem can be alleviated by defining a minimally relevant effect size (MRES) (also known as the smallest difference of practical importance) prior to the experiment
- [stats] [lab] Design the experiment to have the desired power at the MRES; smaller
  effects are by definition uninteresting, so missing them costs nothing. `3.1` ^f2
  > design the experiment to have a desired power for the limit case where d = d∗ , then the test will have greater power for any effect size d > d∗ .
- [stats] Power rises with alpha, N and the standardised effect d = delta / sigma of
  the paired differences. `3.1` ^f3
  > All other quantities being equal, the power of a test increases as α, N and d increase.
- [stats] Fixing the MRES also adds a practical-relevance dimension to significance
  tests, beyond the p-value. `3.1` ^f4
  > By forcing the experimenter to define which differences would have practical relevance prior to the experiment, the MRES helps to avoid well-known problems associated with the exclusive use of the p-value in statistical inference
- [stats] The independent units are the per-instance paired differences, not the
  individual runs; treating runs as independent is pseudoreplication with inflated
  degrees of freedom. `4.1` ^f5
  > the independent observations to be used in the test of this hypotheses are the individual values φj (or, more accurately, their estimates φbj ), and not the individual runs of the algorithms on each instance.
- [stats] Required N is the smallest N whose paired t-test reaches the target power at
  the MRES; computed iteratively, available in R. `4.1` ^f6
  > The sample size for this test can then be calculated as the smallest integer such that π ∗ is equal to or larger than a desired power.
- [stats] [lab] Their procedure checks first whether the needed N exceeds the
  instances available, and if so investigates power or changes parameters before
  running. `algorithm 2` ^f7
  > 2: if N ∗ > |ΓS | then
  > Investigate power, change parameters if needed.
- [stats] Sequential testing (add samples and retest until significant) without
  correcting alpha inflates type I errors; they flag prior work for this. `1` ^f8
  > suggest a sequential inference procedure, iteratively increasing the sample size and re-testing until an effect is found or a statistical power of 0.8 is reached for a given MRES, but fails to adequately correct for the increase in type-I errors due to multiple hypothesis testing
- [stats] [lab] (inferred) For meiolol: with sigma_d the SD of per-game log-loss
  differences between candidate and current model (clustered by game, as the harness
  already does), the two-sided 80% power MDE at alpha 0.05 is about
  2.8 * sigma_d / sqrt(N_eff); an idea whose plausible gain is below that should be
  parked as undetectable at current data, not run and declared refuted. ^f9

## Read

- Abstract, section 1, 3.1 (power, MRES), 4.1 (number of instances, formulas 23-24),
  algorithm 2.

## Not read

- 3.2 and 4.2 (accuracy and number of repeated runs per instance: relevant only if
  our fits are stochastic), 5 (examples), 6.
