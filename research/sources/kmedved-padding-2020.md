---
title: 'Medvedovsky: NBA Stabilization Rates and the Padding Approach (2020)'
url: https://kmedved.com/2020/08/06/nba-stabilization-rates-and-the-padding-approach/
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole post)
relevance: high
grade: B/fair
description: DARKO's author on the padding method, a fixed count of league-average play added to a player's season-to-date numbers, with the count fitted to predict the rest of the season
---
# Medvedovsky: NBA Stabilization Rates and the Padding Approach (2020)

Why: the in-season version of Marcel: how the weight on new data grows with the sample,
and how the constant is chosen.

## Assessment

- Evidence: B. Author of DARKO, a widely used public NBA projection; fit on every
  player after every game of every season since 2001 (about 750K rows). The table of
  padding values is an image, not in the snapshot.
- Reasoning: fair. Explains the method and its alternatives; no error table, no
  comparison against a prior from last season.
- Interests: none known.
- Weigh: trust the form and the fitting rule. Here the pad is the league average, not
  the player's old numbers; DARKO itself (decay plus Kalman) is not described.

## Findings

- [stats] The padding method: add X observations at the league-average rate to both
  numerator and denominator; the result is the forecast for the rest of the season. ^f1
  > "expected_fg3_pct = (17 + X*league_average_fg3_pct)/(34 + X)"
- [stats] [method/dynamics] X is the same from the first game to the last; the weight
  on new data grows only through the sample, n / (n + X). ^f2
  > "the amount of padding remains constant throughout the season"
- [stats] X is the "stabilisation point": at n = X the forecast is half own data, and
  nothing special happens there. ^f3
  > "there’s nothing magical about the ‘stabilization point’, or about 50%"
- [stats] X is chosen by forecast error, not by a reliability formula: the value that
  best predicts the rest of the season from every point in it. ^f4
  > "finding the best ‘padding’ number to add to year-to-date performance for each player, after every game of the season, for every season since 2001, to best predict rest-of-the-year performance (about 750K rows of data)"
- [stats] X differs widely by stat: 242 attempts for three-point percentage, over 1,000
  possessions for plus/minus. ^f5
  > "you should regress a player’s performance by over 1,000 league average possessions going forward"
- [stats] The predictive fit gave a much smaller constant than the reliability method
  had (242 against 750 for threes). ^f6
  > "he concluded you needed **750** attempts for ‘stabilization’"
- [method/dynamics] Variants named, said to matter less than expected: target the next
  game instead of the rest of the season; pad career-to-date instead of year-to-date. ^f7
  > "they mostly matter less than you may expect"
- [method/dynamics] Checked, not there: padding with the player's own previous season
  (a prior mean other than the league's), decay of old games, a known break. ^f8
- [method/dynamics] (inferred) For us: one constant per kind (win rate, matchup, item
  share), fitted on a replayed patch to minimise next-7-days error from every day of
  it, is the whole of the "how fast should the new patch take over" rule, and the pad
  is last patch's estimate, not the role mean. That is A2 / Meio's d[cr, patch] with the
  sd read as X = p(1-p) / sd^2 games; the predictive fit is the check on the MacKay
  estimate of that sd. ^f9

## Read

- Whole post and comments.

## Not read

- The table of padding values per stat (image). DARKO's own method (no write-up found).
