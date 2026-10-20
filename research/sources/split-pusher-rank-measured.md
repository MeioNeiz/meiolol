---
title: "Yorick and split pushers' win rate by rank in ranked solo (our measurement, 2026-10-20)"
url: https://meio.lol/?measured=split-pusher-rank-measured
kind: dataset
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: ran
relevance: medium
grade: B/fair
description: Top lane win rate of Yorick, of six split pushers together and of every top laner, by the player's rank, in 364k ranked solo games of 16.19-16.20 (lab snapshot 13 Oct, test games left out)
---
# Yorick and split pushers' win rate by rank in ranked solo (our measurement, 2026-10-20)

Why: check [[coachrogue-split-push-win-rate]]: Yorick 46% in Master+ against 55.6% in
Iron.

## Assessment

- Evidence: B. 10,175 Yorick top games and 75,481 split pusher games out of 618,586 top
  laner games, every platform, but Platinum IV+ games only, so Iron itself is out of
  reach and Master+ has 545 Yorick games (about ±4.2 points).
- Reasoning: fair. Method: win rate per player rank band, compared with every top laner
  in the same band. Limits: the rank is looked up after the game, so winners sit higher
  (every top laner climbs from 45.9% to 52.4% across bands); "Gold or lower" are
  lower-ranked players in Platinum+ games, not low-rank games.
- Interests: none.
- Weigh: two years and many patches after the video (14.24 against 16.19-16.20).

## Findings

- [data] Yorick top wins 48.9% over 10,175 games in Platinum IV+ ranked solo. ^f1
  > | all | 10175 | 48.9% |
- [data] Yorick sits 0.3-0.8 points under the average top laner from Gold-or-lower players to Diamond, and 4.2 under in Master+ (47.5% on 545 games, at the edge of noise): close to the video's 46% there. ^f2
  > | Master+ | 545 | 47.5% |
  > Yorick minus every top laner, same rank: Gold or lower -0.4, Platinum -0.8, Emerald -0.6, Diamond -0.3, Master+ -4.2 points
- [data] The six split pushers together track every top laner within a point in every rank band (46.8% against 45.9% in Gold or lower, 50.9% against 51.7% in Master+): no split pusher edge at the lower ranks we have. ^f3
  > | Gold or lower | 5517 | 46.8% |
  > | Master+ | 6080 | 50.9% |
- [data] Checked, not there: Iron, where the video's 55.6% comes from; our crawl starts at Platinum IV. ^f4

## Read

- `raw/split-pusher-rank-measured.md`: all
