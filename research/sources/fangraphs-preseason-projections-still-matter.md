---
title: 'FanGraphs: Yes, Preseason Projections Still Matter (Szymborski, Sep 2026)'
url: https://blogs.fangraphs.com/yes-preseason-projections-still-matter/
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole article)
relevance: high
grade: B/fair
description: ZiPS's author backtests preseason projections against five months of season-to-date numbers for predicting September, 2004-2025, with the best mix of the two
---
# FanGraphs: Yes, Preseason Projections Still Matter (Szymborski, Sep 2026)

Why: a measured answer to "how much should a prior built on old periods still weigh
once the new period has a lot of data"; the analogue of Meio's old-patch weight late
in a patch.

## Assessment

- Evidence: B. First-hand backtest by the developer of ZiPS over 600 team seasons,
  2,196 hitter seasons and 2,107 pitcher seasons; no intervals, method of the "ideal
  mix" not given (reads as a two-variable regression).
- Reasoning: fair. Reports where the prior loses (team MAE and RMSE) as well as wins.
- Interests: defends his own system against reader complaints.
- Weigh: trust the direction and rough sizes. Baseball has no known break at the season
  start comparable to a patch; aging and roster moves are its drift.

## Findings

- [method/dynamics] [stats] After five months of a season, the best mix for predicting
  a hitter's last month is still mostly the preseason projection. ^f1
  > "the ideal mix from 2004 to 2025 would be 62% ZiPS/38% season-to-date"
- [stats] Noisier stat, heavier prior: pitchers' ERA+ takes 69% projection. ^f2
  > "the ideal mix from 2004 to 2025 would be 69% ZiPS/31% season-to-date"
- [method/dynamics] Units expected to change more (age 25 and under, 35 and over) get
  less prior, but still most of the weight. ^f3
  > "an ideal mix of preseason and season-to-date numbers being 57% preseason/43% season-to-date for the hitters and 60%/40% for the pitchers"
- [stats] For teams, season-to-date wins on error size and the projection on head to
  head: about a tie, where new data includes things the prior could not know (roster,
  injuries). ^f4
  > "The preseason projections had a mean absolute error of 87 points of winning percentage and an RMSE of 110 points of winning percentage, while the season-to-date numbers had a MAE of 85 points and an RMSE of 107 points."
- [method/dynamics] The author's reading: readers want forecasts to move faster than
  the evidence supports. ^f5
  > "They just don’t move as much as our brains want them to."
- [method/dynamics] Checked, not there: the mix by games played (only the September
  point), any interval on the mix, how in-season ZiPS itself weights new data. ^f6
- [method/dynamics] (inferred) For us: the prior here is a full model of several old
  seasons, and it keeps 57-69% against ~450 PA of new data, less for units more likely
  to have changed. Meio's old-patch weight should likewise stay well above 0 a week into
  a patch for unchanged champion-roles and fall faster for changed ones; the truth test
  (E2) by day bucket is our version of this backtest. ^f7

## Read

- Whole article; comments skimmed.
