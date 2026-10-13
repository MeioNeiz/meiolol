---
status: answered
priority: now
area: stats
tags: [method, stats]
description: How do you measure how much of the draft's effect on winning runs through the early-game state, and what are the pitfalls?
---
# How do you measure how much of the draft's effect on winning runs through the early-game state, and what are the pitfalls?

Feeds: meiolol-state (P(win | draft, full state at minute t), importance by minute) and
meiolol-draftpath (how drafts win, draft vs state over time, mediation through the early
lead); coordinator meiolol-bd. Jacob: accurate win prediction from draft plus in-game
state, and how much each thing matters.

## Answer

With win as the outcome (about 50%, far from rare), the familiar shortcuts are invalid:
product of coefficients, the difference method (draft coefficient with and without gold
in a logistic model) and the rare-outcome odds-ratio formulas, because odds ratios are
non-collapsible (C1). The logistic difference method understates a real indirect effect
and is non-zero even with no mediation (C2). Estimate on the probability scale by
simulation (g-computation), which works with any mediator and outcome model (C1).
Mediator-outcome confounding must be handled even if the draft were randomised; here
player skill on the champion raises gold at 14, the draft score and the win chance, and
matchmaking balances MMR, not mastery (C3). Fit the draft-by-state interaction and report
indirect effects per arm; ignoring it can make an effect look fully mediated (C4). With
the 14:00 state as several correlated mediators, and earlier minutes confounding later
ones, natural effects are not identified: use interventional effects on the joint state,
and never sum per-mediator shares (C5). A noisy mediator (gold at 14 standing in for
"being ahead") biases the indirect effect toward zero, so the indirect share is a lower
bound (C6). Report a sensitivity analysis for unmeasured mediator-outcome confounding;
without it a mediation analysis is incomplete (C3). A "proportion mediated" is meaningful
only when indirect and total effects share a sign (C7). The only sport mediation paper
found splits soccer home advantage into team performance and referee bias; no esports
work does counterfactual mediation with a binary result (C8).

Do this (meiolol-draftpath, C9). Estimand: interventional indirect and direct effects in
win points per sd of the draft model's pre-game logit (and a curve over draft quintiles);
covariates: side, patch, rank, player-history features where present. Mediator: the
joint 14:00 state; gold at 14 alone as secondary. Mediator model: draw real 14:00 states
from games with similar covariates and draft score d* (matching or reweighting), not a
parametric generator. Outcome model: P(win | draft, state14, covariates) with
interactions (meiolol-state's minute-14 model if it takes the draft logit). Per game
Q(d,d), Q(d,d*), Q(d*,d*); indirect = Q(d,d) - Q(d,d*), direct = Q(d,d*) - Q(d*,d*);
game bootstrap. Avoid c - c', a*b, odds-ratio formulas, comparing logit coefficients
across nested models, a binary "ahead at 14" mediator. Sensitivity: on the subset with
player history, estimate with and without it (how far measured skill moves the share),
then Imai's rho curve or VanderWeele's bias-factor table. Report total, direct and
indirect with intervals, the proportion only when signs agree, each minute (5, 10, 14,
20) as its own analysis, the interaction split and the sensitivity result.

## Claims

- C1: With a common binary outcome, product, difference and rare-outcome odds-ratio methods are invalid (non-collapsibility); simulation on the probability scale works with any models. for: [[vanderweele-mediation-guide-2016#^f8]], [[vanderweele-mediation-guide-2016#^f9]], [[vanderweele-vansteelandt-or-mediation-2010#^f4]], [[imai-keele-tingley-mediation-2010#^f4]], [[imai-keele-tingley-mediation-2010#^f7]]
- C2: The logistic difference method understates a real indirect effect and is non-zero with no mediation. for: [[rijnhart-logistic-mediation-2019#^f3]], [[rijnhart-logistic-mediation-2019#^f4]], [[vanderweele-mediation-guide-2016#^f10]]
- C3: Mediator-outcome confounding must be adjusted for even with a randomised treatment, and a sensitivity analysis reported. for: [[vanderweele-mediation-guide-2016#^f4]], [[vanderweele-mediation-guide-2016#^f12]], [[vanderweele-mediation-guide-2016#^f13]], [[imai-keele-tingley-mediation-2010#^f11]], [[imai-keele-tingley-mediation-2010#^f12]], [[imai-keele-tingley-mediation-2010#^f14]], [[vanderweele-vansteelandt-or-mediation-2010#^f9]]
- C4: Treatment-mediator interaction must be fitted; ignoring it can make an effect look fully mediated. for: [[vanderweele-mediation-guide-2016#^f5]], [[vanderweele-vansteelandt-or-mediation-2010#^f5]], [[vanderweele-vansteelandt-or-mediation-2010#^f6]], [[imai-keele-tingley-mediation-2010#^f5]]
- C5: With several correlated or time-ordered mediators, natural effects are not identified; interventional effects are and add up to the total; per-mediator shares do not sum. for: [[vansteelandt-daniel-interventional-2017#^f1]], [[vansteelandt-daniel-interventional-2017#^f9]], [[vanderweele-tchetgen-time-varying-2017#^f1]], [[vanderweele-tchetgen-time-varying-2017#^f2]], [[vanderweele-mediation-guide-2016#^f15]]
- C6: Nondifferential measurement error in the mediator biases the indirect effect toward zero and the direct effect away from it. for: [[vanderweele-mediation-guide-2016#^f14]]
- C7: Latent-scale proportions differ from probability-scale ones; a proportion mediated is meaningful only when indirect and total share a sign. for: [[imai-keele-tingley-mediation-2010#^f8]]
- C8: The one sport mediation found split soccer home advantage into team performance and referee bias; no esports counterfactual mediation exists. for: [[bilalic-ham-home-advantage-2021#^f8]], [[bilalic-ham-home-advantage-2021#^f10]]
- C9 (inferred): Our recipe in the Answer. from: C1, C3, C4, C5, C6, C7

## Disagreements

None between sources; Rijnhart's example shows the methods disagree most with binary
mediators (7% vs 25% mediated), a reason to keep gold at 14 continuous.

## Open

- Leads: Ding and VanderWeele 2016 sharp bounds; VanderWeele, Vansteelandt and Robins
  2014; Valeri, Lin and VanderWeele 2014 (mediator measurement error); Tchetgen Tchetgen
  2014 (common outcomes); Loh et al. 2019; Rijnhart 2021.
