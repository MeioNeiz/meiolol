---
title: "The Review: Patch 10.12 Balance Change Analysis by the Numbers (LoLTheory's Aldonall, r/leagueoflegends, Jun 2020, via devtrackers)"
url: https://devtrackers.gg/leagueoflegends/p/95a56837-the-review-patch-10-12-balance-change-analysis-by-the-numbers
kind: thread
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (original post and the Riot replies devtrackers captured)
relevance: medium
grade: D/weak
description: A stat-site owner's per-patch table of every buffed or nerfed champion-role with win and pick rate before and after (10.11 to 10.12), plus the unchanged champions that moved most; no sample sizes, no forecast
---
# The Review: Patch 10.12 Balance Change Analysis by the Numbers (LoLTheory's Aldonall, r/leagueoflegends, Jun 2020, via devtrackers)

Why: how big are buff and nerf effects when someone tabulates them, and does the notes'
label give the sign? A size table like this is the raw material for a "buff = +x,
nerf = -y" prior mean.

## Assessment

- Evidence: D. One patch, 17 changed champion-roles, win rates to two decimals with no
  game counts, rank filter or intervals; the unchanged movers are picked for being
  biggest (winner's curse).
- Reasoning: weak. Descriptive; "meta" is the label for any unexplained move.
- Interests: promotes LoLTheory.gg (the author's site, which keeps this table per
  patch at /statistics/patch-comparison/changed).
- Weigh: a size anchor only (changed champions move about a point, sign right more
  often for nerfs); our own 16.21 numbers (1.9 pp RMS changed, 0.5 pp rest) are better
  evidence of the same thing.

## Findings

- [method/dynamics] Practice: after each patch, one table of every changed
  champion-role with its label (buff, nerf) and win rate and pick rate on the old and
  new patch; a second table of unchanged ones that moved, labelled "Meta". No forecast
  before the patch. ^f1
  > "I use tables and numbers to talk about what Riot's most recent balance patch actually affected, and by how much"
- [method/dynamics] [stats] 10.12, 17 changed champion-roles with both rates (our
  arithmetic from the table): nerfs went down in 7 of 8 (median about -1.1 pp, Trundle
  -2.1, Varus -1.6, Yasuo -1.0 to -1.3, Cassiopeia flat); buffs went up in 5 of 9
  (Akali +1.3 and +1.5, Xayah +0.4, Volibear +8.9 and +9.8 after his rework; Brand
  -1.2 and -0.9, Senna and Viktor -0.4). ^f2
  > "| Trundle | Jungle | Nerf | 51.83%  ⇘  49.69% | 6.25%  ⇘  4.82% |"
  > "| Brand | Middle | Buff | 46.73%  ⇘  45.54% | 0.27%  ⇒  0.45% |"
- [method/dynamics] Buffed champions whose win rate fell gained pick rate (Viktor 2.53%
  to 4.54%, Senna support 12.71% to 14.26%): the influx reading. ^f3
  > "| Viktor | Middle | Buff | 48.82%  ⇒  48.41% | 2.53%  ⇑  4.54% |"
- [method/dynamics] Unchanged champions listed as movers shifted 1.0-1.3 pp (Ashe -1.2,
  Illaoi -1.3, Annie +1.1), as large as the typical direct change; the author puts it
  down to rune changes (Predator, Ghost) and the meta. ^f4
  > "While these champions weren't changed directly, their WR/PR was influenced either by meta changes, or the many changes to runes."
- [method/dynamics] Checked, not there: games per cell, intervals, a noise control
  (two windows of one patch), any prediction made before the patch, any score across
  patches. ^f5
- [method/dynamics] (inferred) The label gives the sign better for nerfs than buffs
  (a buff draws new pickers), and sizes are about a point with one outlier per patch:
  a prior mean of "sign x about 1 pp" would be right in sign about two times in three
  here, which is the cheapest version of a notes-based prior to test against 0. ^f6

## Read

- Original post (both tables, notes) and Riot replies shown by devtrackers.

## Not read

- The other posts of the series (10.x, 2020) and LoLTheory's patch-comparison page:
  several patches of the same table would give a sign hit rate with a count.
