---
status: answered
priority: now
area: stats
tags: [method, stats, draft]
description: How do sports and esports analytics isolate the value of in-game events and of pairwise synergy and counters?
---
# How do sports and esports analytics isolate the value of in-game events and of pairwise synergy and counters?

Feeds: meiolol-08's effects table and CPU model (docs/model.md "### Effects and the CPU
model"): how to put a number with an interval on a tower, dragon, synergy, counter or comp,
in win points and gold. Builds on [[draft-predictor-methods]], [[comp-attribute-features]],
[[nn-draft-models]]. Ours: lane opponent moves gold@14 by 75-200; other enemy pairs bounded
35-45; ally synergy on win not detected at 90k (docs/model.md).

## Answer

Events. Sports and esports value an event by the change in a calibrated win (or points)
model across it, averaged per event type (C1). They handle "already ahead" only by
putting the lead into the model's state; whatever the state misses (team strength, comp)
still inflates the value, and the win model must be chosen for calibration (C2, C4).
Single events are noisy: only averages over similar states mean anything, with intervals
from resampling whole games or drives (C3). Report the mean starting win chance beside
win points added: in 400k ranked LoL games raw item win rates ranked items wrongly (C5).
Short-horizon labels (the next 10 actions, VAEP) are less noisy than the final result
(C6). No public per-objective win-points value exists for LoL, solo queue or pro; site
"first baron 83-87%" figures are pure "already ahead" (C7). Natural experiments are rare
and fragile: a famous "slightly behind at half-time wins more" effect (6-8 points) fell
to 1.2 points, not significant, at scale (C8). Our cleanest one is the drake element and
soul type, assigned by the game rather than chosen (C9).

Pairs. The standard is ridge (Gaussian) shrinkage with the penalty chosen on held-out
data, mains fitted jointly: it roughly doubled held-out fit over raw plus-minus (C10).
Pair values must be measured beyond both members' own effects, or they reward strong
champions (C11). Fitted on top of main effects, pair terms come out mostly null or sparse
and barely move the mains: 4 of 27k NHL pairs kept by lasso; 221 of the top 1,000 kept
with a held-out-tuned penalty; NBA pair share 3-9% against 3% under shuffled outcomes
(C12). Several pair blocks need a variance estimated per block, not one cross-validated
penalty (C13). Our "ally synergy not detected at 90k" is the expected result at this size
(C14). No source separates counter (opponent pair) variance from synergy; our measured
lane-opponent gold effect (75-200) has no published counterpart.

Methods for us, best first (C15). Pairs: (1) ridge logistic and ridge gold@14 with mains
plus 35 role-pair blocks; (2) empirical Bayes tau per block (how much a role pair matters
in total); (3) shuffled-outcome null; (4) game bootstrap; (5) low-rank pairs on residuals;
(6) attribute-based pair prior. Events: (1) win points added by event type within minute
x win-chance bands, game bootstrap, with mean starting win chance; (2) richer state
(draft win chance, rank, buff and inhibitor timers) chosen by calibration; (3)
short-horizon gold labels; (4) gold equivalent through the win-per-gold slope; (5) ridge
credit split within fight windows; (6) drake element as a natural experiment; (7)
near-even contests only as a check.

## Claims

- C1: Event value is the change in a calibrated win or points model across the event, averaged per event type. for: [[xenopoulos-csgo-wpa-2020#^f1]], [[yurko-nflwar-2019#^f1]], [[decroos-vaep-2019#^f1]], [[maymin-lol-optical-tracking#^f4]]
- C2: These methods handle "already ahead" only through the model's state; what the state misses (team strength, comp) inflates event values. for: [[xenopoulos-csgo-wpa-2020#^f8]], [[decroos-vaep-2019#^f6]], [[jalovaara-lol-wpa-items-2024#^f1]]
- C3: Single-event win changes are unreliable; average over many similar states and resample whole games or drives for intervals. for: [[jalovaara-lol-wpa-items-2024#^f4]], [[yurko-nflwar-2019#^f8]], [[xenopoulos-csgo-wpa-2020#^f5]]
- C4: The win model behind event values must be chosen for calibration. for: [[xenopoulos-csgo-wpa-2020#^f3]], [[yurko-nflwar-2019#^f5]], [[decroos-vaep-2019#^f5]]
- C5: Report mean starting win chance beside win points added; raw win rate ranked LoL items wrongly (Heartsteel 54.15% raw but +0.66 added, Titanic Hydra +1.46). for: [[jalovaara-lol-wpa-items-2024#^f3]], [[jalovaara-lol-wpa-items-2024#^f8]]
- C6: Short-horizon labels (a goal in the next 10 actions) value actions with less noise than the final result; far-ahead states are down-weighted, not dropped. for: [[decroos-vaep-2019#^f3]], [[yurko-nflwar-2019#^f3]]
- C7: No public per-objective win-points value exists for LoL. for: [[maymin-lol-optical-tracking#^f7]], [[jalovaara-lol-wpa-items-2024#^f10]], [[riot-wp-dev-diary#^f5]]
- C8: A published effect of a game state can vanish at scale: "slightly behind at half-time" 5.8-8.0 points fell to 1.2 points, not significant, across four sports. for: [[klein-teeselink-losing-winning-2023#^f1]], [[klein-teeselink-losing-winning-2023#^f2]]
- C9 (inferred): Drake element and soul type are assigned by the game, so their effects (and comp x element) are identified free of "ahead" bias, given the soul was taken. from: C2
- C10: Ridge-regularised plus-minus with the penalty chosen on held-out data is the standard and roughly doubled held-out R2 (0.088 to 0.169). for: [[sill-2010-rapm#^f4]], [[sill-2010-rapm#^f6]], [[sill-2010-rapm#^f7]], [[hvattum-2019-plusminus-review#^f2]]
- C11: Pair values must be measured beyond both members' own effects, or they credit strong players or champions as synergy. for: [[devlin-2020-nba-lineup-spectral#^f2]], [[ramler-2019-lol-symbiosis#^f6]], [[bransen-2020-player-chemistry#^f8]]
- C12: Pair terms fitted on top of main effects are mostly null or sparse and barely move the mains. for: [[gramacy-2013-hockey-logistic#^f6]], [[thomas-2013-hockey-hazard#^f6]], [[thomas-2013-hockey-hazard#^f7]], [[thomas-2013-hockey-hazard#^f9]], [[devlin-2020-nba-lineup-spectral#^f4]]
- C13: Several shrinkage blocks need variances estimated per block (ML or hierarchical), not one cross-validated penalty. for: [[thomas-2013-hockey-hazard#^f2]], [[hvattum-2019-plusminus-review#^f3]], [[gelman-2005-anova#^f2]]
- C14 (inferred): Our "ally synergy not detected at 90k games" is the expected result at this size. from: C12
- C15 (inferred): Methods for us in the order of the Answer. from: C1, C2, C3, C5, C6, C10, C11, C12, C13

## Disagreements

- Pair chemistry from attributes: Maymin (B) and Bransen (B, vendor) predict synergy from
  skills; Bransen's held-out gain for unseen pairs was small (defence RMSE 0.8891 vs
  0.8908). An attribute prior explains a number but can manufacture synergy; test it
  against a zero prior on held-out games.

## Open

- Counter (opponent pair) variance as a share of outcome variance: not published.
- Leads: Maymin 2021 JQAS (paywalled); a CUNY 2021 Dota paper on marginal impact of kills
  and tower damage; arXiv 2110.14632 (causal effect of LoL patches by skill); Clark,
  Macdonald, Kloo 2020 Bayesian plus-minus for Dota 2 on gold; Sun, Schulte 2020 hockey
  model distilled into linear model trees.
- Objective steals as coin flips: match-v5 does not mark steals directly; untested.
