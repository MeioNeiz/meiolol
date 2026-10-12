---
title: 'About League PhD: counter and synergy metrics from a team comp model (2021)'
url: https://leaguephd.com/en/blog/about-us/
kind: docs
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full page)
relevance: medium
grade: C/fair
description: League PhD's method page: regularised logistic regression on full team comps (strength, synergy, counter terms) over millions of Plat+ solo games, log loss about 0.68
---
# About League PhD: counter and synergy metrics from a team comp model (2021)

Why: a live LoL draft tool that states its model and a log loss.

## Assessment

- Evidence: C. Running site (patch 15.12 shown), one author, "not actively managed";
  no split or data size beyond "millions".
- Reasoning: fair. Explains why pairwise win rates mislead and why log loss is near 0.693.
- Interests: own product.
- Weigh: the log loss is unspecified (in-sample or CV, which patches); trust the model
  choice, not the 0.68.

## Findings

- [method] [tools] Model: regularised logistic regression on full team comps with champion strength, synergy and counter terms. ^f1
  > The analysis uses a regularized logistic regression to predict a match outcome solely based on team compositions, taking account of champion strengths as well as synergy and counter relationships with other champions.
- [data] Data: millions of Platinum+ solo queue games, NA, EUW, EUNE and KR, first per-patch release 3-4 days into a patch. ^f2
  > League PhD collects and analyzes millions of Platinum+ solo queue games in multiple regions
- [stats] Reported log loss about 0.68 after tuning (constant 0.693); most common comps sit at 45-55% win; coefficients stable across CV folds. ^f3
  > my model scored log loss of around 0.68, indicating that it has some predictive power.
  > cross-validation results suggested that coefficients are quite stable across folds.
- [draft] [method] Argues the lane matchup explains only a small part of champion performance variation, and that pairwise win rates confound counters with champion strength and with duo correlation (Xayah and Rakan). ^f4
  > your lane matchup explains only a small portion of the variations in champion performance.
- [tools] [method] Pick Now scores a candidate over all possible upcoming enemy and ally picks, weighted by how likely each is. ^f5
  > It calculates how likely a champion will be picked into your champion
- [stats] Checked, not there: no accuracy, AUC, split method or patch window. ^f6

## Read

- Full page.

## Not read

- Other League PhD blog posts.
