---
title: 'Yang, Ning, Kou 2020: Use Internet search data to accurately track state-level influenza epidemics (ARGOX)'
url: https://arxiv.org/pdf/2006.02927
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-06
depth: docs (key points, results, discussion, methods second step, supplementary multiple correlation)
relevance: high
grade: B/strong
description: Harvard statistics arXiv preprint (2020); nowcasts weekly flu share for 51 US states by combining each state's own signal with national and regional estimates and other states' moves through one structured, shrunk covariance; states that move unlike the rest are modelled alone
---
# Yang, Ning, Kou 2020: ARGOX state-level flu tracking

Why: context-aware-models, regions sub-question: a share (flu %ILI) per region estimated
from a noisy own signal plus pooled national and other regions' moves, with a learnt
cross-region covariance; how it is kept from overfitting and what it gains.

## Assessment

- Evidence: B. Out-of-sample weekly nowcasts 2014-2020 for 51 states against CDC
  figures released later; benchmarks include the naive last-week value, VAR, GFT and a
  published state model. Authors behind the ARGO line of flu nowcasting (Kou).
- Reasoning: strong. Explains each structural restriction and why (few observations,
  large covariance), and why some states are left out of pooling; no ablation that
  isolates the cross-state term.
- Interests: own method.
- Weigh: trust the design lessons (structure plus shrinkage, opt-out for unlike
  regions, an unstructured VAR losing); the 28% gain bundles several parts.

## Findings

- [stats/shares] Gain: up to 28% lower MSE and about 15% lower MAE than the best
  alternative over 2014-2020, at least 15% lower MSE in every season 2014-2019.
  Results ^f1
  > ARGOX achieves up to 28% error reduction in MSE and about 15 % error reduction in MAE compared to the best alternative in the whole period.
- [stats/shares] An unstructured multivariate time-series model (lag-1 VAR on the
  same two-year window) never beat the naive last-week value; its MSE was two to
  three times the naive one. Results ^f2
  > VAR and GFT fail to outperform the naive method in any of the evaluated flu seasons; both methods have MSE two or three times larger than the naive method.
- [stats/shares] The target is the logit-scale weekly move of each state; four
  predictors (last move, own search estimate, regional estimate, national estimate)
  are combined by the best linear predictor from their joint covariance. Methods,
  second step ^f3
  > To combine the four predictors, we use the best linear predictor formed by them:
- [stats/shares] Structure keeps the covariance estimable: one cross-state covariance
  of moves shared by all predictors, a single autocorrelation rho for all states and
  times, and errors of the different sources independent. Methods ^f4
  > for the covariance matrices, due to their large sizes and the small number of observations, we need to structure the covariance matrices for reliable estimation.
- [stats/shares] Shrinkage on top: the joint covariance is replaced by the average of
  the structured matrix and its empirical diagonal (ridge-like), halving the
  cross-terms. Methods ^f5
  > replacing the joint covariance matrix of (Zt| , Wt| )| by the average of the structured covariance matrix and its empirical diagonal.
- [stats/shares] Opt-out: 7 of 51 states (two non-contiguous, five with the lowest
  in-sample multiple correlation with other states, regions and the nation) get a
  stand-alone model using only their own and national data. Methods ^f6
  > For these seven states, due to either the geological discontinuity or the low multiple correlation, it is not clear if using information cross the other states or other regions can help the state-level %ILI estimation.
- [stats/shares] The authors credit the gain over a per-state regression approach to
  multi-resolution pooling, one joint structured covariance instead of per-state
  regressions on other states, and the connected/stand-alone split. Discussion ^f7
  > capturing the spatio-temporal information using one joint statistically structured variance-covariance matrix as opposed to ad hoc regression of each individual state’s %ILI on other states’
- [stats/shares] Only ARGOX beat the naive method in all 51 states in MSE. Results ^f8
  > ARGOX is the only one that uniformly outperforms the naive method in all 51 states/district/city in terms of MSE for the whole period of evaluation.
- [stats/shares] (inferred) For us: the same recipe fits "EUW1 move = own noisy move
  combined with the world's and similar regions' moves": predict EUW1's patch move by
  the best linear predictor from (EUW1 own, rest pooled, per-cluster pooled) moves,
  with a covariance learnt across champions and past patches, structured and halved
  towards diagonal; KR and VN would be the "stand-alone" regions (lowest multiple
  correlation), not pooled into the predictor. ^f9
- [stats/shares] Checked, not there: no ablation removing the cross-state or national
  terms alone, so the share of the 28% due to cross-region pooling is unknown. ^f10

## Read

- Key points, results (tables 1-2 text), discussion, methods first and second steps,
  supplementary multiple-correlation section.

## Not read

- Per-state supplementary tables S5 onwards; the follow-up joint COVID and flu model
  (arXiv 2202.02621) that adds neighbouring states' cases.
