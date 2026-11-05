---
title: 'FiveThirtyEight 2020-21 NBA player projections: LeBron James page (Wayback)'
url: https://projects.fivethirtyeight.com/2021-nba-player-projections/lebron-james/
kind: project
commit:
for: [showing-ranges]
looked: 2026-11-05
depth: skimmed (one player page, Wayback Jan 2022 text and screenshot; the WAR chart did not render)
relevance: low
grade: B/weak
description: 538's CARMELO-style player page: a percentile dot strip (Bad, Avg., Good) per stat with red, blue or hollow dots, and a wins-above-replacement chart with a confidence interval legend
---
# FiveThirtyEight NBA player projections (2020-21)

Why: a mainstream projection page that puts a range on a player's future and places
each stat on a percentile scale for lay readers.

## Assessment

- Evidence: B. 538's yearly NBA projections, several seasons (CARMELO then RAPTOR);
  538 closed in 2025, so only archives remain.
- Reasoning: weak. The page itself says little; method in linked articles.
- Interests: none beyond its own model.
- Weigh: Wayback copy; the WAR projection chart is drawn by script and came out blank,
  so only its legend words are read. Screenshot:
  `raw/fivethirtyeight-nba-player-projections-2021.png`.

## Findings

- [ux/uncertainty] The projection chart's legend names two marks, a confidence
  interval and the projection itself, under a wins-above-replacement heading. (chart
  not rendered in the archive, so its look is unread) ^f1
  > "Wins above replacement projection"
  > "Confidence interval"
- [ux/density] Each stat row is value then a dot on a strip from Bad through Avg. to
  Good, labelled as a percentile and based on a three-season weighted average. ^f2
  > "Weighted average of past three seasons"
- [ux/colour] [ux/uncertainty] Dots are filled blue at the good end, filled red at the
  bad end, and hollow near the middle (3 pt. frequency, Block %, Steal %, Defensive
  +/-), so an unremarkable value is drawn empty rather than coloured. (seen in
  screenshot) ^f3
- [ux/uncertainty] Checked, not there: no games or minutes count beside the stats and
  no sample cue on the dot strip; the page flags itself as outdated instead. ^f4
  > "These projections are outdated."

## Read

- LeBron James page text; first screen of stats as a screenshot.

## Not read

- The rendered WAR chart (needs a live or better archived copy); the 2022 version.
