---
title: 'League of Graphs: Darius counters and best partners (Wayback, Mar 2026)'
url: https://www.leagueofgraphs.com/champions/counters/darius
kind: docs
commit: 
for: [dense-stat-layout]
looked: 2026-10-20
depth: docs (Wayback copy 2026-03-02, text and screenshots; live site behind a Cloudflare challenge)
relevance: high
grade: B/fair
description: League of Graphs matchups page: seven small cards, each a top-5 list (counter rating, gold diff at 15, win rate difference) with a bar in every value cell, green for good and red for bad, and a See more button
---
# League of Graphs: Darius counters and best partners (Wayback, Mar 2026)

Why: the site named for its graphs; how it makes a matchup list readable in one glance.

## Assessment

- Evidence: B. Long-running site ([[leagueofgraphs-darius-stats]]); archived copy.
- Reasoning: weak. "Counter Rating" is never defined on the page.
- Interests: vendor (M.O.B.A. Network; promotes Porofessor and Counterstats).
- Weigh: live page blocked by Cloudflare; Wayback screenshots in
  data/team/2026-10-19-night/design-shots/leagueofgraphs-darius-counters*.png.

## Findings

- [ux/layout] Matchups split into small cards by question, each a five-row list with a See more button: counters lane, gets countered in lane, wins lane, loses lane, best with, wins more against, loses more against (seen in screenshot leagueofgraphs-darius-counters.png). ^f1
  > Darius gets countered in lane against
- [ux/density] Every value cell is a horizontal bar plus its number, bar length scaled within the card; green bars for the good lists, red for the bad, so a card reads as a small bar chart (seen in screenshot leagueofgraphs-darius-counters.png). ^f2
- [ux/colour] Colour is fixed per card (all green or all red), not per value: it says which list you are reading, like U.GG's per-list hue ([[ugg-darius-counter#^f8]]) (seen in screenshot leagueofgraphs-darius-counters.png). ^f3
- [ux/uncertainty] Checked, not there: no game counts anywhere on the page, so a +5.8% win rate difference has no visible sample. ^f4
- [ux/trust] Failure: "Counter Rating" (4.0 to 6.4) is an unexplained score, and the "Winrate" column actually holds a signed difference (+5.8%), not a win rate. ^f5
  > | Name | Counter Rating |
- [ux/layout] Failure: lane counter lists mix roles (junglers such as Rek'Sai and Udyr among top laners), which a top laner choosing a pick has to filter by eye (seen in screenshot leagueofgraphs-darius-counters.png). ^f6

## Read

- Wayback text and screenshots (fold and full)

## Not read

- Live page; per-matchup pages (/champions/builds/darius/vs-...)
