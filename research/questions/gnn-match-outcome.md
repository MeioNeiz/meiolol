---
status: answered
priority: soon
area: stats
tags: [method]
description: Have graph neural nets helped match outcome prediction, and where?
---
# Have graph neural nets helped match outcome prediction, and where?

Feeds: coordinator meiolol-76 (Jacob asked, 2026-10-13): whether a GNN or GBDT is worth a
run in the neural net programme. Builds on [[nn-draft-models]], [[draft-predictor-methods]],
[[pregame-player-skill]].

## Answer

Not where it would help us. (a) Draft as a graph: no source shows a GNN over the ten
picks beating flat or set models on a time split; a graph attention model alone lost to a
flat vector (CS:GO and NFL) and added about 2% log loss on top of one, on a random split
over game states (C1). (b) Champion graphs from co-play: pretrained hero-graph embeddings
tied a learnt embedding layer in the same net (0.639 vs 0.637), saving only training
time (C2). (c) Player graph: forward-only message passing (TrueSkill Through Time) beats
TrueSkill by 0.0002-0.004 in probability per game, its large gains need a player's later
games (a leak for us), and graph ratings give new players the average, so their gain
shrinks as new players grow (C3). Tencent's industrial fix for new players is a prior
from their first games' own performance stats, not a graph (C4). (d) GBDT on dense
features around a strong rating won a soccer forecasting challenge on future games, but
most of the signal was the rating and no source compares GBDT with LR on the same
features (C5); on one-hot ids trees lose ([[draft-predictor-methods]] C3).

Ranked for us (C6): (1) GBDT on dense features (player experience, account history, comp
profiles) with the ratings logit as base margin: worth one run, expected +0.1-0.5
accuracy points; (2) for thin-history players, a QuickSkill-style prior from their own
earlier match stats and games on other champions, as features in the existing model: the
non-graph version of (c), cheap; (3) a player-graph GNN: not worth it at 16 days of
history, under 0.1 point expected; (4) champion-graph embeddings and (5) a draft GNN: no.
Searches for (a) and (c) as GNNs saturated (last three found nothing new).

## Claims

- C1: No published GNN over a draft or lineup beats flat or set models on a time split; graph alone lost to a flat vector and added about 2% on top of one, on a random split. for: [[xenopoulos-gnn-sports-2022#^f3]], [[esta-csgo-2022#^f4]], [[gcn-wp-2022#^f5]]
- C2: Champion-graph embeddings from co-play or results match learnt id embeddings but do not beat them. for: [[optmatch-2020#^f7]], [[linnet-2017#^f5]]
- C3: Player-graph rating methods help weak rating systems slightly on forward tests and give nothing to players without games. for: [[gelo-2022#^f4]], [[gelo-2022#^f5]], [[gelo-2022#^f6]], [[trueskill-through-time-2025#^f4]], [[trueskill-through-time-2025#^f5]]
- C4: Industrial cold-start skill uses a new player's own in-game performance stats from first games, not a graph (54.0% to 61.6% higher-rated side wins, possibly optimistic). for: [[quickskill-2022#^f2]], [[quickskill-2022#^f5]], [[quickskill-2022#^f8]]
- C5: GBDT on dense rating-centred features wins forward tests, most signal being the rating; graph features add about 0.0006 RPS. for: [[hubacek-soccer-gbdt-2019#^f4]], [[hubacek-soccer-gbdt-2019#^f5]], [[hubacek-soccer-gbdt-2019#^f8]] against: [[jcj-lol-draft#^f3]]
- C6 (inferred): Run GBDT on dense features with the ratings margin and a QuickSkill-style own-stats prior; skip graph nets. from: C1, C2, C3, C4, C5
- C7: OptMatch's LoL time-split lift (LR 0.599, XGBoost 0.613, OptMatch 0.661) mixes player identity and stats with hero vectors, so it is not a graph-vs-no-graph test. for: [[optmatch-2020#^f6]], [[optmatch-2020#^f10]]

## Disagreements

None between sources; the open question is whether GBDT beats LR on the same dense
features, which no source tests.

## Open

- Leads: KEGC (NetEase, paywalled), Elo-MMR.
- GBDT vs LR with identical dense features on our folds: our run to make.
