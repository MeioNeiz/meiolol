---
title: 'Win Prediction in Multi-Player Esports: Live Professional Match Prediction (IEEE ToG, 2019/2021)'
url: https://eprints.whiterose.ac.uk/id/eprint/152931/1/Win_Prediction_in_Multi_Player_Esports_Live_Professional_Match_Prediction.pdf
kind: paper
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (abstract, literature review section III, Table I, discussion)
relevance: medium
grade: B/fair
description: Hodge, Devlin, Drachen et al. (York); literature review of Dota 2 win prediction (pre-game, in-game, post-game features) plus live pro prediction; the survey we used for the pre-game field
---
# Win Prediction in Multi-Player Esports: Live Professional Match Prediction (IEEE ToG, 2019/2021)

Why: a survey of Dota 2 win prediction to place the draft-only results side by side,
with data size and skill bracket.

## Assessment

- Evidence: B. Peer-reviewed journal, established esports analytics group; the review
  table lists 20 studies with size, bracket and accuracy, but numbers are as claimed by
  each author.
- Reasoning: fair; says outright that the numbers are not comparable.
- Interests: none known.
- Weigh: use as a map of the field, not for numbers; check primaries.

## Findings

- [method] Pre-game features in the Dota literature: one-hot hero vectors (226-dim or
  113-dim tri-state), hand-picked hero combos, role counts; plus player skill,
  player-hero history and friendship ties. Section III-A ^f1
  > Hero vectors are either 226-dimensional binary vectors (113 heroes in 2 teams)
  > The Player-Hero skill combines the player’s skill with the hero success by calculating 8 features to describe the players previous play records using this hero
- [method] Across the reviewed Dota work, LR was the most used model and beat neural
  networks and random forests in several comparisons. Section III-B ^f2
  > LR had superior accuracy for win prediction compared to artiﬁcial neural networks [16], [17] and Random Forests (RFs) [12].
- [method] Reported accuracies are on incomparable datasets (size, bracket, method
  vary), so direct comparison is not possible. Section III-C ^f3
  > readers should be aware that the authors’ data sets vary widely and direct comparison is not possible.
- [method] Table I lists Semenov et al. 2016 at 5,071,858 matches (FM and XGB,
  pre-game, normal to very high skill, 70%) and Conley 2013 at 18,000 (top 8%, 70%).
  (Table text interleaved in raw; read from the layout.) ^f4
- [method] [draft] Higher skill games are harder to predict (Semenov's finding); pros
  expected to be harder still. Section VI ^f5
  > Semenov et al. [14] posited that the accuracy of win prediction varies across skill levels and that higher skill games are harder to predict.
- [method] Live (in-game) pro prediction reached 85% at 5 minutes, outside our
  pre-game scope; listed only so in-game numbers are not confused with draft ones. ^f6
  > is up to 85% accurate after 5 minutes of gameplay

## Read

- Abstract, section III (review, Table I), section VI discussion

## Not read

- Section IV-V (their live models, features, Weka results)
