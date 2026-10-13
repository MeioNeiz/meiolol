---
title: Evaluating Team Skill Aggregation in Online Competitive Games (Dehpanah et al., IEEE CoG 2021)
url: https://arxiv.org/pdf/2106.11397
kind: paper
commit:
for: [pregame-player-skill]
looked: 2026-10-13
depth: docs (whole paper; Table I read from a layout rendering of the PDF)
relevance: medium
grade: C/fair
description: Elo, Glicko, TrueSkill with SUM, MAX or MIN team aggregation on PUBG, LoL (52k games, 324k players) and CS:GO; online chronological prediction; LoL all-players accuracy about 50% for every system
---
# Evaluating Team Skill Aggregation in Online Competitive Games (Dehpanah et al., IEEE CoG 2021)

Why: the DePaul group's rating-system evaluations; what do Elo, Glicko and TrueSkill
reach on LoL outcomes, and does team aggregation (sum vs best player) matter?

## Assessment

- Evidence: C. Four-page conference paper, public datasets, standard implementations
  with default parameters, online predict-then-update in time order. No tuning, no log
  loss, no error bars.
- Reasoning: fair. Honest about sparse data; but the "best players" set-up selects
  players by their final rating and scores their first 10 games, which leaks the
  outcome (players who ended high won those games), so its 76-78% means little.
- Interests: none known; their own MAX method is the favoured side.
- Weigh: the useful number is the LoL all-players and frequent-players accuracy, about
  50% for every rating system: on a sparse sample of matchmade LoL games, rating
  systems built from a few observed games per player predict nothing.

## Findings

- [data] LoL data: a sample of the Sapienza et al. Dataverse set, 52k head-to-head
  games and 324k unique players (so most players appear in very few games). ^f1
  > The sample dataset includes in-game statistics such as number of kills, gold earned, and rank for over 52,000 head-to-head matches and 324,000 unique players.
- [method] Protocol: games sorted by time, new players get default ratings (1500 Elo
  and Glicko, 25 TrueSkill), predict from current ratings then update; default
  parameters (k = 10, beta 4.16, tau 0.833). ^f2
  > For all datasets, we first sorted the matches by their timestamps.
  > Players who appeared in the system for the first time were assigned default ratings, 1500 for Elo and Glicko, and 25 for TrueSkill.
- [stats] LoL accuracy, all players (Table I): Elo 49.2/50.2/49.5, Glicko 49.3/50.1/
  49.8, TrueSkill 49.8/50.4/49.3 (SUM/MAX/MIN); previous-rank baseline 47.6. Players
  with 100+ games, scored on their first 100: 49.2-50.5 for every system. ^f3
  > Accuracy, a popular metric for evaluating classifications, is a common metric for evaluating the predictive performance of rating systems in these games.
- [stats] CS:GO (26k games, 4.9k players, denser): 57-65% accuracy, SUM as good as or
  better than MAX; they note far fewer new players there. ^f4
  > CS:GO has a much higher density compared to the other two datasets, meaning the number of players who played few games is very small and most of the players are known to the system.
- [method] "Best players" set-up: top 1000 by most recent rating, scored on their
  first 10 games; LoL 76-78% with MAX. ^f5
  > we sorted the players based on their most recent skill ratings and selected the top 1000 players who had played more than 10 games.
  > Since these players had competed in different matches, we performed our evaluations on their first 10 games.
- [method] Their conclusion: MAX (team = best member) beats SUM in most cases, so the
  strongest player carries more weight. ^f6
  > Rating systems achieved more accurate predictions when using the MAX method in the majority of the tested cases.
- [method] (inferred) The best-players set-up selects on the outcome: a player ranked
  top by final rating has, by construction, won more of the games being scored, so the
  76% is leakage, and the MAX advantage there may be the same artefact (MAX keys on
  the very player selected). ^f7
- [method] (inferred) For us: about 50% for ratings from scratch on sparse LoL data
  matches our own experience that player-history terms help only once a player has
  earlier games (53.2% to 54.5% overall). Ratings need history; a cold start is worth
  nothing, so per-slot features must say how much history there is (games observed)
  and fall back to a prior (rank at start) when there is none. ^f8
- [method] (inferred) Aggregation matters for us too: a team score as the sum of five
  slot terms is the default; a max or spread term (best player's edge, weakest
  player's deficit) is a cheap test on our net. ^f9

## Read

- Whole paper (sections I-VII, Table I)

## Not read

- Figures 1-3 (time series per set-up, images); the companion battle royale paper
  (arXiv 2105.14069) and free-for-all paper (arXiv 2008.06787)
