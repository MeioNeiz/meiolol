---
title: 'Player Skill Decomposition in Multiplayer Online Battle Arenas (2017)'
url: https://arxiv.org/pdf/1702.06253v1
kind: paper
commit:
for: [curve-statistics-method]
looked: 2026-10-11
depth: docs (abstract, hypotheses, data, results and discussion)
relevance: low
grade: C/fair
description: arXiv 2017 study comparing regularised logistic models with champion, player and player-champion terms on top-tier LoL and Dota 2 ranked outcomes
---
# Player Skill Decomposition in Multiplayer Online Battle Arenas (2017)

Why: does who plays the champion matter enough in LoL that repeated games by the same
player (clustering) could bias a thin matchup's numbers?

## Assessment

- Evidence: C. arXiv preprint, top-tier ranked games only, win/loss outcomes, 10-fold
  CV; modest scale and dated (2017).
- Reasoning: fair. Clear hypotheses and model comparison; causes are speculation.
- Interests: none known.
- Weigh: direction (player and player-champion effects matter in LoL) is plausible and
  matches [[sido-lol-performance]]; size not transferable to gold curves.

## Findings

- [stats] In LoL three components predict outcomes: champion base skill, player base
  skill and player-specific champion skill; in Dota 2 mostly champion base skill. ^f1
  > The finding is that base skills of in-game avatars, base skills of players, and players’ champion-specific skills are three prominent skill components influencing LoL’s match outcomes
- [stats] Adding player-champion terms gave the best accuracy in LoL. ^f2
  > Players’ champion-specific skills are also important in LoL because LR-P-C-PC achieves the best accuracy among all models.
- [stats] (inferred) So for a thin matchup where a few one-tricks supply many of the
  games, game-level standard errors understate uncertainty; count distinct players and
  cap or down-weight games per player. ^f3

## Read

- Abstract, hypotheses H1-H7, data collection, results and discussion

## Not read

- Model details, Table 1 numbers
