---
title: Predicting Winner from Draft Phase for High ELO LoL games (TechLabs Aachen, 2021)
url: https://bcappu.medium.com/predicting-winner-from-draft-phase-for-high-elo-league-of-legends-games-6567b2aadf3e
kind: article
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full post; result tables are images, not read)
relevance: low
grade: D/weak
description: Student project predicting GM+ solo queue winners from draft (op.gg scrape, one patch, ~20k games), claiming 62% from champion win rates plus synergy scores
---
# Predicting Winner from Draft Phase for High ELO LoL games (TechLabs Aachen, 2021)

Why: one of the higher draft-only accuracy claims for solo queue; is it honest?

## Assessment

- Evidence: D. Beginners' course project, results only as images, no code read.
- Reasoning: weak. No mention of where win rates and synergy scores were computed.
- Interests: none.
- Weigh: the 62% is best read as a leakage example, not a ceiling.

## Findings

- [data] Data: games with average rank at least Grandmaster, scraped from op.gg, one patch (10.25.1), about 20k games. ^f1
  > the average elo of a game has to be at least GrandMaster to be considered
  > which initially consisted of around 20k played games.
- [method] Champion identity plus role alone gave an F1 near chance with trees and SVMs. ^f2
  > Our simplest model yields an F1 score close to random chance suggesting that more parameters need to be considered.
- [method] Replacing champions with their role win rates and adding pair synergy scores (wins minus losses per pair over the dataset) gave the headline 62%. ^f3
  > we created a model which can predict the outcome of a match with 62% accuracy.
- [stats] (inferred) The win rates and synergy scores are computed over the dataset that includes the test games, with no sign of out-of-fold computation; on 20k games pair scores carry each game's own result, so 62% is target leakage, not draft signal. ^f4
- [method] Adding Data Dragon base stats and 13 class tags in a neural net did not help and overfit. ^f5
  > It seems that unfortunately adding more parameters did not improve our prediction percentage.

## Read

- Full post text.

## Not read

- Result tables (images), the linked TechLabs pro-play post (pro, out of scope), code.
