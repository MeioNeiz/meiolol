---
title: 'LoLTheory blog: in-game item recommendations (Apr 2026)'
url: https://blog.loltheory.gg/in-game-item-recommendations/
kind: article
commit: 
for: [search-demand]
looked: 2026-10-12
depth: docs (whole post)
relevance: high
grade: C/fair
description: LoLTheory's pitch for its overlay that recommends items as the enemy team builds, with reasons ("Good Against: Heals"), and its account of why item win rates mislead (Mejai's, one-tricks, Zhonya's)
---
# LoLTheory blog: in-game item recommendations (Apr 2026)

Why: who serves "what to build against this enemy team", and how.

## Assessment

- Evidence: C. Vendor blog; claims about its model, no evaluation shown.
- Reasoning: fair. Names three real biases in item win rates and quotes Riot.
- Interests: vendor.
- Weigh: the bias argument is sound and matters for meiolol's own item stats; "no
  major tool does this" is a claim.

## Findings

- [tools] [learning] An in-game overlay recommends items from what the enemy team is building, updating on each enemy purchase. ^f1
  > LoLTheory's in-game overlay recommends items based on what the enemy team is actually building, updating every time someone makes a purchase.
- [tools] (claim) It says no major tool adapts items to the enemy during the game. ^f2
  > No major tool does this. Most give you a build at game start and leave you on your own.
- [stats] Item win rates are biased by purchase context: win-more items look strong, desperation items (Zhonya's) look weak, one-trick items look good. ^f3
  > Mejai's Soulstealer shows roughly 80% win rate. Not because it's broken, but because nobody finishes it in a game they're losing.
  > Zhonya's Hourglass shows a terrible win rate because you buy it when you're desperate.
- [stats] (claim) Its model adjusts for gold difference, player champion skill and enemy matchups to isolate an item's effect. ^f4
  > Gold differences so snowball items aren't overvalued, player champion skill so meta builds aren't undervalued, and enemy matchups so defensive choices get fair consideration.
- [ux/features] [learning] Each recommendation carries a reason label against an enemy trait. ^f5
  > Good Against → Magic Damage
- [policy] (inferred) Live in-game item advice is an overlay during the game; meiolol's web and pre/post-game framing would explain item choices against comp types before or after, not live. ^f6

## Read

- Whole post

## Not read

- Riot's item balancing dev post it quotes
