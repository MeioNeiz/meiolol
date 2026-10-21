---
title: 'MetaBot.GG: LoL Patch 25.22 Winners and Losers'
url: https://metabot.gg/en/league/patch-breakdown/25-22
kind: article
commit: 
for: [frontier-dynamics]
looked: 2026-10-21
depth: docs (whole page)
relevance: low
grade: D/weak
description: A small stats site's per-patch page (archived 25.22): champion win rate change vs the previous patch on 44,293 ranked matches, next to the stat lines that changed in the game data; how a stat site presents patch-to-patch strength moves
---
# MetaBot.GG: LoL Patch 25.22 Winners and Losers

Why: how stat sites present champion strength across a patch boundary, and how big the
reported moves are relative to their samples.

## Assessment

- Evidence: D. Small site, one patch page, no method beyond the match count, no
  intervals; generated prose.
- Reasoning: weak. Moves are presented as patch effects with no noise check.
- Interests: sells a desktop app.
- Weigh: useful only as an example of the stat-site practice and of noise sized as
  effects.

## Findings

- [method/dynamics] [stats] Practice: each patch is a separate bucket; a champion's
  "win rate since the patch" is its new-patch win rate minus the previous patch's, on
  44,293 matches, shown beside the base-stat and cooldown lines that changed in the game
  data. ^f1
  > MetaBot compared 44,293 ranked matches with Patch 25.21.
  > Win rate since the patch: +1.91 points (now 51.6%)
- [method/dynamics] [stats] The biggest reported moves are 6 points (Gangplank +6.37
  to 54.4%, K'Sante -5.90 to 40.5%), called a large swing for a single patch. ^f2
  > Gangplank was the standout winner, jumping 6.37 points to a 54.4% win rate — a large swing for a single patch.
- [method/dynamics] (inferred) At 44k matches a champion averages about 2,600 games per
  patch, so the difference of two patches has a standard error near 1.4 points, more
  for rarer champions; the largest of ~170 such differences reaches 4-6 points from
  noise alone. Per-patch buckets without shrinkage report noise as patch effects, which
  is why a pooled, shrunk model with a small per-patch offset is the right baseline. ^f3
- [method/dynamics] Checked, not there: no intervals, no shrinkage, no mention of who
  plays the champion or of the previous patch's win rate as a predictor. ^f4

## Read

- Whole page.

## Not read

- Other patch pages (same template).
