---
title: 'Player Skill Decomposition in Multiplayer Online Battle Arenas (2017)'
url: https://arxiv.org/pdf/1702.06253v1
kind: paper
commit:
for: [curve-statistics-method, draft-predictor-methods]
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

- [method] Table 1 accuracy, LoL: majority class 53.22%, TrueSkill 55.24%, player only
  56.75%, champion only 55.62%, player + champion 58.82%, plus player-champion 60.24%.
  Dota 2: champion only 59.16%, all terms 59.66%. ^f4
  > 60.24% ± 0.16% 59.66% ± 0.42%
  > 55.62% ± 0.36% 59.16% ± 0.41%
- [data] LoL data: 231,212 ranked games of 972 NA Challenger and Master seed players in
  2015, so the same players recur across games. ^f5
  > We used the public official APIs9 to access detailed data (e.g., win/loss and selected champions) of 231212 unique ranked matches played by the seed players in 2015.
- [method] The logistic models use random 10-fold CV; only TrueSkill is time-split
  (first 90% of matches to fit, latest 10% to test). ^f6
  > In the first 90% matches, we update player skill ratings according to TrueSkill algorithm
- [method] (inferred) Random CV with per-player ID weights lets a player's later games
  inform earlier ones, so the 1.4 to 3.6 point player gains are an upper bound; TrueSkill,
  the honest time-split player model, gained only 2 points over majority class. ^f7
- [method] Authors' guess for Dota 2 showing no player effect: better matchmaking leaves
  little base-skill difference between teams within a game. ^f8
  > the match making system in DOTA2 has a better quality than that in LoL, such that the base skills of players are hard to be further differentiated from the ranked matches meant to be fair
- [data] (inferred) Riot API: player and player-champion terms need stable player IDs
  (PUUIDs in match-v5) and each player's history; fine for an internal model, but in the
  app only the user's own terms could be applied. ^f9

## Read

- Abstract, hypotheses H1-H7, data collection, results and discussion, Table 1 (2026-10-12)

## Not read

- Model details beyond the feature encoding
