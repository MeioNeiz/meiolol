---
title: 'Chess.com: How are moves classified? (Classification V2, Expected Points Model)'
url: https://support.chess.com/en/articles/8572705-how-are-moves-classified-what-is-a-blunder-or-brilliant-and-etc
kind: docs
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (whole article)
relevance: medium
grade: A/fair
description: Chess.com help article: move labels from Best to Blunder by expected points lost, plus Great and Brilliant rules
---
# Chess.com: How are moves classified?

Why: Game Review is the most used post-game review; its labels turn a curve into named
moments.

## Assessment

- Evidence: A. Chess.com Game Review is used by millions of players.
- Reasoning: fair. Gives cutoffs, not why those cutoffs.
- Interests: Game Review is a paid feature beyond one a day.
- Weigh: Game Review page itself is behind sign-in; not screenshot.

## Findings

- [ux/charts] The underlying scale is expected points from rating plus engine eval:
  1.00 winning, 0.00 losing, 0.50 even. ^f1
  > determine a player’s winning chances based on their rating and the engine evaluation**, where 1.00 is always winning, 0.00 is always losing, and 0.50 is even.
- [ux/charts] Each move gets a label from how much expected points it lost, by fixed
  bands. ^f2
  > If the expected points lost by a move is between a set of upper and lower limits, then the corresponding classification is used
- [ux/charts] The bands, from the article's table (HTML, not quoted): Best 0.00,
  Excellent 0.00 to 0.02, Good 0.02 to 0.05, Inaccuracy 0.05 to 0.10, Mistake 0.10 to
  0.20, Blunder 0.20 to 1.00: six steps, finer near zero, the worst step very wide. ^f3
- [ux/charts] Positive labels need special rules: Great is a move critical to the
  outcome (losing to equal, equal to winning, or the only good move); Brilliant is a
  good piece sacrifice. From the second table (HTML). ^f4
- [ux/trust] Labels are softer for new players than for strong ones (stated for Great
  and Brilliant). ^f5
  > How do we define a blunder for a chess master versus a new player?

## Read

- Whole article.

## Not read

- Game Review UI (eval bar, classification icons and colours): needs sign-in.
