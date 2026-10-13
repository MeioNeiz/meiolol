---
title: What Makes a Good Team? Team Composition in Honor of Kings (Cheng et al., WWW 2019 long version)
url: https://arxiv.org/pdf/1902.06432
kind: paper
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (sections 1-3, 6; skimmed 4-5)
relevance: medium
grade: B/fair
description: Zhejiang and Tencent; 54M ranked Honor of Kings games, win rate by role composition (126 role counts), plus XGBoost win prediction with role-combination features over player info; no hero-id baseline
---
# What Makes a Good Team? Team Composition in Honor of Kings (Cheng et al., WWW 2019 long version)

Why: the largest measured role-count (missing role, stacked role) effect on win in a MOBA.

## Assessment

- Evidence: B. Tencent data at huge scale (54.4M ranked games for the descriptive part,
  78K games for prediction), short paper at WWW 2019 plus arXiv long version.
- Reasoning: fair. Descriptive win rates by role composition are raw (no hero or skill
  control, except a rank-gap split); prediction compares with player info, never with
  hero ids.
- Interests: Tencent co-authors; no product claim.
- Weigh: the role-count effect is large but mostly from rare degenerate comps; in HoK
  players pick roles freely, unlike LoL where lanes fix one of each.

## Findings

- [data] Three weeks of August 2017 logs: 95.6M games, 54.4M ranked used for the
  composition analysis; 78K ranked games for prediction; five roles (warrior, mage,
  marksman, assassin, support), 126 role-count compositions. ^f1
  > Among these games, there are 54.4M ranked games
  > In total, there exist 126 team compositions.
- [draft] Raw win rate by role composition spans 8.3% to 53.6%; most rare comps lose,
  the common ones sit near 50%. ^f2
  > rate of different team compositions spans a wide range, from 8.3%
  > which suggests that most losing teams do not occur frequently.
- [draft] Teams with more distinct roles win more; the worst comps are dominated by
  supports or assassins, all top comps have at least four roles; no mage or marksman
  means too little damage. ^f3
  > while all the top winning teams have at least four roles.
  > cannot cause sufficient damage in a game.
- [method] Prediction: XGBoost, 5-fold nested CV on third-week games; feature sets are
  baseline (time), player info (rank, recent win rates), role properties (one- and
  two-role combinations crossed with per-role player stats) and total. ^f4
  > For each task, we conduct 5-fold nested crossvalidations on prediction games in the third week
  > We only consider up to two-role combinations (k ≤ 2)
- [method] Lift from composition: total 70.4% vs player info 67.7% (+2.7 pp); role
  properties beat player info by 0.9 pp on all games and 1.6 pp on games with equal
  average rank. ^f5
  > by the difference between total and player information: e.g., 70.4%
  > the difference between role properties and player information almost doubles (1.6% vs. 0.9%)
- [method] [draft] Two-role combinations capture almost all of it; three- to five-role
  (full composition) features add nothing more. ^f6
  > saturates after adding two-role combinations. It suggests that modeling single roles and two-role combinations provides most of the
  > predictive power.
- [method] Checked, not there: no hero-id model, so whether role features add to hero
  ids is untested; role features are mixed with per-role player win rates, so pure
  composition effect is not isolated; no AUC or log loss; no time-based split. ^f7
- [draft] (inferred) The role-count effect is a missing-role penalty that LoL's lane
  assignment mostly removes (one of each position); the analogue for us would be
  attribute balance within a fixed five-position team, which this paper does not
  measure. ^f8

## Read

- Sections 1-3 (data, composition and winning), 6 (prediction), Table 4

## Not read

- Sections 4-5 (surrender, abuse) beyond headlines; appendix tables
