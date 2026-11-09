---
status: answered
priority: soon
area: stats
tags: [method, stats, method/dynamics, stats/eb, method/causal]
description: Which published methods use the structure our data has (patch notes, regions that move alike but not as one, rare picks winning less, partial pre-game mastery, store lag and a leaky stored rank, selection effects, early regions' day-0 games), with what gains on similar data, and which should we try first?
---
# Which published methods use the structure our data has (patch notes, regions that move alike but not as one, rare picks winning less, partial pre-game mastery, store lag and a leaky stored rank, selection effects, early regions' day-0 games), with what gains on similar data, and which should we try first?

Feeds: data/team/2026-11-09-more/modelresearch-proposals.md; docs/plan/estimates.md (Meio)

Builds on: [[frontier-dynamics]], [[patch-transfer]], [[patch-shift-nets]],
[[frontier-causal]], [[pregame-player-skill]], [[thin-cell-ranges]], [[effect-isolation]].

## Answer

Each structure has a published method; gains on data like ours are modest and most need a
guard. Rare picks: Meio's hinge lines are covariate EB for the mean (C10); fitting the
spread by popularity too (CLOSE) took 86% of the oracle gain vs 31-50% (C11), the direct
fix for Meio's too-narrow rare ranges, scored by coupled bootstrap (C12). Regions: shared
move plus per-region scale and shift (C1), borrowing only where alike and less for
precise cells (C2), as a structured best linear predictor with unlike regions opted out
(C3, C4). Day 0: borrow at a weight between pooled and separate, by measured similarity
(C5); a well-updated prior matters more than the cross-market term (C6); our JP SG TW OC
lead fits (C7). Patches: a known break is a variance step plus reversion (C8), but a few
breaks estimate it badly and no source uses change lists (C9); our changed-champion
checks were null too (docs/model.md "Day-0 shares on the changed champions"): wait for
more boundaries. Mastery: impute without the result plus per-seat indicators (C13), test
the coverage shift 1 in 15 to 1 in 3 (C14); gains need informative missingness (C15).
Leaky rank: time stamps are the fix, repair often fails (C16); outcome-aware imputation
from the since-13-Oct games, selection modelled (C17). Store lag is a reporting triangle
(C18). Selection: match on pre-choice state and propensity, score the change in win
chance (C19); the within-deck contrast flags ride-along items (C20).

Search state: regions, day 0, missing data, nowcasting slowing; patch breaks saturated;
selection 2 searches, no peer-reviewed MOBA item estimate.

## Claims

- C1: One model with shared weights plus per-domain weights and per-domain scale and shift
  beats both one pooled model and implicit sharing, in every domain; the per-domain scale
  and shift is most of the gain. for: [[sheng-2021-star#^f4]], [[sheng-2021-star#^f5]],
  [[bonab-2021-xmrec-forec#^f2]]
- C2: Borrowing across correlated outcomes pays only at high correlation (gain 10-12% at
  0.75, about 0 to -2.5% at 0.25) and can hurt the most precise units; transfer to a thin
  target can lose. for: [[ito-kubokawa-2018-multivariate-fh#^f3]],
  [[ito-kubokawa-2018-multivariate-fh#^f5]], [[bonab-2021-xmrec-forec#^f5]]
- C3: A structured best linear predictor (own, regional, national moves; one shared
  covariance, shrunk; unlike units opted out) beat naive in all 51 states, up to 28% MSE;
  an unstructured VAR never did. for: [[yang-2020-argox-state-flu#^f1]],
  [[yang-2020-argox-state-flu#^f2]], [[yang-2020-argox-state-flu#^f6]]
- C4 (inferred): EUW1's patch share move should be a weighted mix of its own and the
  rest's (KR, VN2 out), the weight falling with EUW1's own sample. from: C2, C3
- C5: Cross-market diffusion forecasts best at a mixing weight between one market and
  separate ones (0.7), with proximity by trade and travel beating geography. for:
  [[everdingen-2003-intl-diffusion-kalman#^f2]], [[hartman-2012-cross-country-diffusion#^f3]],
  [[hartman-2012-cross-country-diffusion#^f4]], [[bonab-2021-xmrec-forec#^f4]]
- C6: The cross-market term adds less than a well-updated prior (MAPE 8/14/12 with, 9/16/16
  without, 14/27/39 plain per-country fit), and the speed prior matters most. for:
  [[everdingen-2003-intl-diffusion-kalman#^f3]], [[everdingen-2003-intl-diffusion-kalman#^f5]]
- C7 (inferred): For EUW1 day 0, a shrunk lead slope from JP SG TW OC (measured slope
  0.45, rho 0.6-0.7; KR VN2 rho 0.4, data/team/2026-11-05-notes2/modelresearch/leadlag.out)
  is the transfer form these sources support. from: C5, C6
- C8: Sports state-space models give a known break its own variance step (5-12 weeks'
  worth) and 31-46% reversion; Glicko fits its variance steps by one-step-ahead log loss.
  for: [[lopez-2018-best-team-win#^f1]], [[lopez-2018-best-team-win#^f2]],
  [[lopez-2018-best-team-win#^f4]], [[glickman-1999-dynamic-paired#^f5]]
- C9: Few breaks estimate break parameters poorly, and neither source sets a unit's break
  variance from known changes. for: [[lopez-2018-best-team-win#^f6]],
  [[lopez-2018-best-team-win#^f8]], [[glickman-1999-dynamic-paired#^f2]]
- C10: Covariate EB (prior mean from any regression on covariates incl. sample size,
  cross-fitted) beats raw and the regression alone, gaining at small N; plain EB pulls rare
  underperformers up wrongly. for: [[ignatiadis-wager-2019-covariate-eb#^f4]],
  [[ignatiadis-wager-2019-covariate-eb#^f5]]
- C11: When precision predicts the true effect, fitting the prior's spread as a function
  of precision as well as its mean (CLOSE) captures 86% of the oracle gain vs 31-50%;
  standard EB can do worse than raw. for: [[chen-2022-close-eb#^f7]],
  [[chen-2022-close-eb#^f9]] against: [[ignatiadis-wager-2019-covariate-eb#^f6]]
- C12: The coupled bootstrap scores any shrinkage rule without assuming its prior. for:
  [[chen-2022-close-eb#^f10]]
- C13: For prediction with missingness at deployment: impute from observed covariates
  without the outcome and add missing indicators; indicators help when missingness is
  informative and don't hurt otherwise. for: [[sisk-2023-mim-prediction#^f2]],
  [[sisk-2023-mim-prediction#^f4]], [[van-ness-2022-missing-indicator#^f1]],
  [[van-ness-2022-missing-indicator#^f5]], [[josse-2019-consistency-missing#^f5]]
- C14: Imputation must match between training and serving, and a missingness pattern that
  changes between them is a distribution shift. for: [[josse-2019-consistency-missing#^f3]],
  [[josse-2019-consistency-missing#^f6]], [[sisk-2023-mim-prediction#^f5]],
  [[sisk-2023-mim-prediction#^f7]]
- C15: On real data the missing-data methods often tie; indicator models win clearly only
  under outcome-related missingness. for: [[fletcher-mercaldo-2020-pattern-submodel#^f5]],
  [[fletcher-mercaldo-2020-pattern-submodel#^f6]], [[fletcher-mercaldo-2020-pattern-submodel#^f3]]
- C16: Leakage is avoided by time-stamping each record and cutting by time; repairing it
  afterwards often only partly works. for: [[kaufman-2011-leakage#^f2]],
  [[kaufman-2011-leakage#^f3]], [[kaufman-2011-leakage#^f5]]
- C17: With a validation subset, imputation conditioned on the outcome handles
  differential measurement error, where regression calibration is biased; a non-random
  subset needs its selection modelled. for: [[keogh-bartlett-2019-me-missing#^f4]],
  [[keogh-bartlett-2019-me-missing#^f5]], [[keogh-bartlett-2019-me-missing#^f7]]
- C18: Reporting delays are nowcast from a reporting triangle with a random walk on the
  true value; a delay cap must cover the tail, and intervals from past real-time errors
  calibrate best. for: [[mcgough-2020-nobbs#^f2]], [[mcgough-2020-nobbs#^f5]],
  [[wolffram-2023-collab-nowcast#^f4]], [[wolffram-2023-collab-nowcast#^f5]],
  [[wolffram-2023-collab-nowcast#^f8]]
- C19: In-game choices whose takers differ are compared by matching on the pre-choice
  state and the propensity to choose, scoring the change in win probability with a
  bootstrap. for: [[yam-lopez-2019-fourth-down#^f1]], [[yam-lopez-2019-fourth-down#^f2]]
- C20: Card-draft stats contrast games where a card was drawn with games where it sat in
  the deck unseen; a high raw rate with a negative contrast marks a card riding good
  decks, and Blitz shows a pre-buy win rate beside item win rates. for:
  [[mtg-causal-drafts-2026#^f1]], [[mtg-causal-drafts-2026#^f3]],
  [[blitz-darius-vs-garen#^f5]] against: [[mtg-causal-drafts-2026#^f2]]

## Disagreements

C11: Ignatiadis-Wager keep one prior variance; Chen fits it by precision. Our rare misses
(1.2-3.7x sd, docs/model.md "The lean table") side with Chen; C12 settles it on our cells.

## Open

- Per-unit break variance from change exposure (C9): no source; needs 16.23+ boundaries
- Leads: Brill-Yurko-Wyner (win-model uncertainty), Queen-Albers, Gao et al. (brackets)
