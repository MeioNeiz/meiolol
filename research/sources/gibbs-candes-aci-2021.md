---
title: 'Gibbs and Candes 2021: Adaptive Conformal Inference Under Distribution Shift'
url: https://arxiv.org/pdf/2106.00170
kind: paper
commit:
for: [share-drift-ranges]
looked: 2026-11-04
depth: listed (sections 1-2, 4.1, 5 discussion, 6, 7)
relevance: high
grade: A/strong
description: NeurIPS 2021 paper (Stanford) introducing adaptive conformal inference (ACI): an online update of the working miscoverage level alpha_t from observed misses, giving long-run coverage with no assumption on how the data drift
---
# Gibbs and Candes 2021: Adaptive Conformal Inference Under Distribution Shift

Why: our 80% share ranges miss more on day 8+ than on days 1-3; is there a model-free
online wrapper that keeps coverage at 80% per slot as shares drift?

## Assessment

- Evidence: A. NeurIPS 2021, Candes; ACI is the base of a large follow-up literature
  (DtACI, conformal PID control) and a standard baseline.
- Reasoning: strong. Proves a finite-sample long-run bound, discusses the step-size
  trade-off and states its own limits (delayed or batched labels, gamma choice).
- Interests: none.
- Weigh: the guarantee is on the long-run average miss rate, not per-time or per-cell
  coverage; the width it settles at is only as good as the base model and score.

## Findings

- [stats/shares] Split conformal: fit on one part, rank a held-out calibration set's
  scores, take the (1 - alpha) quantile; coverage is exact under exchangeability.
  Section 1.1 ^f1
  > we remark that the method outlined above is often referred to as split or inductive conformal inference
- [stats/shares] [method/dynamics] ACI keeps a working level alpha_t and updates it
  after each outcome: alpha_{t+1} = alpha_t + gamma (alpha - err_t), err_t = 1 on a
  miss; misses narrow alpha_t (wider sets), hits widen it. Section 2 ^f2
  > Then, fixing a step size parameter γ > 0 we consider the simple online update
  > αt+1 := αt + γ(α − errt ).
- [stats/shares] A variant uses a weighted recent miss frequency (e.g. 0.95^(t-s)
  weights) instead of the last miss; results are almost identical, trajectories
  smoother. Section 2 ^f3
  > In practice, we find that (2) and (3) produce almost identical
- [stats/shares] With no assumption on the data, the average miss rate over T steps is
  within (max(alpha_1, 1 - alpha_1) + gamma) / (T gamma) of alpha, so it converges to
  alpha. Proposition 4.1 ^f4
  > adaptive conformal inference obtains the correct coverage frequency irrespective of any assumptions
  > on the data-generating distribution.
- [stats/shares] Step size gamma trades adaptivity against volatility; bigger shift
  wants bigger gamma; they used gamma = 0.005; too small behaves like fixed alpha.
  Section 2.1 ^f5
  > The choice of γ gives a tradeoff between adaptability and stability.
  > In our experiments we will take γ = 0.005.
- [stats/shares] Coverage depends on how stationary the conformity score is: a score
  normalised by the model's own variance (|V - sigma^2| / sigma^2) worked, the raw
  difference swung far from target. Section 5 ^f6
  > properties of adaptive conformal inference depend on how close St (Xt , Yt ) is to being stationary.
  > critical for obtaining an approximately stationary conformity score
- [stats/shares] Election night 2020 (counties reporting east to west, a drift):
  non-adaptive CQR lost 90% coverage at time-zone changes, ACI held about 90%.
  Section 6 ^f7
  > find that the non-adaptive method fails to maintain the desired 90% coverage level, incurring large
  > troughs in its coverage frequency during time zone changes.
- [stats/shares] Limits they state: needs each label revealed in turn (delayed or
  batched labels open), theory assumes a fixed quantile function, gamma chosen by
  heuristic. Section 7 ^f8
  > However, there are many settings in which we receive the response
  > in a delayed fashion or in large batches.
- [stats/shares] (inferred) For us: use the normalised score z = (logit share_target -
  logit estimate) / sd_model, with sd_model our current phi plus drift sd; then ACI per
  slot kind (item, keystone, build) and horizon bucket learns the z quantile that gives
  80%. Our labels arrive in daily batches with many cells per day, so update alpha_t
  once per day per group with the day's miss fraction (the weighted variant), not per
  cell. ^f9
- [stats/shares] (inferred) ACI fixes average coverage per group but not which cells
  miss: a thin cell and a big one share alpha_t. Run it per (slot kind, horizon bucket,
  n bucket) group, and read a drifting alpha_t as a diagnostic that the model's drift
  term is wrong, not only as a patch. ^f10

## Read

- 1-2 (split conformal recap, ACI, step size), 4.1 (distribution-free bound), 5
  (score choice), 6 (election), 7 (discussion)

## Not read

- 2.2 volatility example details, 4.2 Markov-chain bounds, appendix proofs
