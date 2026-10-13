---
title: 'Trouncing in Dota 2: An Investigation of Blowout Matches (Viggiato and Bezemer, AIIDE 2020)'
url: https://ojs.aaai.org/index.php/AIIDE/article/download/7444/7279/10873
kind: paper
commit:
for: [comp-attribute-features]
looked: 2026-10-13
depth: docs (whole paper)
relevance: medium
grade: B/weak
description: University of Alberta, AIIDE 2020; XGBoost on 55k pro Dota 2 games with hero ids, role counts (9 roles), patch-correct base attributes, hero and player win rates; SHAP importance, no ablation of the attribute features
---
# Trouncing in Dota 2: An Investigation of Blowout Matches (Viggiato and Bezemer, AIIDE 2020)

Why: one of the few Dota papers that puts role counts and hero base stats (strength,
agility, intelligence, gains, health, regen, move speed) next to hero ids.

## Assessment

- Evidence: B. Peer-reviewed (AIIDE), 55,287 pro games 2012-2020, code and data
  released (asgaardlab/dota2-prediction-models, 3 stars, pushed 2020-09).
- Reasoning: weak for our question. Only SHAP importance; no model without the
  attribute features, so their lift over ids is unmeasured. Blowout groups are selected
  by game length and kill gap (outcome-side variables), so their high AUCs are not draft
  prediction.
- Interests: none known.
- Weigh: use the regular-match AUC (0.65, ids plus everything) as a ceiling for pro
  pre-game; do not read SHAP rank as lift.

## Findings

- [data] 55,287 pro games from OpenDota (Oct 2012 to May 2020, Captains Mode 99%, no
  abandons); split into time blowouts (bottom 10% length), score blowouts (top 10% kill
  gap) and regular (middle quartiles, 36,348). ^f1
  > 55,287 remaining matches.
- [method] Features (457): hero one-hot per side, role counts per side over 9 roles
  (carry, nuker, initiator, disabler, durable, escape, support, pusher, jungler), each
  hero's base strength, agility, intelligence and their gains, health, regen, move speed
  (patch-correct from changelogs), plus up-to-date hero, player and hero-player stats. ^f2
  > roles: carry, nuker, initiator, disabler, durable, escape, support, pusher, and jungler.
  > we collected the changelog for each hero
- [method] Attributes enter per hero slot (five values per side), not as team balance
  or interaction terms; XGBoost is left to find any interactions. ^f3
  > ﬁve values, each corresponding to one team's player/hero.
- [method] 10-fold CV (random, across 2012-2020), AUC: regular games XGBoost 0.65, LR
  0.61, RF 0.60; time blowouts 0.86 (XGB), score blowouts 0.78 (XGB). ^f4
  > 0.65 (regular matches) to 0.86 (time blowout matches).
  > with AUC values of 0.61 against 0.60
  > (regular), 0.79 against 0.74 (time blowout), and 0.77 against
- [method] [draft] SHAP: player win rate is top for every group, then hero win rate;
  roles and attributes (pusher count, Dire intelligence gain) only rank high in score
  blowouts, much less in regular games. ^f5
  > The up-to-date win rate of the players of both teams is
  > the most important factor for all groups.
  > pusher hero role (role pusher *) is a key factor for the Radiant's victory in score blowout matches
  > Note that those features are much less important for regular
- [method] Secondary report: Semenov et al. 2016 used picked heroes plus the number of
  hero roles per team as draft features. ^f6
  > based on the draft information (picked heroes and
  > the number of hero roles in each team)
- [method] Checked, not there: no ablation (ids alone vs ids plus roles and attributes),
  no log loss or accuracy, no time-ordered split, no within-team balance or missing-role
  feature. ^f7

## Read

- Whole paper (7 pages)

## Not read

- Released code and Zenodo data (could rerun an ablation; pro games only)
