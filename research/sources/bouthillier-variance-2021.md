---
title: Accounting for Variance in Machine Learning Benchmarks (Bouthillier et al., MLSys 2021)
url: https://arxiv.org/abs/2103.03098
kind: paper
commit: 
for: [agent-ml-practice]
looked: 2026-10-13
depth: skimmed (abstract, 1, 2 results, 3.1-3.3, 4, 5, 6 opening, appendix A note)
relevance: high
grade: A/strong
description: Mila/Inria study (6.4 GPU years, 5 deep-learning tasks) of which sources of variance move benchmark results, how to estimate cheaply by randomising all of them, and a P(A>B) >= 0.75 decision rule for declaring an improvement
---
# Accounting for Variance in Machine Learning Benchmarks (Bouthillier et al.)

Why: how many seeds and splits an agent needs before trusting an improvement, and which
sources of variance to randomise.

## Assessment

- Evidence: A. MLSys 2021, many authors incl. Varoquaux and Vincent; 6.4 GPU years of
  measurement on five tasks (image classification, segmentation, NLP, PascalVOC),
  200 seeds per source.
- Reasoning: strong. Formal model of the benchmarking process, explains the
  counter-intuitive result (fixing seeds correlates runs), measures error rates of the
  decision rules, states what it does not cover (many-way comparisons).
- Interests: none known.
- Weigh: deep-learning tasks with larger effects than ours; gamma 0.75 was tuned to
  separate published improvements from noise in their five cases, so treat it as a
  starting value. Their binomial test-set noise model applies directly to our win
  prediction (n games).

## Findings

- [lab] [stats] Recommendations: randomise as many sources of variation as possible;
  decide on improvement with variance, via the probability A beats B in a run; prefer
  resampling (out-of-bootstrap) over one fixed held-out test set for small gains. Section 1 ^f1
  > 1) As many sources of variation as possible should be randomized whenever possible.
  > We propose a simple decision criterion based on requiring a high-enough probability that in one run an algorithm outperforms another.
  > 3) Resampling techniques such as out-of-bootstrap should be favored instead of fixed held-out test sets to improve capacity of detecting small improvements.
- [lab] [stats] Data sampling (bootstrap of the data) is the largest source of variance;
  weight initialisation is usually under half of it, on par with data order. Section 2 ^f2
  > Bootstrapping data stands out as the most important source of variance. In contrast, model initialization generally is less than 50% of the variance of bootstrap, on par with the visit order of stochastic gradient descent.
- [stats] Test-set noise in accuracy matches a binomial with n test samples; with
  correlated errors the distribution is wider. Section 2 ^f3
  > if the pipeline has a chance τ of giving the wrong answer on a sample, makes i.i.d. errors, and is measured on n samples, the observed measure follows a binomial distribution
  > If errors are correlated, not i.i.d., the degrees of freedom are smaller and the distribution is wider.
- [lab] Hyperparameter optimisation alone induces about as much variance as weight
  initialisation (20 HPO runs of 200 trials each, other seeds fixed). Section 2 ^f4
  > The three hyperparameter optimization methods induce on average as much variance as the commonly studied weights initializa-
- [lab] [stats] The total variance from arbitrary choices is on the order of published
  state-of-the-art increments. Section 2 ^f5
  > Figure 3 shows that this variance is on the order of magnitude of the individual increments.
- [lab] [stats] Fixing seeds conditions on arbitrary values and correlates runs, so
  more splits stop reducing the estimator's variance; randomising seeds and data
  together decorrelates them. Section 3.2 ^f6
  > this conditioning to arbitrary ξ induces a correlation between the trainings which in turns increases the variance of the estimator.
- [lab] [stats] Re-seeding only the init (common practice) barely helps beyond k = 1;
  randomising data splits too, and all non-HPO sources, is far better and 51x cheaper
  than redoing HPO each time (21 vs 1070 hours at k = 100). Section 3.3 ^f7
  > Randomizing weights initialization only (FixedHOptEst(k,init)) provides only a small improvement with k > 1.
  > IdealEst(k = 100) takes 1 070 hours to compute, compared to only 21 hours for each FixedHOptEst(k = 100).
- [lab] [stats] Decision error rates (simulated, k = 50): a single-run comparison has
  about 10% false positives and 75% false negatives; a mean difference with a
  published-improvement threshold has under 5% false positives but about 90% false
  negatives; P(A>B) gives about 5% and 30%. Section 4.2 ^f8
  > The single point comparison leads to the worst decision by far. It suffers from both high false positives (≈ 10%) and high false negatives (≈ 75%).
  > Using the probability of outperforming leads to better balanced decisions, with a reasonable rate of false positives (≈ 5%) on the left and a reasonable rate of false negatives on the right (≈ 30%).
- [lab] [stats] Rule: A beats B if P(A>B) over paired splits is significantly above
  0.5 (bootstrap CI) and meaningfully reaches gamma, with gamma = 0.75 robust across
  their cases. Sections 4.1, 4.2 ^f9
  > We recommend to conclude that algorithm A is better than B on a given task if the result is both statistically significant and meaningful.
  > For the probability of outperforming, we use a threshold of γ = 0.75 which we have observed to be robust across all case studies
- [lab] Report all procedures within the significance bounds, not only the best. Section 5 ^f10
  > We recommend to always highlight not only the best-performing procedure, but also all those within the significance bounds.
- [lab] Even with every seed fixed, one pipeline (segmentation) was not reproducible;
  they measured that residual numerical noise with 200 fixed-seed runs. Appendix A ^f11
  > we have been unable to make the learning pipeline perfectly reproducible.
  > We thus trained our model with every seeds fixed across all 200 trainings and measured the variance we could not control.
- [lab] Checked, not there: many-way comparisons (an agent's long search) are left
  open; they suggest raising gamma as a multiple-comparison correction. Section 6 ^f12
  > A possible alley would be to adjust the decision threshold γ, raising it with a correction for
- [lab] (inferred) For meiolol: our paired game-clustered interval on one split covers
  test-set noise but not training noise; a keep should need k paired runs that vary
  seed and train subsample together (not seed alone), with P(new > base) and its
  bootstrap CI reported. A noise-floor run (baseline vs itself, new seeds) sizes the
  variance before any campaign. ^f13

## Read

- Abstract, introduction and recommendations list, section 2 results, 3.1-3.3, 4,
  5, start of 6, appendix A note on numerical noise

## Not read

- Appendix B bootstrap procedure, C worked example, I (gamma sensitivity), H figures
