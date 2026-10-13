---
title: 'Akhmedov and Phan 2021: Machine learning models for Dota 2 outcomes prediction'
url: https://arxiv.org/pdf/2106.01782
kind: paper
commit: 
for: [live-win-probability]
looked: 2026-10-13
depth: docs (abstract, sections V-VII)
relevance: low
grade: D/weak
description: Skoltech 2021 arXiv paper; LR vs MLP vs LSTM on Game State Integration data from the authors' own games; the "93% LSTM accuracy" is R squared for a player's gold some steps ahead, not win prediction
---
# Akhmedov and Phan 2021: Machine learning models for Dota 2 outcomes prediction

Why: often cited as "LSTM 93% vs LR 82% for Dota outcome prediction"; checked what
the numbers measure before trusting a sequence-beats-frame claim.

## Assessment

- Evidence: D. About 100 games recorded by the authors via Game State Integration;
  3,833 rows; no outcome labels in the reported metric.
- Reasoning: weak. The target is a player's gold d steps ahead (regression), scored
  by R squared and called accuracy; overlapping lagged windows split at random 80/20,
  so neighbouring windows from the same game sit in train and test.
- Interests: none.
- Weigh: do not cite as evidence that LSTMs beat frame models for win probability.

## Findings

- [method] The predicted target is player gold (a regression), not the match winner.
  Section VI-A ^f1
  > The dependent variable is player gold and this parameter is not stable during the game
- [stats] "Accuracy" is R squared (adjusted for LR). Section VI ^f2
  > we took final accuracy score as adjusted R2 , while NN and LSTM models accuracy scores were taken as R2 .
- [data] Rows are overlapping windows of L lagged steps per game; 3,833 rows by 70
  columns, split at random 80/20, so near-identical windows of one game land in both
  train and test. Sections V-B, VI ^f3
  > datasetX is 3833 rows and 70 columns, and datasetY consists of 3833 rows and a column with a target.
  > When splitting, we used standard 20% testing to 80% training respectively.
- [method] Headline: LSTM 93%, MLP 88%, LR 82% (R squared on gold d steps ahead).
  Section VII ^f4
  > 93% accuracy compare to 82% for LR and 88% for NN respectively
- [data] Data from about 100 of the authors' own games. Section VII-A ^f5
  > Real-time data collection tools were tested in more than 100 games
- [method] (inferred) A worked example of the two traps for live win models: a target
  that is not the outcome, and a row-level random split over overlapping frames of the
  same game. Any sequence-vs-frame comparison we run must split by game (and by time). ^f6

## Read

- Abstract, sections V (data construction), VI (setup), VII (results text)

## Not read

- Related work (numbers there are secondary), GSI server details
