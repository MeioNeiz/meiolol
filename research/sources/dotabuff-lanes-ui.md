---
title: 'Dotabuff: match Lanes tab (Dota 2)'
url: https://www.dotabuff.com/matches/9059185615/lanes
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (Lanes tab, screenshot)
relevance: high
grade: A/fair
description: Dotabuff match Lanes tab: laning stage 0-12 min per player with lane verdict, lane opponents, NW and XP bars, last hits at 4, 8 and 12 min
---
# Dotabuff: match Lanes tab (Dota 2)

Why: how a game page compares each player with their lane opponent, for the meio.lol lane section.

## Assessment

- Evidence: A. Largest Dota stats site.
- Reasoning: fair.
- Interests: sells Plus.
- Weigh: screenshot data/team/2026-10-24-ui/refs/game-detail/dotabuff-lanes.png.

## Findings

- [ux/postgame] The laning stage is a fixed window, stated in the table header. ^f1
  > Laning Stage (00:00 - 12:00)
- [ux/density] One row per player, 18 columns: hero, player, role, lane, lane verdict, the lane heroes as portraits (own side vs other side), NW, XP, K, D, A, T, Fed, Lost, Acc, and last hits at 4, 8 and 12 minutes. ^f2
  > | Hero | Player | R | L | Lane | Heroes | NW | XP | K | D | A | T | Fed | Lost | Acc | @4 | @8 | @12 |
- [ux/postgame] Each player gets a one-word lane verdict (Won Lane, Drew Lane, Lost Lane) coloured green, white or red, and the team total row gives the team's. ^f3
  > Laning Stage: won
- [ux/charts] NW and XP cells carry two thin bars under the number (about 3 px each, the player's and, by our reading, the lane opponents'), so the lane comparison is read without a second table. (seen in screenshot dotabuff-lanes.png) (inferred for what the second bar is) ^f4
- [ux/colour] The three last-hit cells are filled with a green whose strength follows the value (11 pale, 116 strong): a heat strip across time. (seen in screenshot dotabuff-lanes.png) ^f5
- [ux/postgame] Checked, not there: no per-minute lane graph and no gold or XP difference number; the comparison is the verdict word plus bars. ^f6

## Read

- Lanes tab, desktop.

## Not read

- Phone layout of this tab.
