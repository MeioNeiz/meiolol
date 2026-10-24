---
title: Blitz Darius top build page, element by element (24 Oct 2026)
url: https://blitz.gg/lol/champions/darius/build
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (rendered text, 1280x900 fold and a 1280x3600 tall-viewport screenshot)
relevance: high
grade: B/weak
description: Blitz champion build page re-read for its build variant list and item table, the two elements other sites lack
---
# Blitz Darius top build page, element by element (24 Oct 2026)

Why: lol-site-ui, kind 3 (champion page). Jacob wants most common and highest win rate
shown at once, not a toggle; Blitz is the one site whose build switcher is a sortable list.
Earlier notes: [[blitz-darius]] (header strip, variant tabs), [[blitz-darius-vs-garen]]
(pre-buy win rate). Screenshots in data/team/2026-10-24-ui/refs/champion/ (gitignored):
blitz-darius-fold.png, blitz-darius-item-table.png. Raw is the page's innerText after
consent (the plain fetch got only the consent wall).

## Assessment

- Evidence: B. Large site (Overwolf app), 26,974 Emerald+ Darius top games on 26.21.
- Reasoning: weak. WRI is an unexplained label (an info icon); no stated rationale.
- Interests: ad funded, sells Premium (ad-free, a locked fourth build tab).
- Weigh: copy the list and table shapes; not the signed WRI number.

## Findings

- [ux/controls] [ux/density] Build variants are a list, not a toggle: three sort tabs
  (Best, Win Rate, Common) over named builds, each row giving name, games, win rate and
  three core item icons (Bruiser 23,521 games 51%, AD 6,726 52%, Tank 5,358 48%). Every
  variant's sample and win rate stay visible; the tabs only reorder. Clicking a row swaps
  the build panel beside it. (seen in screenshot blitz-darius-fold.png) ^f1
  > Emerald+ Builds Bruiser 23,521 GAMES 51%
- [ux/density] [ux/controls] Item Performance is a real sortable table: item (icon and
  name), WRI, pre-buy WR, win rate, pick rate, purchases; sorted by pick rate by default
  (arrow on the header), pick rate drawn again as a six-dash bar under the number, and a
  "Min pick rate" switch that hides rare items. 15 rows from 13,289 purchases down to 377.
  (seen in screenshot blitz-darius-item-table.png) ^f2
  > Item Performance Item Builder Min pick rate
  > PRE-BUY WR	WIN RATE	PICK RATE
- [ux/colour] WRI is a signed number in green or red (+1.27, -0.94, +4.92) and the only
  coloured column; the largest values sit on the rarest items (Maw of Malmortius +4.92 on
  486 purchases). (seen in screenshot blitz-darius-item-table.png) ^f3
- [ux/controls] Filter row: five role icons with no share under them, rank (Emerald+),
  region (World by default, not the visitor's region), Select Matchup, patch as plain text;
  no rank or region shown in the header strip. ^f4
  > across 26,974 Emerald+ matches in the World region on Patch 26.21
- [ux/layout] The build card is three columns at 1280: variant list (about 285 px), rune
  trees with two keystone summaries (win rate, games), spells and item lists without
  numbers (starting, build order, completed, situational). Item numbers live only in the
  table below. (seen in screenshot blitz-darius-fold.png) ^f5
- [ux/layout] The page scrolls inside an inner container, so the browser's full-page
  capture is one screen; an extra tall viewport was needed to see past the fold. ^f6

## Read

- raw/blitz-champion-ui.txt (innerText); screenshots fold and tall viewport

## Not read

- Counters, Synergies and Abilities tabs (separate pages); phone layout
