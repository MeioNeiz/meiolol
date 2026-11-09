---
title: 'Dotabuff Plus (subscription page, Nov 2026)'
url: https://www.dotabuff.com/plus
kind: docs
commit:
for: [postgame-review-compare]
looked: 2026-11-07
depth: docs (whole page)
relevance: high
grade: A/weak
description: Dotabuff Plus sales page: $6 a month or $56 a year for TrueSight replay analysis (damage and CC breakdown, farm and comparative lane charts, vision map, item timeline, death map), hero rankings, lifetime data, no ads
---
# Dotabuff Plus

Why: what the biggest Dota stats site puts behind its paywall for post-match review.

## Assessment

- Evidence: A for what is sold (vendor page, live Nov 2026; Dotabuff has run Plus for
  about a decade).
- Reasoning: weak (a feature list).
- Interests: vendor sales page.
- Weigh: lists screens, not whether players use them. Free match pages are in
  [[dotabuff-match]], [[dotabuff-lanes-ui]], [[dotabuff-game-detail-ui]].

## Findings

- [tools/paid] Price: $6 a month or $56 a year. ^f1
  > $56/YEAR (SAVE 22%)
- [tools/paid] [ux/postgame] The paid part is TrueSight, replay parsing that does the
  analysis for you. ^f2
  > TrueSight analyzes your replays so that you don't have to.
- [ux/postgame] TrueSight screens: damage and crowd control breakdown (who contributed
  most and how), farm stats, vision map over time, ultimate ability logs, item build
  timeline, gold and XP charts, combat logs, death map, kill and death economy. ^f3
  > See who on your team contributed the most, and in what ways.
  > Travel back in time revealing where wards were placed or destroyed throughout the match.
  > See how effective you were with key ultimates like Black Hole, or abilities like Shackleshot.
- [ux/postgame] Lane outcome is judged from minute-by-minute comparative farm charts
  (last hits, gold, XP). ^f4
  > Minute-by-minute comparison of last hits, gold and experience helps identify winning lanes and matchups
- [ux/postgame] Item timing: every player's build with purchase times, multiple buys
  grouped. ^f5
  > Detailed item builds for every player in the match, showing times and grouping multiple purchases.
- [tools/paid] Plus also sells standing: personal hero rankings, a dashboard, lifetime
  data retention, friends feed, no ads; free is profile, public stats, ads. ^f6
  > Easily see where you rank on each hero and find opportunities to get ranked on new heroes.
- [ux/postgame] Checked, not there: no single performance score, no move or moment
  labels, no coach text; Plus is more charts, not a verdict. ^f7

## Read

- Whole page.

## Not read

- Upgrade flow; FAQ.
