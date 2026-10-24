---
title: 'Blitz.gg: player profile and match rows'
url: https://blitz.gg/lol/profile/euw1/
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: skimmed (first screen of a Challenger EUW player's profile, desktop and phone; the page did not scroll in capture)
relevance: medium
grade: B/fair
description: Blitz profile: name, three tabs, a ranked card with LP bar and an LP history dot sparkline, two collapsed panels, then large match rows led by the result word and KDA
---
# Blitz.gg: player profile and match rows

Why: match history rows and profile summary (kind 2) on a big desktop-app site. Game page: [[blitz-match-ui]].

## Assessment

- Evidence: B. Major site and app ([[blitz-lol]]); live page.
- Reasoning: weak.
- Interests: vendor; right column is ads.
- Weigh: shots in data/team/2026-10-24-ui/refs/profile/ (blitz-profile.png, blitz-phone.png). Only the first screen was captured: the page scrolls inside a container the capture did not move.

## Findings

- [ux/layout] Profile header is just portrait with level, name and a share-link button; tabs Overview, Champion Pool, LP History. ^f1
  > Overview Champion Pool LP History
- [ux/charts] The ranked card is tier, LP and a full-width LP bar, win rate and W-L, then an LP History sparkline of about 14 dots with "VIEW FULL HISTORY". (seen in screenshot blitz-profile.png, 24 Oct) ^f2
  > VIEW FULL HISTORY
- [ux/layout] Other modes and a profile stats summary are collapsed into two bars ("Other Modes", "Profile Stats"), so the first match row starts at about 630 px. ^f3
  > Other Modes Profile Stats
- [ux/density] A match row is about 140 px with a result-tinted background: the result word in colour (Defeat red, Victory teal), queue, duration, age; portrait framed in the result colour; KDA as the big number with K/D/A under it; CS per minute and gold per minute with totals under them; spells, runes, items; game badges ("CS Master", "2-Piece", "First Blood", "+2 More"); 10 players in two columns. ^f4
  > 0.8 KDA 3 / 10 / 5 5.5 CS/Min.
- [ux/layout] On a 390 px phone the row keeps its desktop layout and is cut at the right edge: items and players are off screen. (seen in screenshot blitz-phone.png) ^f5
- [ux/postgame] Checked, not there on the first screen: no summary over the last N games, no played-with list, no per-day grouping. (seen 24 Oct) ^f6

## Read

- First screen, desktop and phone; page text of the Overview.

## Not read

- Champion Pool and LP History tabs; rest of the match list (not captured).
