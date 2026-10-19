---
title: 'FBref: Scouting Reports Explained'
url: https://web.archive.org/web/20260108232949/https://fbref.com/en/about/scouting-reports-explained
kind: docs
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (whole page)
relevance: medium
grade: A/strong
description: FBref's method page for percentile scouting reports: comparison pools, minimum minutes, lower-is-better stats
---
# FBref: Scouting Reports Explained

Why: what sits behind the percentile bars in [[fbref-salah-scout]], especially how
thin samples are kept out.

## Assessment

- Evidence: A. The canonical method page of the reference football stats site.
- Reasoning: strong. Explains why position groups were merged (too few players) and why
  the summary set is the same for every outfield player.
- Interests: none beyond selling the site.
- Weigh: trust as a description of their method; percentiles are rank-based, so they
  say nothing about how big a gap is.

## Findings

- [ux/density] Every statistic becomes a percentile against players at the same
  position over the same window: one shared 0 to 100 scale makes unlike stats
  readable side by side. ^f1
  > Scouting Reports compare a player's statistics to other players at their position over a specific amount of time. Each statistic is ranked as a percentile based on how it compares to other players.
- [ux/layout] The player page shows a fixed summary of about 20 stats, the same set for
  all outfield players, chosen with users and experts; the full set is one link away. ^f2
  > On a player's main page, we show a summary of the player's scouting report. This includes about 20 statistics we chose based on feedback from users and industry experts.
- [ux/uncertainty] Thin samples: a minimum of minutes to be in the comparison pool; groups
  were merged when a pool had too few players. ^f3
  > To be included in a comparison pool, players need to reach a [minimum number of minutes](https://fbref.com/en/about/scouting-reports-explained#minutes) played at that position.
  > For example, separating Midfielders into Defensive, Central, Attacking and Wide Midfielders caused each comparison pool to include too few players.
- [ux/uncertainty] A player can get a report while being below the pool minimum, so more
  players are covered without thin players skewing everyone else's percentiles. ^f4
  > Some players may meet the mimimum to have a scouting report, but don't have enough minutes to be in the comparison pool.
- [ux/colour] Direction is normalised so that high percentile always means good: for
  lower-is-better stats the scale is flipped, so the colour always means the same. ^f5
  > There are some statistics where a lower value is considered better, such as goals allowed for Goalkeepers. In these cases, the lower value is given a high percentile and vice versa.

## Read

- Whole page.

## Not read

- Minimum minutes table per competition (numbers only).
