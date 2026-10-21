---
status: answered
priority: soon
area: stats
parent: frontier-experiments
tags: [method/dynamics, stats]
description: How should champion strength be modelled over time (patch jumps, meta shifts, player adoption lag), and which dynamic rating methods beat static or per-patch fits on future games?
---
# How should champion strength be modelled over time (patch jumps, meta shifts, player adoption lag), and which dynamic rating methods beat static or per-patch fits on future games?

Feeds: docs/plan/lab-frontier.md (gpu-box experiment programme), parent [[frontier-experiments]].
Builds on [[draft-predictor-methods]] C14 (stationary strength plus per-patch offset, not
recency weighting) and docs/model.md "Patch and rank context" (offsets not detected, one
boundary, 16.19 to 16.20).

## Answer

Dynamic ratings beat a static fit on future games only by little, and only when they
keep a stationary part. On forward splits a Gaussian-process rating with a constant plus
mean-reverting kernel gains 0.004-0.011 nats over Elo or TrueSkill; where outcomes are
noisy (football, chess) Elo is worse than a static fit, and Kalman-style variance
tracking adds nothing over plain Elo (C1, C4). With win-only outcomes the best memory is
long: decay as weak as the grid allows, or none (C2). The structure that works is a
stationary strength plus shrunk per-period offsets, or its state-space twins (constant
plus Matern GP, correlated skills per context) (C3). Our draft signal is weaker than any
of these sports, so expect at most about 1 milli-nat, mostly in a new patch's first days
(C11).

What moves LoL champions over time is known in kind: Riot patches champions outside a
49-54.5% win rate band back toward it, so a patch-day jump should be predictable in sign
from the previous patch's strength (C5). Patch-note counts predict poorly: effects run
through other champions, and a buff can draw newcomers who lower the win rate (C6, C8).
New champions and reworks start low and climb for about a month as players learn them,
and opponents learn too (C7). Stat sites bucket by patch without shrinkage, so their
patch-to-patch "winners" are largely noise ([[metabot-patch-25-22#^f3]], inferred).

Is the plateau in champion strength a drift limit? Probably not. The 1.39M games span
about four weeks and two patches, a decay of 3-7 days gained nothing, and the literature
says noise, not staleness, limits win-only ratings (C2). The clean test holds the game
count fixed: newest-W games vs the same number spread over all days vs the oldest (C10).
Experiment order: C12. Search state: stat-site and
new-champion time-course angles saturated (3 searches found no systematic data).

## Claims

- C1: Over a static fit, flexible dynamic ratings gain little on forward prediction (0.004-0.011 nats over Elo or TrueSkill in sports; TTT 0.0002-0.004 over TrueSkill), and on noisy outcomes Elo loses to the static fit. for: [[maystre-kickscore-2019#^f5]], [[maystre-kickscore-2019#^f4]], [[trueskill-through-time-2025#^f4]], [[trueskill-through-time-2025#^f5]]
- C2: With win-only or noisy outcomes, long memory wins: decay helps less the less a game tells you, and moderate to no decay forecasts best. for: [[ley-soccer-current-strength-2019#^f3]], [[koren-temporal-2009#^f2]], [[jcj-lol-draft#^f7]], [[gama-drift-survey-2014#^f2]], [[gama-drift-survey-2014#^f3]]
- C3: The structure that works is stationary strength plus a shrunk time-varying part: per-bin offsets, a constant plus Matern kernel, or correlated per-context skills; adjacent-patch smoothing helps at small data. for: [[koren-temporal-2009#^f4]], [[maystre-kickscore-2019#^f2]], [[maystre-kickscore-2019#^f1]], [[ingram-extend-elo-2021#^f2]], [[loldraftai#^f14]]
- C4: Kalman, Glicko and TrueSkill style variance tracking adds nothing over SGD (Elo) on noisy outcomes; its payoff is faster settling after a change. for: [[szczecinski-kalman-rating-2021#^f4]], [[szczecinski-kalman-rating-2021#^f5]], [[szczecinski-kalman-rating-2021#^f6]], [[szczecinski-kalman-rating-2021#^f3]], [[ingram-extend-elo-2021#^f3]]
- C5: Riot's balance process pulls champion win rates into a band (49% floor, 52-54.5% ceiling by audience and ban rate), and champions further from 50% get patched more. for: [[riot-balance-framework-2019#^f1]], [[riot-balance-framework-2019#^f2]], [[kica-claypool-lol-patches#^f2]], [[kica-claypool-lol-patches#^f3]]
- C6: Counting buffs and nerfs predicts a champion's win rate change poorly; other champions' changes move it (role rivals' win rates anti-correlate). for: [[kica-claypool-lol-patches#^f4]], [[he-2021-patch-hte#^f4]]
- C7: New champions and reworks launch below their long-term strength and climb for about a month as players learn them (about 4 pp per player over the first ~15 games); opponents' learning can pull the other way. for: [[riot-balancing-new-champions-2020#^f1]], [[riot-balancing-new-champions-2020#^f2]], [[riot-balancing-new-champions-2020#^f3]], [[riot-balancing-new-champions-2020#^f4]], [[riot-balance-framework-2019#^f4]]
- C8: A champion's raw win rate change across a patch mixes power with who plays it: mastery curves are steep, and a buff can bring an influx of inexperienced players that lowers it. for: [[riot-balance-framework-2019#^f5]], [[kica-claypool-lol-patches#^f4]], [[he-2021-patch-hte#^f5]], [[riot-balancing-new-champions-2020#^f2]]
- C9: Per-patch stat-site buckets present multi-point swings as patch effects with no intervals or shrinkage. for: [[metabot-patch-25-22#^f1]], [[metabot-patch-25-22#^f2]]
- C10: Whether more history hurts depends on the memory to shift-period ratio and the window's signal-to-noise; with noisy data recency is not relevance. for: [[giannakopoulos-demanding-lord-2012#^f1]], [[giannakopoulos-demanding-lord-2012#^f3]], [[gama-drift-survey-2014#^f2]]
- C11 (inferred): For us a patch-aware model can gain at most about 1 milli-nat on a new patch's first days and near 0 averaged: a 2 pp miss on the ~15 changed champions costs about E[delta^2]/8 per game, under 1 mnat, and per-patch offsets refit within days. from: C1, C2, C5
- C12 (inferred): Order: equal-N drift test, 16.21 boundary rerun scored by day since patch, mean-reversion patch prior, mastery-conditioned drift, then a state-space strength (kickscore or Kalman) only if a jump is detected. from: C1, C3, C4, C5, C8, C10, C11

## Disagreements

- Long memory: no decay best (Koren A, local drift, many ratings) and grid-edge half
  periods for win-only models (Ley B) vs accuracy falling toward the minimum as memory
  grows (Giannakopoulos C, total concept shifts). Drift type decides; LoL patches are
  local ([[lu-concept-drift-review#^f6]]). Our equal-N test settles it for our data.
- Launch learning sign: Riot says new champions climb (B) but Neeko fell after week one
  as opponents learned ([[riot-balancing-new-champions-2020#^f4]]). Per champion; a
  rising-trend prior must allow either sign.

## Open

- Size of real patch-day jumps on our games: unknown until 16.21 is in dev; measure per
  changed champion with intervals and the shuffled-patch control.
- Does the previous patch's offset predict the next jump's sign (mean reversion) on our
  data? Two boundaries are too few to fit a slope; pooling past patches would need
  older games (match-v5 history or another region's crawl).
- Numeric patch diffs: Data Dragon has base stats and cooldowns, not ability damage
  (MetaBot notes the same); CommunityDragon may have the rest. LLM reading of notes is
  frontier-pretrain's scope.
- Within-patch adaptation of existing champions (builds found over two weeks): no
  measured source found; our day-since-patch slope for changed vs unchanged champions
  would be the first.
- Not read: Wild-Time (lead), Glickman 1999, Cattelan et al. 2013 dynamic BT
  (paywalled).
