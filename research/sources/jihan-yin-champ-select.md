---
title: 'LoL: Predicting Wins In Champion Select With ML (Jihan Yin, 2018)'
url: https://medium.com/@jihan_yin/league-of-legends-predicting-wins-in-champion-select-with-machine-learning-6496523a7ea7
kind: article
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full post; tables are images)
relevance: low
grade: D/fair
description: 2018 student post predicting ranked outcomes from 1,700 games with champion.gg champion stats and player history, best about 60%
---
# LoL: Predicting Wins In Champion Select With ML (Jihan Yin, 2018)

Why: early public champ select predictor; what features carry signal and how it was tested.

## Assessment

- Evidence: D. 1,700 matches, one week, crawled from the author's account.
- Reasoning: fair. States biases (rank skew, preseason) but split is random over mirrored rows.
- Interests: none.
- Weigh: only useful as a small-data, player-features-dominate data point and a mirror-row
  split warning.

## Findings

- [data] 1,700 matches, each as two rows (winning and losing team), 70/30 random split. ^f1
  > Each match was treated as two data points: one for the winning team, and one for the losing team.
  > Splitting my data into 70% training and 30% test
- [stats] (inferred) With two rows per match and a random row split, a match's mirror can land in train while the other side is in test, a duplicate-style leak. ^f2
- [method] Best model about 60%; player features beat champion features (champion.gg win rate, matchup win rate) when trained alone. ^f3
  > my best model had an accuracy of only 60% in predicting wins/losses.
  > The models seem to work best when trained only on specific player information, doing significantly better than if trained only on champion specific information.

## Read

- Full post text.

## Not read

- Tables (images), linked repo arilato/ranked_prediction.
