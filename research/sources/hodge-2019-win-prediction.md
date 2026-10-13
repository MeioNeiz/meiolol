---
title: 'Win Prediction in Multi-Player Esports: Live Professional Match Prediction (IEEE ToG, 2019/2021)'
url: https://eprints.whiterose.ac.uk/id/eprint/152931/1/Win_Prediction_in_Multi_Player_Esports_Live_Professional_Match_Prediction.pdf
kind: paper
commit:
for: [draft-predictor-methods, live-win-probability]
looked: 2026-10-12
depth: docs (abstract, sections III-VI)
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

- [method] [data] Percent of game time (used by earlier pro papers) cannot be used live,
  since length is known only after the game; they predict at clock minutes. Section
  III-C ^f7
  > Percentage of game time cannot be used for live prediction as the game length is not known until the end.
- [data] Split by time: 5.7k replays (24% pro, rest MMR above 5000) sorted by date, 66%
  train, 34% test, so the past never predicts from the future; pro test set is 186
  TI 2017 games. Section IV ^f8
  > we split the data 66% for training and 34% for testing as per Weka’s train/test split ratio with the data sorted in chronological order.
- [method] One model per minute t, each on a 5-minute window of team features (Radiant,
  Dire, R minus D and per-minute change for each); features restricted to what the live
  feed gives: damage, kills, last hits, net worth, tower damage, XP. Section IV-A,
  Table II ^f9
  > we calculate the value for team Dire D, the value for team Radiant R, the difference between Radiant and Dire R − D and the change (gradient) since the last timestamp for Dire dD and Radiant dR respectively.
  > we train a separate win predictor for each minute through the game
- [method] At minute 20 LR, RF and LightGBM all land at 77.2-77.5% on mixed data; net
  worth difference alone gives 74-76%. Pro test: 70.8-74.6%. Section V-C, Table III ^f10
  > all accuracies are very similar ranging from 77.24% to 77.51% for all 3 algorithms and their conﬁgurations.
  > For the Pro-InGame data, accuracies ranged from 70.81% to 74.59%.
- [method] [draft] Hero combinations alone predicted pro games at only 55.8%: pros pick
  to counter, so draft adds little there. Section V ^f11
  > achieving prediction accuracy of 55.8% on professional data while authors have achieved up to 70% accuracy on lower skill data
- [method] Neural nets not used: underperformed in prior work and need more data than
  their 5.7k games. Section V-A ^f12
  > Results for neural networks were not compelling (underperforming the algorithms in section III-B) and the newer deep learning methods require much larger training data sets than are available here.
- [stats] Live test on 28 ESL games: 70-90% by minute (85% at minute 5), noisy at N=28;
  17 of 28 games had two or more swings in the predicted winner. Section VI-A ^f13
  > Due to the low sample size (N=28) the accuracy varies between 70% and 90%.
  > Of the 28 games, 11 games had no swing in prediction result, while 17 games had 2 or more swings.
- [method] (inferred) Their 85% at minute 5 on 28 games is noise, not a result; the
  numbers to keep are the 77% at minute 20 with any model, and net worth diff alone
  within 1-3 points of all features. ^f14

## Read

- Abstract, section III (review, Table I), sections IV-V (live models), VI

