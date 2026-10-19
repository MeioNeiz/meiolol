---
title: 'ESPN: NFL game page with win probability (Seahawks at Broncos, 15 Oct 2026)'
url: https://www.espn.com/nfl/game/_/gameId/401872995
kind: dataset
commit:
for: [dense-stat-layout]
looked: 2026-10-20
depth: skimmed (full page screenshot)
relevance: high
grade: A/fair
description: ESPN game page after the final: team stat bars, scoring play list and a win probability chart from ESPN Analytics
---
# ESPN: NFL game page with win probability

Why: the most-seen sports win probability chart, for the Your games review chart.

## Assessment

- Evidence: A. ESPN game pages have shown win probability for years; huge audience.
- Reasoning: weak (no method on the page).
- Interests: betting odds sit beside the chart (DraftKings).
- Weigh: screenshots espn-nfl-gamecast-full.png and espn-nfl-winprob.png
  (`data/team/2026-10-19-night/design-shots/`); a consent footer covers part of it.

## Findings

- [ux/charts] The win probability chart is a single line on a 0 to 100 axis labelled
  100, 50, 100: the top half belongs to one team, the bottom to the other, with team
  logos at each end and 50 drawn as a baseline. One line, two readings, no legend.
  (seen in screenshot espn-nfl-winprob.png) ^f1
- [ux/charts] The area between the line and the 50 line is shaded, so the size of the
  lead over time reads as area; quarter labels (1st to 4th, OT) are the only x ticks.
  (seen in screenshot espn-nfl-winprob.png) ^f2
- [ux/charts] The current or final value is a big number per team (0%, 100%) beside the
  chart, with the source credited under it. ^f3
  > According to ESPN Analytics
- [ux/colour] Team stat comparisons are two-sided bars per stat, one team hatched and
  the other solid navy, so the two sides differ by texture, not only hue (works in
  greyscale and for colour-blind readers). (seen in screenshot espn-nfl-winprob.png) ^f4
- [ux/layout] Scoring plays are cards with the running score after each one, grouped
  by quarter: the key moments list under the chart. (seen in screenshot
  espn-nfl-winprob.png) ^f5

## Read

- Full page screenshot.

## Not read

- Live gamecast during a game (hover on the chart, play-by-play sync).
