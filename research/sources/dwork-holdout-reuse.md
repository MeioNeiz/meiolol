---
title: Generalization in Adaptive Data Analysis and Holdout Reuse (Dwork, Feldman, Hardt, Pitassi, Reingold, Roth, 2015)
url: https://arxiv.org/pdf/1506.02629
kind: paper
commit: 
for: [llm-experiment-agent]
looked: 2026-10-12
depth: skimmed (abstract, sections 1, 4.1-4.2, 5 experiments, 6)
relevance: high
grade: A/strong
description: Reusable holdout paper (arXiv long version of the Science 2015 article): Thresholdout and SparseValidate, adaptive reuse of a holdout set without overfitting it
---
# Generalization in Adaptive Data Analysis and Holdout Reuse (Dwork et al., 2015)

Why: what goes wrong when an automated searcher evaluates many adaptively chosen variants
against one held-out set, and what guard keeps the holdout honest.

## Assessment

- Evidence: A. Canonical reference by the founders of adaptive data analysis (Dwork,
  Roth: differential privacy; Hardt, Feldman); Science 2015 short version; widely cited.
  Proofs plus one synthetic experiment (n = 10,000, d = 10,000, 100 runs).
- Reasoning: strong. States the gap with static multiple-testing corrections, gives
  proofs, admits the experiment's parameters are below what the proofs need.
- Interests: none known (academic; authors' own method).
- Weigh: trust the mechanism and the synthetic demonstration; the formal guarantees
  need holdout sizes far beyond our 1334 test games, so for us Thresholdout is a
  heuristic guard, not a proof. Its threshold T = 0.04 on accuracy is much coarser than
  our ±0.0012 log-loss interval: tuning it to our scale is our problem.

## Findings

- [lab] [stats] Reusing a holdout adaptively overfits the holdout itself; reporting the
  best of many tested predictors is the well-known cause. Section 1 ^f1
  > Reusing a holdout set adaptively multiple times can easily lead to overfitting to the holdout set itself.
  > One well-known reason for such dependence is that the holdout data is used to test a large number of predictors and only the best one is reported.
- [lab] [stats] Static multiple-testing corrections only work when the set of tested
  hypotheses is fixed in advance; adaptive choice (hyperparameter tuning, analyst in the
  loop, stopping conditions) breaks them. Section 1 ^f2
  > However such static approaches do not apply if the estimates or hypotheses tested on the holdout are chosen adaptively: that is, if the choice of hypotheses depends on previous analyses performed on the dataset.
- [lab] [stats] Synthetic demo: with labels independent of data (true accuracy 50%),
  standard holdout reuse reported over 63% on both training and holdout for k = 500;
  a fresh set showed the truth. Section 5 ^f3
  > Nevertheless, reusing a standard holdout results in reported accuracy of over 63% for k = 500 on both the training set and the holdout set
- [lab] [stats] Thresholdout: if training and holdout scores agree within a noisy
  threshold, return the training score; otherwise return the holdout score plus noise and
  spend one unit of an overfitting budget B; stop answering when B runs out.
  Section 4.1, Figure 1 ^f4
  > If the difference is below the threshold, then the algorithm returns ESt [φ]. If the difference is above the threshold, then the algorithm returns ESh [φ] + ξ for another Laplacian noise variable ξ.
  > Each time the difference is above threshold the “overfitting” budget B is reduced by one. Once it is exhausted, Thresholdout stops answering queries.
- [lab] [stats] The number of queries Thresholdout can answer is exponential in holdout
  size n, as long as overfitting answers stay at most quadratic in n. Section 1.1.1 ^f5
  > The number of queries that Thresholdout can answer is exponential in n as long as the number of times that the analyst overfits is at most quadratic in n.
- [lab] [stats] SparseValidate: the analyst only gets a bit back per query, with budgets
  for total queries m and for failed validations B; information leaks only on failures.
  Section 4.2 ^f6
  > SparseValidate has a budget m for the total number of queries that can be asked and budget B for the number of queries that returned 1. Once either of the budgets is exhausted, no additional answers are given.
- [lab] [stats] Cross-validation and bootstrap do not fix adaptive reuse; before this the
  only known safe approach was a fresh holdout for each dependent validation. Section 5 ^f7
  > neither cross-validation nor bootstrap resolve this issue.
  > previously the only known safe approach was to collect a fresh holdout set each time a function depends on the outcomes of previous validations.
- [lab] [stats] With a real signal (20 informative attributes) Thresholdout still finds
  a good classifier while preventing overfitting: the guard does not block true
  discoveries. Section 5 ^f8
  > when using the reusable holdout, the algorithm still finds a good classifier while preventing overfitting.
- [lab] [stats] The experiment used T = 0.04, below the values the proof needs, and
  Gaussian instead of Laplace noise: practical settings are empirical. Section 5 ^f9
  > This is lower than the values necessary for the proof (and which are not intended for direct application) but suffices to prevent overfitting in our experiment.
- [lab] (inferred) For meiolol: an agent that sees exact held-out log-loss after every
  variant is the "standard holdout" curve; exposing only a coarse or noisy answer, and
  counting how often the held-out score disagrees with the training/CV score, is a cheap
  Thresholdout-style guard. ^f10

## Read

- Abstract, section 1 (intro, 1.1.1 reusable holdout), 4.1 Thresholdout, 4.2
  SparseValidate (statement), 5 experiments, 6 conclusions

## Not read

- Sections 2-3 (max-information, description length proofs): theory, not needed for guards
- Exact parameter bounds (Theorem 25 etc.): would tell how small a holdout can be
