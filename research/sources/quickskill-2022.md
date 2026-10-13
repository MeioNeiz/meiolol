---
title: 'Zhang et al. 2022: QuickSkill, novice skill estimation in online multiplayer games (Tencent, CIKM)'
url: https://arxiv.org/pdf/2208.07704
kind: paper
commit: 
for: [gnn-match-outcome]
looked: 2026-10-13
depth: docs (sections 1-4.6, Tables 1-4)
relevance: high
grade: B/fair
description: Tencent CIKM 2022; a transformer reads a novice's in-game stat snapshots (115 features every 3 min) and predicts the TrueSkill2 rating they will have after 18 games; time split, 80M samples, mobile MOBA; no graph
---
# Zhang et al. 2022: QuickSkill, novice skill estimation in online multiplayer games (Tencent, CIKM)

Why: (c) how industry handles players with little history; is a player graph used, and
how much does a cold-start estimate add to outcome prediction?

## Assessment

- Evidence: B. Tencent production system (deployed, 20 ms serving), 80M samples, time
  split, five model baselines plus raw TrueSkill and TrueSkill2.
- Reasoning: fair. Clear ablations (sequence vs last snapshot, label K). But the
  outcome metric is the share of games won by the side with the higher summed rating,
  no log loss, no CIs on it, and it is unclear whether the scored game's own stats feed
  its rating (leak risk).
- Interests: authors' production system; game name withheld (NDA).
- Weigh: trust the direction (in-game performance beats win/loss counting for
  novices); discount the 61.6% headline until the leak question is settled. Not graph
  based: the industrial answer to cold start here is performance features, not a
  player graph.

## Findings

- [method] Cold start defined: TrueSkill and TrueSkill2 ratings are unreliable before
  about 18 games in their game. Section 3.1 ^f1
  > we set 𝐶 = 18 for TrueSkill and TrueSkill2 based on our observation on online deployment, as both models converge after 18 games.
- [method] Idea: regress a novice's future converged rating (game K = 18) from their
  in-game performance in the current game, and use it instead of the raw rating until
  the cold-start period ends. Section 3.1 ^f2
  > we design QuickSkill to “gaze into the future”, by predicting players’ future MMR scores given their game performance at novice stages.
- [method] Inputs: 115 features (own kills, deaths, gold and team and opponent
  context) sampled every 3 minutes, last 12 snapshots, plus line-up embedding; model is
  a transformer with attention across time and features. Section 4.1 ^f3
  > For each data, we collect 115 features for each snapshot, where snapshots are sampled every 3 minutes in a game.
- [data] Time split: 20 days collected, first 13 for training and validation, rest for
  test; normal 34M/4M/14M and ranked 44M/8M/28M samples. Section 4.1 ^f4
  > Both datasets are collected in 20 days, where data collected in the first 13 days are employed for training and validation, and the rest are for testing.
- [method] Table 3, share of games won by the side with the higher predicted rating
  (TrueSkill2 labels): raw TrueSkill2 54.0% normal, 53.6% ranked; LR on one-hot
  features 50.4%, 52.8%; MLP 60.8%, 60.4%; transformer 61.3%, 61.1%; MMR-Net 61.6%,
  61.5%; MMR-Net on end-of-game snapshot only 59.8%, 60.2%. ^f5
  > our MMR-Nets obtain up to 4% and 7.9% higher win-rateℎ , yielding a remarkable improvement.
- [method] The label's own ceiling is far higher: the converged TrueSkill2 rating at
  game 18 picks the winner 72.3% (normal) and 74.0% (ranked), vs QuickSkill 61.6% and
  61.5%. Table 4, K = 18 ^f6
  > TrueSkill2 always achieves better results over TrueSkill, for both QuickSkill prediction and ground truth.
- [method] TrueSkill2 labels beat TrueSkill labels throughout (TrueSkill-trained
  QuickSkill 55.4% and 54.7%). Section 4.3 ^f7
  > MMRs estimated by TrueSkill2 are more accurate than its TrueSkill, as models trained with TrueSkill2 labels achieve significantly better performance in terms of win-rateℎ .
- [method] Checked, not there: no player graph, teammates or opponents used for the
  novice's skill (only the line-up as context); no log loss or calibration; no
  statement that the game being scored is excluded from its own rating's inputs. ^f8
- [method] (inferred) The ground-truth row (72-74%) is the converged rating of game 18
  scored on novice games, so it uses later games: a hindsight ceiling, not a forecast. ^f9
- [method] (inferred) For us: Riot match-v5 gives the same kind of per-player stats
  (kills, deaths, gold, damage, CS) for every game we crawl, so a player with one or two
  earlier games can get a performance-based skill prior, not just a win count. That is
  the industrial cold-start fix, and cheaper than a player graph; our 74% with no
  earlier game on their champion still get nothing from it unless their games on other
  champions count. ^f10

## Read

- Abstract, sections 1-3 (problem, framework, features), 4.1-4.4, 4.6 opening; Tables
  1-4

## Not read

- Fig. 8 detail by cold-start stage, related work in full, appendix
