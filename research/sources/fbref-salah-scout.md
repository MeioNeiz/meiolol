---
title: 'FBref: Mohamed Salah scouting report (percentile bars)'
url: https://web.archive.org/web/20250118123631/https://fbref.com/en/players/e342ad68/scout/365_m1/Mohamed-Salah-Scouting-Report
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (summary and complete report, screenshot of both)
relevance: high
grade: A/fair
description: FBref player scouting report, Wayback copy of January 2025 (live site behind a Cloudflare challenge); per-90 values with a percentile bar per row
---
# FBref: Mohamed Salah scouting report (percentile bars)

Why: how the best-known football stats site shows "is this good" for dozens of numbers
about one player at once.

## Assessment

- Evidence: A. FBref (Sports Reference, Opta data) is the reference stats site for
  football; percentile scouting reports are widely copied (radars, pizza charts).
- Reasoning: fair. Layout explained on a separate page ([[fbref-scouting-explained]]).
- Interests: stats site selling ad-free subscriptions.
- Weigh: page read from the Wayback Machine (live 403 to bots); layout may have moved
  slightly since. Screenshots: `data/team/2026-10-19-night/design-shots/`
  fbref-salah-scout-percentiles.png, fbref-salah-scout-complete.png.

## Findings

- [ux/density] Each row is three narrow columns: statistic name right-aligned, the raw
  per-90 value, then the percentile number and a horizontal bar whose length is the
  percentile; about 23 px rows, so 15 stats fit in the space of one card. ^f1
  > | Statistic | Per 90 | Percentile |
  (seen in screenshot fbref-salah-scout-percentiles.png)
- [ux/colour] Bar colour is diverging by percentile with a grey middle: deep green at
  90+, pale green around 60 to 70, grey around 50, dusty pink in the 30s, saturated red
  under 15. The bar length repeats the colour's message, so colour is never alone.
  (seen in screenshot fbref-salah-scout-percentiles.png) ^f2
- [ux/colour] The percentile number itself is printed in dark red in the summary table,
  in grey in the complete report: the number is ink, the bar carries the colour.
  (seen in screenshot fbref-salah-scout-complete.png) ^f3
- [ux/uncertainty] Sample and comparison pool are one sentence under the table: who the
  player is compared with, the window, and minutes played, in bold. ^f4
  > Player compared to positional peers in Men's Big 5 Leagues, UCL, UEL over the last 365 days. Based on **3285 minutes** played.
- [ux/layout] Progressive disclosure: the player page shows a summary of about 20 stats;
  "Complete Scouting Report" below it groups every stat into sections (Standard,
  Shooting, Passing, Possession, Defence) each with its own header row, thin rules
  between sub-groups. (seen in screenshot fbref-salah-scout-complete.png) ^f5
- [ux/layout] A position switcher tab ("vs. Att Mid / Wingers") sits above the table:
  the comparison group is a visible, changeable choice, not hidden.
  (seen in screenshot fbref-salah-scout-percentiles.png) ^f6
- [ux/layout] Next to the report, a "Similar Players" list (10 names, each with a
  Compare link) turns the numbers into a next step. ^f7
  > Compare Mohamed Salah to Top 5 Similar Players

## Read

- Summary and complete report tables, top 3000 px of the page.

## Not read

- Live page (403); the radar/pizza variant some mirrors show.
