---
title: 'Baseball Savant: percentile rankings on a player page and its leaderboards'
url: https://baseballsavant.mlb.com/savant-player/aaron-judge-592450
kind: dataset
commit:
for: [stat-presentation-patterns]
looked: 2026-11-02
depth: skimmed (Judge player page text, percentile and Statcast leaderboards, two changelog entries)
relevance: high
grade: A/fair
description: MLB's Statcast site: per-season percentile history on a player page, the full percentile leaderboard behind it, qualifier rule, filters and comparison tool
---
# Baseball Savant: percentile rankings

Why: the best-known "place among all" widget in sport: how the player page links to
the full ranking, how thin samples are kept out, how the leaderboard is laid out.
Snapshots are page text: the slider graphic at the top of the page is an image and
is not in the text (the numbers are in the season table below it).

## Assessment

- Evidence: A. MLB's own Statcast site, the reference for the metrics, years of use.
- Reasoning: fair. Rules stated in one-line notes; the percentile method page
  (MLB glossary) could not be snapshotted (JS shell), so how ties and the pool are
  handled is inferred.
- Interests: league-owned site; no selling angle on the layout.
- Weigh: trust what the pages show; the pool for a percentile is not stated in the
  text we read. Slider graphic not seen (text snapshot only).

## Findings

- [ux/features] The player page carries a "Percentile Rankings" block with a link
  straight to the full ranking behind it, and one to a compare tool. ^f1
  > [+ View Complete Percentile Rankings Leaderboard](https://baseballsavant.mlb.com/leaderboard/percentile-rankings?type=batter)
  > [+ Compare To Other Players](https://baseballsavant.mlb.com/comparison-tool?player=592450-2026-batter&openSearch=true)
- [ux/features] Below the sliders the page repeats the percentiles as a table with
  one row per season (2016 to 2026) and one column per metric (xwOBA, xBA, EV,
  Barrel%, Chase%, Whiff%, K%, BB%, Sprint Speed, about 20 columns): a bare 0 to
  100 integer per cell. ^f2
  > | 2025 | 100 | 4 | 79 | 100 | 99 | 100 | 100 | 100 | 99 | 92 | 97 | 28 | 84 | 2 | 36 | 100 | 86 | 86 | 85 |  | 42 |
- [ux/uncertainty] A season without enough playing time shows empty cells, not a
  low or provisional percentile: Judge's 2026 row (285 PA) is blank except fielding
  and running, and the 2020 short season is nearly blank too. ^f3
  > | 2026 |  |  | 42 |  |  |  |  |  |  |  |  |  |  |  |  |  |  | 66 | 81 |  | 30 |
- [ux/uncertainty] The qualifier is a rate per team game, not a fixed count, so it
  scales with how far the season has got; it is printed at the top of the leaderboard. ^f4
  > Percentile Rankings Qualifiers: 2.1 PA per team game for batters, 1.25 PA per team game for pitchers.
- [ux/layout] The full percentile leaderboard is a paged table (50 per page,
  "Showing 1-50 of 612 results"), rank column then player (linked to the player
  page) then one column per metric, so the ranking is a grid of percentiles, not a
  list of raw values. ^f5
  > Showing 1-50 of 612 results
- [ux/layout] On that leaderboard ties are not broken: rows 1 and 2 both read 100
  for xwOBA, 99 for rows 3 and 4; the "Rk." number follows the first metric and many
  rows share a value. Blank cells where the player has no value (e.g. OAA for a
  designated hitter). ^f6
  > | 1 |  [Alvarez, Yordan](https://baseballsavant.mlb.com/savant-player/670541) | 100 | 100 | 100 | 100 | 100 | 100 | 98 | 99 | 100 | 97 | 74 | 97 | 77 | 54 | 9 |  | 40 | 91 | 67 | 79 |
- [ux/layout] The raw-value leaderboard (Statcast "Exit Velocity & Barrels") has the
  same shape: "Rk.", player, then grouped numeric columns with two-level headers
  (Exit Velocity, Distance, Hard Hit, Barrels); controls above are dropdowns for
  player type, position, team, season and "Minimum BBE (Qualified)". ^f7
  > Batters ▾ Position ▾ Team ▾ 2026 ▾ Minimum BBE (Qualified) ▾
- [ux/controls] The qualified minimum is a visible, changeable dropdown on the raw
  leaderboard, with a note that a click on a player opens that player's events. ^f8
  > Click on a player to see more information about their specific events including videos of plays if available.
- [ux/layout] The percentile leaderboard can be filtered by percentile thresholds on
  any stat ("pitchers with whiff rate in the 90th percentile or higher", several at
  once), an "Edit Filters" button then "Add Filter"; a "VS" icon on each row jumps to
  the comparison tool with that player and season. ^f9
  > you can filter the leaderboard to batters in the 75th percentile of MLB or better in both barrel rate and sprint speed.
- [ux/features] The comparison tool puts up to nine players' percentile sliders
  side by side; a setting highlights the winner of each metric and swaps the
  percentile for the actual value. ^f10
  > Under Settings, you can choose to highlight the "winner" of any percentile comparison, as well as show the actual stat value for a player as opposed to simply his MLB percentile for that stat.
- [ux/features] The page keeps a line "Player" vs "MLB" in the Statcast table, so the
  league average is the reference next to the career figure (2015 to present). ^f11
  > | **MLB** |  | 48.7 | 67.0 | 82.7 | 28.6 | 57.9 | 42.6 | 30.3 | 47.3 | 25.0 | 7.3 | 76.2 |
- [ux/features] Checked, not there: no "3rd of 612" rank on the player page text;
  place is given only as a 0 to 100 percentile, not as an ordinal rank. ^f12
- [ux/layout] Checked, not there: the leaderboard text shows no highlighted or
  scrolled-to row for the player you came from (text snapshot, so unverified for
  hover or anchors); the link carries only `type=batter`, not the player. ^f13
- [ux/uncertainty] Checked, not there: no confidence interval or sample size beside
  a percentile; sample is handled only by the qualifier. ^f14

## Read

- Judge page text (percentile block, Statcast table), percentile and Statcast
  leaderboards (first page), changelog entries 2026-07-20 (filters, comparison tool).

## Not read

- The MLB glossary page on percentile rankings (JS shell, archive 404): the pool and
  tie method. Slider graphic itself. Phone layout of the leaderboard.
