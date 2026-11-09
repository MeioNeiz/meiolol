---
title: 'Ramos 2026: Embarrassingly causal: causal use of associational data in MTG drafts'
url: https://arxiv.org/pdf/2604.18314
kind: paper
commit:
for: [context-aware-models]
looked: 2026-11-09
depth: skimmed (sections 1-4.1)
relevance: medium
grade: C/fair
description: arXiv 2026 essay (Penn State health policy) on when observational data may be used causally, using 17Lands' Magic draft win-rate stats (games in hand, not seen, improvement in hand) as the case
---
# Ramos 2026: Embarrassingly causal: causal use of associational data in MTG drafts

Why: the nearest game-draft analogue for selection in pick and item statistics: how
17Lands separates "this card helps" from "it ends up in good decks".

## Assessment

- Evidence: C. One author, an argument paper; no new estimates, no data analysis.
- Reasoning: fair. Clear on what each statistic estimates and why it is biased; offers
  no correction.
- Interests: none known.
- Weigh: trust the definitions and the bias reasoning; the "embarrassingly causal"
  criterion is a philosophy claim, not evidence a statistic is right.

## Findings

- [method/causal] 17Lands compares, within decks that hold a card, games where it was
  drawn against games where it never showed (improvement in hand): a within-deck
  contrast that holds the deck fixed. ^f1
  > Improvement In Hand (IIH): The difference between Games in Hand Win Rate and Games Not Seen Win Rate.
  > Games Not Seen Win Rate (GNSWR): The win rate in games where one or more copies of the card was in the deck but not seen at any stage of the game.
- [method/causal] Drawing a card is still confounded with game length and deck style, so
  even the within-deck contrast is biased. ^f2
  > drawing a speciﬁc card 𝑐𝑐 is confounded with variables such as the number of turns in the game
- [method/causal] Experts read a card whose games-in-hand rate is high but whose
  improvement in hand is negative as one that rides good decks: the same pattern as
  items whose buyers were already ahead. ^f3
  > this card itself isn’t as strong as the win rate suggests; it just happens to make it into good decks.
- [method/causal] Checked, not there: no adjustment, matching or model-based estimate;
  the paper argues the naive numbers are usable, it does not measure their bias. ^f4
- [method/causal] (inferred) Our analogue: an item's effect within one champion-role
  and similar lead at purchase time, buyers vs games where the item was in the build
  path but not finished (like "in deck, not drawn"); a negative within-contrast with a
  high raw rate flags a ride-along item. ^f5

## Read

- Sections 1-4.1

## Not read

- Section 4.2 onward: guidance for reviewers, not methods
