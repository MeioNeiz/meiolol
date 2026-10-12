---
title: The iTero AI Drafting Model (iTero, Jan 2022)
url: https://itero.gg/articles/the-draft-model
kind: article
commit:
for: [draft-predictor-methods]
looked: 2026-10-12
depth: docs (full article)
relevance: medium
grade: D/fair
description: iTero founder's description of its pro-play draft model: stacked linear and GBDT layers, time-split evaluation, claims 70-73% vs bookmakers' 63-65%
---
# The iTero AI Drafting Model (iTero, Jan 2022)

Why: iTero's only method page found; what its draft model is and how it was evaluated.

## Assessment

- Evidence: D. No data size, metric definition or numbers beyond rough accuracy.
- Reasoning: fair. States a time split and a baseline (bookmaker odds), admits numbers are rough.
- Interests: vendor (iTero's own product page).
- Weigh: pro play, with team and player strength from bookmaker odds; says nothing about
  solo queue draft-only accuracy. The time-split practice is the useful part.

## Findings

- [method] [tools] Pro-play model: predicts results from both drafts on top of bookmaker odds; built over about a year. ^f1
  > Enter both teams draft, predict who will win the game.
- [method] (claim) Bookmakers average 63-65% accuracy on pro games; adding draft data reaches 70-73%. ^f2
  > Once we embed our additional draft-based data, we predict the results with c. **70–73% accuracy**.
- [method] Model is stacked: sub-models (simple linear models, gradient boosted trees) predict parts of the game and are combined. ^f3
  > Some of these are simple linear models whilst others are much more complex non-linear methods such as gradient boosted trees.
- [stats] Evaluation is time-split: only games before the predicted period are used for training. ^f4
  > The evaluation uses train/test/validation splits and is time-split.
- [method] Features tested include solo queue data for pro games, champion strength vs player experience on it, counters and synergies, kept only if they improve held-out prediction. ^f5
  > What is more important, the strength of a Champion or the players experience on it?
- [method] Checked, not there: no data size, log loss, AUC, rank or solo queue draft-only figure. ^f6

## Read

- Full article.

## Not read

- iTero's in-app solo queue drafting coach has no method page found; see [[itero-companion-apps]].
