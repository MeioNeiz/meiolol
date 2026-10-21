---
status: answered
priority: soon
area: stats
tags: [method, method/tabular, method/ensemble, method/interpret, method/pretrain, method/causal, method/dynamics, method/ceiling]
description: Which new experiments could push draft win prediction and our understanding of why drafts win past what meiolol has tried, given a 3080 gpu-box and 1.4M+ games?
decision: docs/plan/lab-frontier.md
---
# Which new experiments could push draft win prediction and our understanding of why drafts win past what meiolol has tried, given a 3080 gpu-box and 1.4M+ games?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme)

Children (one reader each, 21 Oct): [[frontier-ceiling]], [[frontier-tabular-ensembles]],
[[frontier-interactions]], [[frontier-causal]], [[frontier-dynamics]],
[[frontier-pretrain]]. Inventory of what we tried: docs/plan/lab-frontier.md "Already
tried".

## Answer

The draft holds little information: with a calibrated true logit of sd s, accuracy is
about 50% + 20 s points and the log loss gain s^2/8, so today's 54.8% is s 0.25 and 56%
needs s 0.30, 3.6 milli-nats more (C1). The ceiling can be measured from the data as
summed variance components rather than guessed (C2). Accuracy past that comes from who
plays (player history, mastery: internal only), not from bigger draft models (C3).

Within the draft, the gains with evidence are cheap: post-hoc ensemble selection over
the forward-fold predictions we already have, TabM in place of seed ensembles, a
field-aware FM member, and refitting on the newest games (C4). Tabular foundation
models, contrastive pretraining, LLM predictors and dynamic Kalman ratings are not worth
a run beyond a yardstick (C5). For "why", a 10-seat draft decomposes exactly, so the
work is in trusting the pairs: knockoff seats, planted pairs and agreement across seeds
(C6). For truth, observed champion strengths mix in their pickers' mastery, and only
random or blind assignment (ARAM, Swiftplay) tests causality; match-v5 has no pick order
(C7). Time: a static fit plus a shrunk patch part is the structure that works, worth at
most ~1 milli-nat on a new patch's first days (C8).

## Claims

- C1: Ceiling arithmetic: accuracy ~50% + 20 s, log loss gain ~s^2/8; ours is s 0.25. for: [[ishida-bayes-error-2023#^f1]], [[bayes-optimal-ber-auc-2026#^f1]]
- C2: A feature set's total explained variance can be estimated without building the predictor, and exceeds what effects tested one by one show. for: [[yang-gcta-height-2010#^f1]], [[yang-gcta-height-2010#^f2]], [[aoki-luck-sports-2017#^f1]]
- C3: Matchmaking balances MMR, not champion familiarity, so player-champion information stays predictive. for: [[riot-dev-matchmaking-real-talk-2018#^f1]], [[riot-dev-matchmaking-real-talk-2018#^f2]]
- C4: Ensemble selection with replacement and bagging, TabM, and field-aware FM are the measured tabular gains; validation on the newest slice costs under drift. for: [[caruana-ensemble-selection-2004#^f4]], [[temporal-shift-tabular-2025#^f1]], [[bars-ctr-2021#^f3]], [[temporal-shift-tabular-2025#^f3]]
- C5: Foundation models need 50 GB GPUs and one bars production use; representation of well-seen entities doesn't matter; LLM forecasters restate the market; variance tracking adds nothing on noisy outcomes. for: [[tabiclv2-2026#^f1]], [[tabpfn3-2026#^f6]], [[bertram-card-representations-2024#^f1]], [[worldcup-llm-forecast-2026#^f2]], [[szczecinski-kalman-rating-2021#^f4]]
- C6: Order-n Shapley interactions recover an order-n additive model exactly; naive pair scores fail FDR, knockoffs control it; one net's interactions are fragile. for: [[bordt-nshapley-gam-2023#^f2]], [[chen-diamond-fdr-interactions-2024#^f2]], [[li-fis-rashomon-2024#^f3]]
- C7: No pick order in match-v5; ARAM's first roll is uniform over available champions; a champion's rate mixes its pickers' mastery. for: [[meiolol-pick-order-check#^f1]], [[ask-riot-aram-random#^f1]], [[phroxzon-interview-2023#^f1]]
- C8: Static strength plus a shrunk time-varying part forecasts best on noisy outcomes; long memory wins. for: [[koren-temporal-2009#^f4]], [[ley-soccer-current-strength-2019#^f3]]

## Disagreements

- Tabular: TabM scaled best on a 4M-row time split, but every expected size is read
  across from other domains; none is measured on a near-coin-flip target.

## Open

- The draft ceiling itself (lab-frontier B1), and whether the set net's lead is pairs
  or comp traits (C1 there).
- Whether the plateau is drift or noise (E1): the dynamics reader expects noise.
