---
title: 'r/leagueoflegends: We need to talk again about using day 1 patch data (Jul 2021)'
url: https://old.reddit.com/r/leagueoflegends/comments/opc2kj/we_need_to_talk_again_about_using_day_1_patch/
kind: thread
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (post and top replies)
relevance: medium
grade: D/fair
description: Reddit post (2021) arguing that LoLalytics' day-one patch win rates are already statistically solid, with replies naming what the binomial sum misses (who plays first, builds not found yet)
---
# r/leagueoflegends: We need to talk again about using day 1 patch data (Jul 2021)

Why: how do stat-site users read a patch's first-day numbers, and what does a site show
an hour in?

## Assessment

- Evidence: D. One player's argument, 0 points and 44% upvoted; a worked binomial
  example on an old patch, no before/after check of whether day-one rates held.
- Reasoning: fair. The sum is right for sampling noise and the post names its own
  exceptions; replies supply the non-sampling objections.
- Interests: none known.
- Weigh: as a record of the debate and of LoLalytics showing new-patch counts within an
  hour; the "rarely change much" claim is unmeasured here (our own 16.21 curve: late
  minus early -0.2 ± 0.3 pp, docs/learned.md).

## Findings

- [tools] [data] LoLalytics shows a new patch's own bucket at once: the example champion
  had 865 new-patch games about an hour in. ^f1
  > A champion has 865 games recorded right after an hour of play (data from lolalytics) at win rate 47.8, or around 414 wins
- [stats] The post's argument is binomial noise only: at a day's volume a miss of a point
  or more is very unlikely. ^f2
  > the chance the data is wrong by a little over 1% is only 0.05%
- [method/dynamics] (claim) Day-one rates rarely move much later; stated exceptions are
  new champions (players learning) and builds found during the patch. ^f3
  > win rates rarely change much from the initial early data is the take away here
  > new builds being discovered and slowly filtering into the community
- [method/dynamics] Reply (loldraftingaid): after an item change or a mixed buff and
  nerf, players need more than a day to find the new best build, so day-one rates lag
  the champion's settled strength. ^f4
  > it would probably take longer than 24 hours for players to figure out the new optimized build(s) for the champion and thus the stats to reflect that
- [method/dynamics] Reply: the first hour's games are each main's first game on the
  patch, played as before it: who plays first, not sample size, is the objection. ^f5
  > What if those 865 games are shaco players first game on the new patch and they are playing exactly the same as before the patch.
- [stats] Checked, not there: no comparison of day-one rates with the same patch's later
  rates, no use of the previous patch as a prior. ^f6

## Read

- The post and the first replies in the snapshot.

## Not read

- Deeper reply chains (cut in the snapshot).
