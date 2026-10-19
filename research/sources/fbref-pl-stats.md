---
title: 'FBref: Premier League Stats (league table, squad tables, leaders)'
url: https://web.archive.org/web/20261005133149/https://fbref.com/en/comps/9/Premier-League-Stats
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (league table, leaders boxes, screenshot)
relevance: medium
grade: A/fair
description: FBref competition page, Wayback copy of 5 Oct 2026: league table with form, squad stat tables, leaderboards
---
# FBref: Premier League Stats (league table, squad tables, leaders)

Why: FBref's team-level table and how it shows leaders across many stats.

## Assessment

- Evidence: A. Reference football stats site.
- Reasoning: fair. No method text; layout read from the page and screenshot.
- Interests: stats site.
- Weigh: Wayback copy; screenshot fbref-pl-leaders.png and fbref-pl-stats-full.png
  (`data/team/2026-10-19-night/design-shots/`).

## Findings

- [ux/density] The league table packs form, attendance, top scorer and goalkeeper into
  one row per team beside the points: identity plus a few headline facts per row. ^f1
  > | Rk | Squad | MP | W | D | L | GF | GA | GD | Pts | Pts/MP | Last 5 | Attendance | Top Team Scorer | Goalkeeper | Notes |
- [ux/layout] Leaders are a grid of small boxes, one per stat (Goals, Goals/90, Assists
  and so on), three across: each box shows only number one with the value right-aligned,
  then a red "Show #2-10" toggle; ties list everyone tied. Small multiples of
  leaderboards with progressive disclosure. (seen in screenshot fbref-pl-leaders.png) ^f2
- [ux/layout] A jump menu at the top lists every table on the page (Squad Standard
  Stats, Goalkeeping, Shooting, Leaders): one long page, many anchored sections. ^f3
  > [Squad Standard Stats](https://fbref.com/en/comps/9/Premier-League-Stats#all_stats_squads_standard)

## Read

- League table, leaders grid, section menu.

## Not read

- The squad stat tables in detail (per-90 and against columns).
