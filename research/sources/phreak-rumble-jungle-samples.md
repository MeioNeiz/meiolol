---
title: '[2021] Rumble is not a jungler part 2 - Phreak (devtracker thread)'
url: https://devtrackers.gg/leagueoflegends/p/42f35e1d-rumble-is-not-a-jungler-part-2-phreak
kind: thread
commit: 
for: [champselect-advice-methods]
looked: 2026-11-07
depth: docs (whole devtracker page: post and Phreak's replies, grepped for samples and sites)
relevance: medium
grade: B/fair
description: Riot designer Phreak (May 2021, patch 11.10) arguing an off-role pick's win rate gap from rank curves; his sample rules (at least 1,000 games, 49 games is two net wins), a site figure he calls clearly wrong, and region and surrender biases in sliced stats-site data
---
# [2021] Rumble is not a jungler part 2 - Phreak (devtracker thread)

Why: a Riot designer's own rules for when an off-role pick's win rate means anything, and
how sliced stats-site numbers mislead.

## Assessment

- Evidence: B. First-hand from a Riot designer (later lead gameplay designer) with internal
  data; an argument in a Reddit thread, not a study.
- Reasoning: fair. States his sample floor and why, admits MMR as a proxy for practice is
  flawed.
- Interests: defending his own claim against pro players' view.
- Weigh: trust the sample arithmetic and the bias list; the Rumble conclusion itself is
  out of scope.

## Findings

- [stats] [ux/uncertainty] Sample floor: he only trusts samples of at least 1,000 games,
  about a 6-point win rate band at 95%, and only for large moves. ^f1
  > Intuitively, I really tried to only use samples with at least 1,000 games. That's less than ~6% wr change 95% of the time
- [stats] Small-sample rule of thumb: 55% over 49 games is two net wins, "unacceptable" as
  evidence. ^f2
  > keep in mind 55% win rate in 49 games is just winning 2 more than you lost and that's just unacceptable for this
- [stats] Slicing to a region and top bracket leaves too few games for 1-2 point claims
  (under 500 games of Rumble mid in Korean Master+ over two weeks). ^f3
  > there were under 500 games of Rumble mid in master+ Korean solo queue over the last two weeks. If we're going to debate 1-2% win rate shifts as indicative of champion performance, that's not enough samples
- [ux/trust] [data] A stats site's current figure (U.GG Challenger Rumble mid 45.5%) is called
  "clearly not accurate" against the prior patch's 54.7%. ^f4
  > Right now, Rumble mid is sitting at 45.5 on that site, which is clearly not accurate.
- [method/causal] Region bias: early surrenders in Korean solo queue favour early-game
  champions, so a region filter brings its own bias. ^f5
  > So any server where players FF early is biased toward making Rumble look good.
- [method/dynamics] [draft] New or new-in-role picks: he expects a steep rise with practice
  (an "Azir curve"), read from win rate by MMR as a stand-in for practice. ^f6
  > I expect Azir curves to be pronounced on any new champion (or new in role).
  > We're using MMR as a dummy variable to represent practice games.

## Read

- Whole page as captured (Phreak's post and replies with quoted parents)

## Not read

- The part 1 thread
