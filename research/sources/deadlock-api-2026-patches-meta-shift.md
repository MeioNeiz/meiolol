---
title: 'Deadlock API blog: Four months of Valve balancing Deadlock, told in 2.9 million matches (Apr 2026)'
url: https://deadlock-api.com/blog/2026-patches-meta-shift
kind: article
commit: 
for: [early-patch-forecast]
looked: 2026-11-14
depth: docs (whole post)
relevance: low
grade: C/weak
description: A Deadlock stats API's write-up of hero and item win and pick rates in windows before and after five 2026 patches, by rank bracket, with no model or intervals
---
# Deadlock API blog: Four months of Valve balancing Deadlock, told in 2.9 million matches (Apr 2026)

Why: how another game's stats operator reads patch moves, and any measured sizes of
moves, selection after a buff, or who reacts first.

## Assessment

- Evidence: C. 2.9M matches behind it, but only window means in prose; no samples per
  hero, no intervals, causes asserted; windows of about two weeks.
- Reasoning: weak. Descriptive; one selection effect named, not tested.
- Interests: promotes its own API and analytics pages.
- Weigh: sizes of the biggest moves and the direction of the selection example only.

## Findings

- [method/dynamics] Method: fixed windows before and after each patch, compared
  directly; no pooling across patches. ^f1
  > "We pulled hero stats, item stats and game-level averages from the API for windows just before and just after each one"
- [method/dynamics] A buff can lower the win rate of the thing buffed as more players
  take it: a buffed item's pick rate rose 16% to 27% while its win rate fell 3 points. ^f2
  > "But the win rate moved in the opposite direction: 55.3% before the buff, 52.1% after."
- [method/dynamics] Their reading of that is dilution by new takers. ^f3
  > "more players bought it, the average skilled-user winrate regressed"
- [method/dynamics] Sizes: the largest hero moves at one patch are 2.5-3.6 points on a
  roster whose win rates have an sd of 2.1-2.5 points. ^f4
  > "Bebop cratered by 3.6 percentage points and Infernus by 2.5, two of the biggest single-patch drops of the year"
  > "went from **2.52 percentage points** in the pre 01-30 window to **2.13** after 04-10"
- [method/dynamics] High ranks moved their picks more than low ranks at the same patch,
  while the win-rate change was not larger there. ^f5
  > "Seven's pickrate jumped +25.7 points at high rank versus +18.9 at low, even though his winrate gained _more_ at low rank (+1.8 vs +0.7)"
- [method/dynamics] Checked, not there: day-by-day rates after a patch, a settle time,
  any forecast of a move, shrinkage, intervals. ^f6
- [method/dynamics] (inferred) For us: the same shape as our findings (a few changed
  units move by about one roster sd, picks react more than win rates, no lead for high
  ranks in win rate), and one more case of buff, pick surge, lower win rate
  ([[kica-claypool-lol-patches#^f4]]): a pick-share jump on days 0-1 is a candidate
  predictor of a win-rate move against the buff's sign (TS3). ^f7

## Read

- Whole post (charts not in the snapshot).
