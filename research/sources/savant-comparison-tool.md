---
title: 'Baseball Savant: comparison tool and player page sliders for unqualified players'
url: https://baseballsavant.mlb.com/comparison-tool
kind: project
commit:
for: [showing-ranges]
looked: 2026-11-05
depth: skimmed (comparison tool page text; screenshot of Judge's 2026 percentile sliders)
relevance: high
grade: A/fair
description: How Savant draws a percentile slider for a metric where the player has not reached the qualifier: hatched, no number, a NOT QUALIFIED label; complements savant-percentiles
---
# Baseball Savant: sliders for unqualified players

Why: [[savant-percentiles]] read the page text, where an unqualified season is just
blank cells; this reads the slider graphic itself, the headline widget, to see what a
lay reader sees for a thin sample.

## Assessment

- Evidence: A. MLB's own Statcast site; the percentile sliders are its best-known
  widget, years of use.
- Reasoning: weak. One line of explanation; no stated reason for the design.
- Interests: league-owned; nothing to sell on the layout.
- Weigh: the slider findings are read off one screenshot (Judge, 2026 regular season,
  285 PA, taken 5 Nov 2026): `raw/savant-comparison-tool-judge-2026.png`. Colours
  named by eye.

## Findings

- [ux/uncertainty] The comparison tool's only note on thin data: an unqualified
  metric is drawn as a slashed bar and its number is left out. ^f1
  > "Slashed bars with no numbers indicate that the player has not qualified in that particular metric."
- [ux/uncertainty] On the player page the same rule holds: a qualified metric is a
  solid bar ending in a round bubble with the percentile (Fielding Run Value 42, Arm
  Strength 81, Sprint Speed 30); an unqualified one is a pale diagonal-hatched bar
  with no bubble. Judge's 2026 Batting Run Value bar carries the words "NOT QUALIFIED"
  in small capitals; the other hatched rows have no label. (seen in screenshot
  savant-comparison-tool-judge-2026.png) ^f2
- [ux/uncertainty] [ux/colour] An unqualified bar is not hidden: it keeps its length
  and its red (good) or blue (poor) hue, only washed out and hatched, so the reader
  still sees roughly where the player would sit (xwOBA, Barrel %, BB % long and red;
  Whiff %, K % short and blue). (seen in screenshot) ^f3
- [ux/uncertainty] The raw value stays at the right of every row, qualified or not
  (.396 xwOBA, 20.9 Barrel %), so the thin sample hides only the ranking, never the
  measured number. (seen in screenshot) ^f4
- [ux/colour] The scale is labelled in words over the bars, POOR, AVERAGE, GREAT,
  with blue at the poor end and red at the great end. (seen in screenshot) ^f5
- [ux/uncertainty] Checked, not there: no count of how far the player is from
  qualifying, and no range on any percentile; the qualifier rule (2.1 PA per team
  game) sits only on the leaderboard ([[savant-percentiles#^f4]]). ^f6

## Read

- Comparison tool intro text; Judge player page first screen (screenshot).

## Not read

- The comparison tool's rendered comparison (needs players picked); pitcher pages.
