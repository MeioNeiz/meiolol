---
status: answered
priority: now
area: stats
tags: [method, stats]
description: Which feature importance and attribution methods hold up under correlated features, for saying how much each thing matters to win prediction?
---
# Which feature importance and attribution methods hold up under correlated features, for saying how much each thing matters to win prediction?

Feeds: meiolol-state (P(win | draft, full state at minute t), importance by minute) and
meiolol-draftpath (how drafts win, draft vs state over time, mediation through the early
lead); coordinator meiolol-bd. Jacob: accurate win prediction from draft plus in-game
state, and how much each thing matters.

## Answer

No method gives a correlation-free importance for each feature. Plain permutation
importance and interventional SHAP score the model on impossible rows (a big gold lead
with no towers) and overstate correlated features in trees and nets, a bias that stays
as the sample grows (C1). Any measure that removes correlation must score rows where
data is sparse; refitting without a feature (LOCO) avoids that bias but counts only the
feature's unique share (C2). The recommended way is to group correlated features in
advance and drop-and-refit per group, scored by log loss, with intervals from
cross-fitting and influence functions; near zero, test against a minimum meaningful size
on a separate split, since 230k games makes everything significant (C3, C4). Shapley
shares depend on which features count as players, so groups are fixed before looking
(C5). Interventional and observational Shapley answer different questions: what this
model uses vs what the data says (C6).

Do this (meiolol-state, C7): fixed groups of similar size (economy: gold, XP, kills, CS
leads; levels if kept apart; towers and plates; dragons with soul state; barons, heralds
and inhibitors; vision if present; draft prior), one or two summary features each. Per
minute bucket (5, 10, 15, 20, 25, 30+), LightGBM with 5-fold cross-fitting on one row per
game. Report in log-loss skill: unique share (full minus refit without the group), alone
share (group alone vs base rate), and exact Shapley over the groups by refitting (2^7 =
128 subsets per bucket, cheap on the gpu-box), side by side; the gap between unique and
alone is shared signal no method assigns without a convention. Intervals: Williamson
influence-function errors (already clustered with one row per game), or a game bootstrap
when minutes are pooled. Avoid: plain or out-of-bag permutation, mean |SHAP| per raw
column as importance, SAGE with marginal sampling, Strobl's conditional forest
importance, and comparing shares across different feature lists.

## Claims

- C1: Plain permutation importance and interventional SHAP give unreliable importance for correlated features in GBDT and neural models; the bias persists with sample size. for: [[hooker-2021-permutation-extrapolation#^f1]], [[hooker-2021-permutation-extrapolation#^f3]], [[kumar-2020-shapley-problems#^f1]], [[molnar-2023-conditional-subgroup#^f4]]
- C2: Removing correlation from importance forces scoring in sparse regions; refit (LOCO) avoids that bias but gives only the unique share. for: [[verdinelli-2023-shapley-loco#^f2]], [[verdinelli-2023-shapley-loco#^f3]], [[hooker-2021-permutation-extrapolation#^f5]], [[hooker-2021-permutation-extrapolation#^f6]]
- C3: Group correlated features and refit; with near-copy groups permutation called both important while refit showed them interchangeable. for: [[williamson-2023-vim-inference#^f7]], [[au-2022-grouped-importance#^f3]], [[au-2022-grouped-importance#^f4]], [[verdinelli-2023-shapley-loco#^f6]]
- C4: Refit importance by deviance gets valid intervals from cross-fitting; testing zero needs a separate split, and near zero intervals are variability intervals. for: [[williamson-2023-vim-inference#^f1]], [[williamson-2023-vim-inference#^f5]], [[williamson-2023-vim-inference#^f6]], [[verdinelli-2023-shapley-loco#^f5]]
- C5: Shapley shares change with the set of players (a redundant copy changes every share), so groups are fixed in advance. for: [[kumar-2020-shapley-problems#^f3]], [[au-2022-grouped-importance#^f6]]
- C6: Interventional Shapley explains the model, observational the data; they answer different questions. for: [[chen-2020-true-to-model#^f3]], [[janzing-2020-causal-shapley#^f2]]
- C7 (inferred): For our win model by minute: fixed groups, cross-fitted LightGBM per bucket, unique, alone and group-Shapley shares by refit, influence-function or game-bootstrap intervals. from: C1, C2, C3, C4, C5

## Disagreements

- Conditional measures (Strobl, Molnar subgroups) vs refit: both aim at the unique share;
  conditional sampling fails when a feature depends on many others (gold lead), refit
  does not. No disagreement on the recommendation.

## Open

- Leads: Williamson and Feng 2020 (Shapley over groups with intervals); Chamma et al.
  2023 (conditional permutation with valid tests).
