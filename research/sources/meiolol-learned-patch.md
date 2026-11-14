---
title: 'meiolol docs/learned.md: what a patch moves and what does not predict it (our measurements, 16.21-16.22)'
url: 
kind: docs
commit: 45b1e7c0
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (docs/learned.md patch lines; sizes from docs/model.md, not snapped)
relevance: high
grade: B/strong
description: Our held-out results on what a patch moves (16.21, 16.22) and which predictors of the move failed (changed list as a looser prior, rank and region leads, a learning curve), for comparison with prior art
---
# meiolol docs/learned.md: what a patch moves and what does not predict it (our measurements, 16.21-16.22)

Why: early-patch-forecast compares others' methods with what we measured; companion of
[[meiolol-learned-tools]] (#^f6-^f9) and [[patch-jump-16-21-measured]].

## Assessment

- Evidence: B. Our own games (16.21: 428k dev games on days 1-3, day one 52k per
  platform check), declared rules, shuffled controls; two boundaries at most, one for
  most lines.
- Reasoning: strong. Each line names its sample and where the evidence sits in
  docs/model.md.
- Interests: ours.
- Weigh: trust for League solo queue at our volume; "no curve" and "no lead" are one
  patch each and cover number changes, not reworks or new champions.

## Findings

- [method/dynamics] A looser prior for the champions a patch changed adds nothing once
  the offset's sd is estimated from the fit. ^f1
  > changed-champions list adds nothing. Evidence: model.md "The latest patch day by day on
- [method/dynamics] No lead: Diamond+ does not move before other ranks, nor KR before
  EUW1. ^f2
  > RMS on 16.21's day one, 1.9 pp for the 12 changed); Diamond+ doesn't move first, nor KR
- [method/dynamics] No settling curve after a number change: a champion-role whose pick
  share jumps starts about a point up and stays; late minus early days -0.2 ± 0.3 pp. ^f3
  > before EUW1, and a pick that jumps starts about a point up and stays. Sure: day one 52k
  > games; 16.21 (KR 16.22 too): no lead, no curve (late - early -0.2 ± 0.3 pp). Site: Learn.
- [method/dynamics] Pooled plus a shrunk per-patch champion offset beats plain pooling
  from the patch's second day, by 0.28 milli-nats a game. ^f4
  > 16.21 days 1-3, 428k games, -0.28 ± 0.07 milli-nats a game vs plain pooling; a
- [method/dynamics] [data] An item change moves the champions that build it, by
  exposure, and Data Dragon's diff hid the change: only Riot's notes had it. ^f5
  > worth about 0.5-1 point. Data Dragon's diff hid that change. Sure: one patch, 513
- [method/dynamics] Pick shares move alike across regions but not as one; a term for the
  platforms that patch early missed its bar. ^f6
  > KR, VN2 least alike). Games before EUW1 carry real balance; an early-platforms term and
- [method/dynamics] Shares keep moving inside a patch: about 3 points for a keystone at
  50% from the first week to the second, 2 for an item. ^f7
  > repeat their picks: at a 50% share, a keystone's share moves about 3 points from a
- [method/dynamics] [stats] (inferred) The fitted offset sd of 0.020-0.024 logit
  (docs/model.md "The latest patch day by day on 16.21") is a pad of X = 4 / sd^2 =
  7,000-10,000 new-patch games of a champion-role before its own games weigh half: in
  [[kmedved-padding-2020#^f3]]'s terms the stabilisation point, between the hand-set
  4,000 (changed) and 15,000 (unchanged) of [[meta-unbound-patch-forecast#^f10]] and
  far above DraftGap's 1,000 ([[draftgap#^f30]]). ^f8

## Read

- `docs/learned.md`: the patch lines under "Data quality" and the share-drift and
  item-nerf lines.

## Not read

- `docs/model.md` sections named in those lines (the tables): not snapped, the file
  held another session's uncommitted work.
