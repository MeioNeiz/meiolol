---
title: 'Chess.com Help: How is Game Rating calculated in Game Review?'
url: https://support.chess.com/en/articles/10773754-how-is-game-rating-calculated-in-game-review
kind: docs
commit:
for: [postgame-review-compare]
looked: 2026-11-06
depth: docs (whole article)
relevance: high
grade: A/fair
description: Chess.com help article (Feb 2026) on Game Rating: the rating you played at in this one game, from move quality against what your rating predicts; swings a lot per game
---
# Chess.com Help: How is Game Rating calculated in Game Review?

Why: the second summary number, in rating units rather than percent.

## Assessment

- Evidence: A. Vendor help page.
- Reasoning: fair. No formula; admits single-game noise and bot-game gaps.
- Interests: vendor.
- Weigh: the framing (a rating per game, next to your real one) is the point.

## Findings

- [ux/postgame] Game Rating (also called performance rating) says what rating you played
  at in this one game, from the quality of your moves. ^f1
  > Performance rating is **a way to measure how well you played in a particular game compared to your usual rating.**
  > **Game Review estimates your performance in a single game** based on the quality of your moves.
- [ux/postgame] Example: a 2404 blitz player played like 2650, his 2391 opponent like
  2200; both players get one. ^f2
  > has a Blitz rating of 2404, but in this particular game, he played at the level of a 2650 rated player (in Blitz).
  > their performance in this specific game was at the level of a 2200-rated player.
- [ux/postgame] It compares your moves with what a player of your rating is expected
  to play. ^f3
  > Performance rating is determined **by comparing the quality of your moves to what is expected from a player at your rating level.**
- [ux/trust] It is noisy per game and averages to your rating over time; said openly. ^f4
  > in a single game or even a series of games, it can fluctuate significantly, sometimes being much higher or lower than expected.
- [ux/trust] Large rating gaps (bot games) make it unreliable. ^f5
  > Performance ratings are harder to assess when there is a large rating gap between opponents.

## Read

- Whole article.
