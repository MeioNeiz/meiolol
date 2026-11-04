---
status: answered
priority: now
area: stats
tags: [stats, stats/shares, method/dynamics]
description: How should ranges for drifting shares (item, keystone, build pick rates within a champion) be modelled: overdispersed multinomial, state-space drift, and conformal checks?
---
# How should ranges for drifting shares (item, keystone, build pick rates within a champion) be modelled: overdispersed multinomial, state-space drift, and conformal checks?

Feeds: MeioModel share ranges (overdispersion phi, within-patch drift term), truth share targets, the 16.22 check

## Answer

Our two fixes are the textbook ones, with two refinements. Overdispersion: under a
Dirichlet-multinomial with player clusters, a share's variance is [1 + (m - 1) tau]
times the multinomial one, one factor for every option in the slot, so one phi per slot
fits as long as games per player (m) are similar across its cells; phi grows with m, so
a 14-day window should show a larger phi than a 3-day one (C1, C2). On sparse slots,
estimate it with a Fletcher-type estimator (Pearson X^2/df divided by 1 + sbar), not
plain Pearson or the deviance (C3). So: fit tau per slot kind and give each cell phi =
1 + (mbar - 1) tau from its own mbar = sum m^2 / sum m over players (C10).

Drift: local-level and discount dynamic models give a forecast variance that grows with
the horizon, and a dynamic model needs its own per-step noise term or it under-covers at
1, 7 and 14 days ahead (C4, C5). meio.zig's Drift fits one tau2 from two halves of a
patch ("over about a week"), which is a method-of-moments local-level estimate right at
one lead only: the gap between the halves' centres. A range made on days 1-3 and judged
on day 8+ needs about lead / gap times that (C9). Make it q times h, q = tau2 / gap
pooled per slot kind, and since post-patch adoption is front-loaded, let q depend on
days since patch, estimated from past patches. A logistic local-level filter per cell
(one discount per slot kind) is the later, fuller version.

Model-free check: adaptive conformal inference keeps the long-run miss rate at target
under any drift with one update per batch, alpha_t+1 = alpha_t + gamma (alpha - err_t),
given a roughly stationary normalised score; weighting calibration cases by rho^age
(NexCP) bounds the coverage gap under drift, where unweighted calibration lost it (0.84
against 0.90) (C6, C7). Weighted conformal under covariate shift does not fit, since a
drifting share changes the outcome itself (C8). Use ACI per (slot kind, lead bucket) on
z = (logit target - logit estimate) / sd as a check first: a drifting alpha_t says the
drift term is wrong (C11).

## Claims

- C1: Player-clustered share counts have variance [1 + (m - 1) tau] times multinomial, so
  phi rises with games per player. for: [[afroz-sparse-multinomial-overdispersion-2018#^f2]], [[afroz-sparse-multinomial-overdispersion-2018#^f3]], [[practools-design-effects#^f3]]
- C2: One phi per slot fits the Dirichlet-multinomial and quasi-multinomial models (one
  factor for every option) when games per player are similar across its cells.
  for: [[afroz-sparse-multinomial-overdispersion-2018#^f1]], [[afroz-sparse-multinomial-overdispersion-2018#^f3]]
- C3: On sparse data estimate phi with a Fletcher or Farrington type estimator, not
  Pearson X^2/df or the deviance. for: [[afroz-sparse-multinomial-overdispersion-2018#^f5]], [[afroz-sparse-multinomial-overdispersion-2018#^f6]], [[afroz-sparse-multinomial-overdispersion-2018#^f7]]
- C4: Local-level and discount dynamic models give forecast variance that grows with the
  horizon. for: [[fpp3-ets-forecasting#^f4]], [[berry-west-dcmm-2020#^f3]], [[berry-west-dcmm-2020#^f5]]
- C5: A dynamic model needs a term for per-step noise; adding one fixed under-coverage at
  1, 7 and 14 days ahead. for: [[berry-west-dcmm-2020#^f6]], [[berry-west-dcmm-2020#^f7]]
- C6: Adaptive conformal inference holds long-run coverage under any drift, given a
  normalised score and a step size trading adaptivity against volatility.
  for: [[gibbs-candes-aci-2021#^f2]], [[gibbs-candes-aci-2021#^f4]], [[gibbs-candes-aci-2021#^f5]], [[gibbs-candes-aci-2021#^f6]], [[gibbs-candes-aci-2021#^f7]]
- C7: Calibration weighted by age bounds the coverage loss under drift; unweighted loses
  coverage. for: [[barber-nexcp-2023#^f2]], [[barber-nexcp-2023#^f4]], [[barber-nexcp-2023#^f6]]
- C8: Weighted conformal assumes the outcome given covariates does not change; a share
  drifting within a patch breaks that. for: [[tibshirani-weighted-conformal-2019#^f3]]
- C9 (inferred): The halves-based tau2 is a local-level drift estimate right at one lead
  (the gap between halves); it should scale with lead. from: C4, C5; see [[fpp3-ets-forecasting#^f5]]
- C10 (inferred): Fit tau per slot kind and give each cell phi from its own mbar. from:
  C1, C2, C3; see [[afroz-sparse-multinomial-overdispersion-2018#^f9]]
- C11 (inferred): ACI or NexCP per (slot kind, lead bucket) is a cheap check and wrapper
  on share ranges. from: C6, C7; see [[gibbs-candes-aci-2021#^f9]], [[barber-nexcp-2023#^f9]]

## Disagreements

None between sources. Caveat on C9: post-patch drift is adoption (trend-like and
front-loaded), not a random walk; a constant q under-states days 1-3 and over-widens
later, hence q by days since patch.

## Open

16.22 check (proposals, not yet run):
- Ranges from days 1-3 scored at leads 4-7 and 8-14 days, per slot kind and n bucket:
  fixed tau2 against q times h
- phi on 3-day against 14-day windows: if it does not rise with mbar, one phi per slot
  is enough (C1)
- per-day logit drift q by days since patch: front-loaded or not
- ACI (gamma 0.005-0.02) per (slot kind, lead bucket) and NexCP (0.9^days, calibrated on
  16.21 pairs) run back over 16.22: coverage and alpha_t paths

Leads: Triantafyllopoulos binomial dynamic models (0802.0219), Minka's Dirichlet note,
Angelopoulos and Bates intro (2107.07511), DtACI (2208.08401), conformal PID (2307.16895),
AgACI (2202.07282).
