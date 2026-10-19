---
title: 'Lichess: Accuracy metric'
url: https://lichess.org/page/accuracy
kind: docs
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (whole page)
relevance: medium
grade: A/strong
description: Lichess explainer of Win% from engine evaluation and per-move and per-game accuracy derived from Win% drops
---
# Lichess: Accuracy metric

Why: chess game review turns an engine curve into a few readable numbers; meio.lol's
Your games review does the same with win chance by minute.

## Assessment

- Evidence: A. Lichess is a top-two chess site, open source; the formula is in lila.
- Reasoning: strong. Explains the transform, its limits, and why game accuracy is not
  a plain average.
- Interests: none (non-profit).
- Weigh: the analysis board itself (eval bar, chart) was not screenshot: no public
  analysed game found through the API in time.

## Findings

- [ux/charts] Engine evaluation is turned into Win% (0 to 100) before it is shown,
  "to make it more intelligible": the same move meio.lol makes with win chance. ^f1
  > Win% = 50 + 50 * (2 / (1 + exp(-0.00368208 * centipawns)) - 1)
- [ux/charts] Move quality is measured as the drop in Win% across the move; a move can
  only lose winning chances, never gain them. ^f2
  > how much your winning chances decreased with each move you made
- [ux/trust] They warn the number is not a school grade: in lopsided positions almost
  any move keeps the Win%, so accuracy runs high. ^f3
  > It is flawed to compare accuracy to a numerical grade you would get on a test.
  > in lopsided positions most moves don't change the winning chances meaningfully
- [ux/charts] Game accuracy weights moves by how volatile that part of the game was, so
  a single blunder in an equal game counts more than one in a lost position. ^f4
  > The simple move average can be misleading if one side completely dominates or makes a one-move blunder in a completely equal game.

## Read

- Whole page.

## Not read

- Analysis board UI (eval bar, advantage chart, move annotations), lila source.
